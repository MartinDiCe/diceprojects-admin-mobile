param(
  [string]$FlutterBat = "C:\src\flutter\bin\flutter.bat",
  [string]$VersionName = "",
  [string]$OutputDir = "$env:USERPROFILE\Desktop",
  [switch]$DryRun,
  [switch]$SkipKill,
  [switch]$NoIncrement
)

$ErrorActionPreference = "Stop"

function Write-Step($Message) {
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Resolve-Flutter {
  if (Test-Path -LiteralPath $FlutterBat) {
    return $FlutterBat
  }

  $cmd = Get-Command flutter -ErrorAction SilentlyContinue
  if ($cmd) {
    return $cmd.Source
  }

  throw "No se encontro Flutter. Ajusta -FlutterBat o agrega flutter al PATH."
}

function Set-FileText($Path, $Content) {
  [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Get-FileText($Path) {
  return [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$pubspecPath = Join-Path $repoRoot "pubspec.yaml"
$appConfigPath = Join-Path $repoRoot "lib\core\config\app_config.dart"

if (-not (Test-Path -LiteralPath $pubspecPath)) {
  throw "No se encontro pubspec.yaml en $repoRoot"
}

$pubspec = Get-FileText $pubspecPath
$originalPubspec = $pubspec
$originalAppConfig = if (Test-Path -LiteralPath $appConfigPath) {
  Get-FileText $appConfigPath
} else {
  $null
}
$versionMatch = [regex]::Match($pubspec, "(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$")
if (-not $versionMatch.Success) {
  throw "No pude leer la version desde pubspec.yaml. Formato esperado: version: 1.0.6+22"
}

$currentName = $versionMatch.Groups[1].Value
$currentBuild = [int]$versionMatch.Groups[2].Value
$nextName = if ($VersionName.Trim()) { $VersionName.Trim() } else { $currentName }
$nextBuild = if ($NoIncrement) { $currentBuild } else { $currentBuild + 1 }

$debugInfoDir = Join-Path $OutputDir "diceprojects-debug-info-$nextName-$nextBuild"
$outputAab = Join-Path $OutputDir "diceprojects-backoffice-$nextName-$nextBuild.aab"
$flutter = Resolve-Flutter

Write-Step "Version detectada: $currentName+$currentBuild"
if ($NoIncrement) {
  Write-Host "Version a compilar: $nextName+$nextBuild (sin incrementar)"
} else {
  Write-Host "Proxima version: $nextName+$nextBuild"
}
Write-Host "AAB destino: $outputAab"
Write-Host "Debug info: $debugInfoDir"

if ($DryRun) {
  Write-Host ""
  Write-Host "DryRun activo: no modifico archivos ni compilo." -ForegroundColor Yellow
  exit 0
}

if (-not $NoIncrement -or $VersionName.Trim()) {
  Write-Step "Actualizando version"
  $pubspec = [regex]::Replace(
    $pubspec,
    "(?m)^version:\s*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+\s*$",
    "version: $nextName+$nextBuild"
  )
  Set-FileText $pubspecPath $pubspec
}

if (Test-Path -LiteralPath $appConfigPath) {
  $appConfig = if ($null -ne $originalAppConfig) {
    $originalAppConfig
  } else {
    Get-FileText $appConfigPath
  }
  $appConfig = [regex]::Replace(
    $appConfig,
    "(static const String appVersionName = String\.fromEnvironment\(\s*'APP_VERSION_NAME',\s*defaultValue:\s*')[^']+(')",
    "`${1}$nextName`${2}",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
  )
  $appConfig = [regex]::Replace(
    $appConfig,
    "(static const String appBuildNumber = String\.fromEnvironment\(\s*'APP_BUILD_NUMBER',\s*defaultValue:\s*')[^']+(')",
    "`${1}$nextBuild`${2}",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
  )
  Set-FileText $appConfigPath $appConfig
}

if (-not $SkipKill) {
  Write-Step "Cerrando procesos Java/Dart/Gradle si estan activos"
  foreach ($name in @("java", "dart", "gradle")) {
    Get-Process -Name $name -ErrorAction SilentlyContinue |
      Stop-Process -Force -ErrorAction SilentlyContinue
  }
}

$buildDir = Join-Path $repoRoot "build"
if (Test-Path -LiteralPath $buildDir) {
  $resolvedBuild = Resolve-Path -LiteralPath $buildDir
  if (-not $resolvedBuild.Path.StartsWith($repoRoot.Path, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "La carpeta build resuelta queda fuera del repo: $resolvedBuild"
  }
  Write-Step "Eliminando build"
  Remove-Item -LiteralPath $resolvedBuild.Path -Recurse -Force
}

Write-Step "flutter clean"
& $flutter clean
if ($LASTEXITCODE -ne 0) { throw "flutter clean fallo con codigo $LASTEXITCODE" }

Write-Step "flutter pub get"
& $flutter pub get
if ($LASTEXITCODE -ne 0) {
  Set-FileText $pubspecPath $originalPubspec
  if ($null -ne $originalAppConfig) { Set-FileText $appConfigPath $originalAppConfig }
  throw "flutter pub get fallo con codigo $LASTEXITCODE. Version revertida."
}

Write-Step "flutter build appbundle release"
$builtAab = Join-Path $repoRoot "build\app\outputs\bundle\release\app-release.aab"
& $flutter build appbundle --release `
  --build-name=$nextName `
  --build-number=$nextBuild `
  --split-debug-info=$debugInfoDir `
  --no-shrink

if ($LASTEXITCODE -ne 0) {
  if (Test-Path -LiteralPath $builtAab) {
    Write-Host ""
    Write-Host "Flutter devolvio codigo $LASTEXITCODE, pero el AAB fue generado. Lo copio igual." -ForegroundColor Yellow
    Write-Host "Si el error fue strip de simbolos nativos, revisa Android cmdline-tools/licencias con flutter doctor." -ForegroundColor Yellow
  } else {
    Set-FileText $pubspecPath $originalPubspec
    if ($null -ne $originalAppConfig) { Set-FileText $appConfigPath $originalAppConfig }
    throw "flutter build appbundle fallo con codigo $LASTEXITCODE y no genero AAB. Version revertida."
  }
}

if (-not (Test-Path -LiteralPath $builtAab)) {
  Set-FileText $pubspecPath $originalPubspec
  if ($null -ne $originalAppConfig) { Set-FileText $appConfigPath $originalAppConfig }
  throw "No se encontro el AAB generado en $builtAab"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
Copy-Item -LiteralPath $builtAab -Destination $outputAab -Force

Write-Step "Listo"
Get-Item -LiteralPath $outputAab | Format-List FullName, Length, LastWriteTime
