param(
  [string]$DeviceId = "",
  [int]$MaxScrolls = 6,
  [int]$TapDelayMs = 900,
  [switch]$VerboseLogs
)

$ErrorActionPreference = 'Stop'

# Runner para ejecutar el UAT móvil desde la carpeta del proyecto Flutter.
# Delegamos al script fuente en /tests para no duplicar lógica.

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')
$script = Join-Path $repoRoot 'tests\uat\mobile\validate_views.ps1'

if (-not (Test-Path $script)) {
  throw "No se encontró el script UAT en: $script"
}

$args = @(
  '-ExecutionPolicy', 'Bypass',
  '-File', $script
)

if ($DeviceId) { $args += @('-DeviceId', $DeviceId) }
if ($MaxScrolls) { $args += @('-MaxScrolls', $MaxScrolls) }
if ($TapDelayMs) { $args += @('-TapDelayMs', $TapDelayMs) }
if ($VerboseLogs) { $args += '-VerboseLogs' }

powershell @args
