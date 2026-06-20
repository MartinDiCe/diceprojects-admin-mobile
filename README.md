# DiceProjects Admin App

Aplicación móvil Flutter del backoffice DiceProjects. Permite operar módulos administrativos desde Android con autenticación, permisos IAM, notificaciones, manuales de uso y copiloto operativo local.

## Stack

- Flutter / Dart
- Riverpod
- GoRouter
- Dio
- Firebase Messaging
- Android App Bundle para Google Play

## Funcionalidades principales

- Login mobile con refresh token y dispositivo.
- Dashboard operativo por permisos.
- Seguridad: usuarios, roles, invitaciones.
- Organización: empresas, sucursales, vendedores, clientes, proveedores y personas.
- Productos: artículos, tipos, marcas, presentaciones e importación.
- Ventas, compras, proyectos, proyectos integrales y almacenes.
- Marketing: campañas, leads, cupones y destacados.
- Notificaciones y logs.
- Manuales de uso con ejemplos por módulo.
- Chat IA / Copiloto Backoffice local: guía al usuario con manuales, permisos y contexto activo sin depender de LLM.

## Idiomas

La app soporta `es`, `en` y `pt` a nivel de configuración de Flutter. Los textos operativos principales del shell, manuales y copiloto están preparados para convivir con ese selector; algunos módulos internos mantienen textos funcionales en español hasta completar la traducción fina por pantalla.

## Configuración local

No commitear archivos sensibles. Para Android se requieren localmente:

```text
android/app/google-services.json
android/app/upload-keystore.jks
android/key.properties
```

El archivo `android/key.properties` debe apuntar al keystore local:

```properties
storePassword=...
keyPassword=...
keyAlias=...
storeFile=app/upload-keystore.jks
```

## Variables de compilación

La API productiva por defecto es:

```text
https://api.diceprojects.com/api
```

Se puede sobrescribir al compilar:

```powershell
flutter build appbundle --release `
  --dart-define=API_BASE_URL="https://api.diceprojects.com/api" `
  --dart-define=PRIVACY_POLICY_URL="https://diceprojects.com/privacidad"
```

Para revisión de Google Play, si se quiere precompletar un usuario demo sin hardcodearlo:

```powershell
flutter build appbundle --release `
  --dart-define=REVIEWER_USERNAME="demo@diceprojects.com" `
  --dart-define=REVIEWER_PASSWORD="********"
```

## Comandos útiles

```powershell
flutter pub get
flutter analyze
flutter build appbundle --release
```

Salida esperada del AAB:

```text
build/app/outputs/bundle/release/app-release.aab
```

Para generar un AAB de Play Store incrementando automaticamente el build number:

```powershell
.\tools\build-release-aab.ps1
```

El script lee `version` desde `pubspec.yaml`, suma `+1` al build, sincroniza `AppConfig`, limpia, compila y copia el AAB al Escritorio como:

```text
diceprojects-backoffice-<version>-<build>.aab
```

Para verificar que version usaria sin compilar:

```powershell
.\tools\build-release-aab.ps1 -DryRun
```

Si una compilacion anterior ya incremento la version pero fallo antes de copiar el AAB, recompila esa misma version sin volver a sumar:

```powershell
.\tools\build-release-aab.ps1 -NoIncrement
```

Si `flutter build appbundle --release` falla localmente en el paso de strip de símbolos nativos, validar el Android SDK con:

```powershell
flutter doctor -v
```

En este workspace el bundle release también puede generarse desde Gradle:

```powershell
cd android
.\gradlew.bat bundleRelease
```

Ese comando deja el mismo AAB firmado en `build/app/outputs/bundle/release/app-release.aab`.

## Google Play

Antes de subir:

1. Verificar `version` en `pubspec.yaml`.
2. Ejecutar `flutter analyze`.
3. Ejecutar `flutter build appbundle --release`.
4. Subir `build/app/outputs/bundle/release/app-release.aab`.
5. Completar notas de acceso privado en Play Console.
6. Publicar o validar URL de privacidad.

Ver también:

```text
play-store/reviewer-notes.md
play-store/privacy-policy.html
```

## Copiloto Backoffice

El copiloto de la APK trabaja en modo local/determinístico:

- Usa manuales de usuario como KB curada.
- Respeta permisos del usuario antes de navegar a módulos.
- Usa el contexto activo de empresa y seller.
- Si el usuario está global sin empresa, pide seleccionar contexto antes de consultar datos operativos.
- Puede orientar sobre creación de proyectos, búsqueda de clientes/proveedores/productos, ventas, compras, marketing, salud, agenda y AI Orchestrator.

La integración LLM queda preparada conceptualmente para una etapa posterior: el LLM debe ser la última instancia, usando manuales, permisos, contexto y memoria curada como base para reducir costo y evitar respuestas fuera de scope.
