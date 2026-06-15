# Notas para revision de Google Play

## Acceso a la app

La app requiere login porque es un backoffice privado. Para revision, crear un usuario demo en el ambiente productivo o UAT con permisos limitados de lectura/operacion y cargarlo en Play Console en:

`App content > App access > All or some functionality is restricted > Add instructions`

Texto sugerido:

```text
La aplicacion requiere autenticacion porque es un panel administrativo privado.

Usuario demo:
[COMPLETAR_EMAIL_DEMO]

Contrasena:
[COMPLETAR_PASSWORD_DEMO]

Pasos:
1. Abrir la app.
2. Ingresar con el usuario demo.
3. Revisar dashboard, productos, ventas, marketing, organizaciones/personas y notificaciones.
4. No usar datos reales de clientes.
```

Si se desea mostrar un boton "Completar acceso demo para revision" en el login sin hardcodear credenciales, compilar con:

```powershell
flutter build appbundle --release `
  --dart-define=REVIEWER_USERNAME="[COMPLETAR_EMAIL_DEMO]" `
  --dart-define=REVIEWER_PASSWORD="[COMPLETAR_PASSWORD_DEMO]"
```

## Politica de privacidad

Publicar `play-store/privacy-policy.html` en una URL publica y compilar indicando esa URL:

```powershell
flutter build appbundle --release `
  --dart-define=PRIVACY_POLICY_URL="https://diceprojects.com/privacidad"
```

## Permisos declarados

- Internet: comunicacion con la API DiceProjects.
- Camara: carga de imagenes cuando el usuario lo solicita.
- Notificaciones: alertas operativas y novedades de cotizaciones.
- Biometria: ingreso opcional en el mismo dispositivo.

## Seguridad

No commitear:

- `android/app/google-services.json`
- `android/app/upload-keystore.jks`
- `android/key.properties`
- credenciales server de Firebase/Google Cloud
