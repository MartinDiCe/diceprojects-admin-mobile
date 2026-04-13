# UAT Mobile (UI automático)

Este folder contiene wrappers para ejecutar el UAT móvil desde el proyecto Flutter.

## Requisitos

- Device Android conectado por USB con `USB debugging` habilitado.
- `adb` disponible en PATH.
- La app debe estar instalada y el usuario ya logueado (el script asume sesión activa).

## Ejecutar

Desde `frontent/app-diceprojects-admin`:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\uat\run-uat.ps1
```

Opcionalmente:

```powershell
# Elegir device
powershell -ExecutionPolicy Bypass -File .\tools\uat\run-uat.ps1 -DeviceId <DEVICE_ID>

# Logs detallados si detecta errores
powershell -ExecutionPolicy Bypass -File .\tools\uat\run-uat.ps1 -VerboseLogs
```

## Qué valida

- Recorre módulos clickables desde Dashboard (uiautomator dump + taps).
- Detecta pantallas "Página no encontrada".
- Busca patrones de error en logcat (flutter).

Fuente de verdad: `tests/uat/mobile/validate_views.ps1` (este runner solo delega).
