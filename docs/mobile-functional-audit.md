# DiceProjects Admin App - Auditoria funcional

Fecha: 2026-06-19

## Criterio de revision

Cada modulo se revisa contra esta matriz:

| Modulo | Listado | Filtros | Crear | Ver | Editar | Historico | Cambio de estado | Acceso por permiso | Mobile | Estado |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Central de notificaciones | OK | No aplica | No aplica | OK | Preferencias | No aplica | Marcar leida | OK | OK | Revisado |
| Manuales | OK | No aplica | No aplica | OK | No aplica | No aplica | No aplica | OK | OK | Revisado previo |
| Chat backoffice | OK | No aplica | Acciones guiadas | OK | No aplica | No aplica | No aplica | OK | OK | Revisado previo |
| Seguridad | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | En cola |
| Organizacion | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | En cola |
| Clientes / Proveedores | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | En cola |
| Productos | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | En cola |
| Ventas / Compras | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | En cola |
| Proyectos / Integrales | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | En cola |
| Marketing | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | En cola |
| Notificaciones configuracion | OK parcial | OK | No aplica | OK | Preferencias | No aplica | Activo/inactivo visual | OK | OK parcial | Revisado parcial |
| Almacenes | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | En cola |

## Central de notificaciones

### Verificado

- El inbox consulta `GET /v1/notifications/inbox` con `unreadOnly=true`, paginado `page=0&size=20`.
- La pantalla refresca manualmente y por pull-to-refresh.
- El provider refresca silenciosamente cada 45 segundos.
- Las preferencias consultan `GET /v1/notifications/preferences`.
- Las preferencias se guardan por tipo con `PUT /v1/notifications/preferences/{typeCode}`.
- Al tocar una notificacion se marca como leida con `PATCH /v1/notifications/{notificationId}/read`.

### Ajustado

- La navegacion desde notificaciones ya no abre rutas a ciegas.
- Si el `targetPath` no existe en la app mobile, se muestra un mensaje y la app queda en la central.
- Si el usuario no tiene permiso para el destino, se muestra un mensaje y no se navega.
- Se normalizaron destinos web frecuentes a rutas mobile soportadas.
- Se corrigio texto visible: `campana` -> `campaña`.

### Riesgos que quedan para revisar con backend

- El unread count se calcula sobre los 20 registros cargados, no necesariamente sobre el total real del servidor.
- Si el backend envia rutas nuevas, hay que agregarlas al mapper mobile o enviar rutas ya compatibles con la app.
- Las preferencias dependen de que notification tenga tipos activos seedeados por tenant.

## Proxima pasada recomendada

1. Seguridad: usuarios, roles, invitaciones y permisos.
2. Organizacion: empresas, vendedores y sucursales.
3. Clientes / Proveedores: crear, editar, ver, historico, baja y restauracion.
4. Marketing: campanias, leads, formularios, proteccion de bots y centro de eventos.
5. Ventas / Compras / Proyectos: flujos de estado y acciones transaccionales.

## Configuracion de notificaciones

### Verificado

- Tipos de notificacion consulta `GET /v1/notification-types`.
- Plantillas de notificacion consulta `GET /v1/notification-templates`.
- Perfiles de envio consulta `GET /v1/notification-sender-profiles`.
- Variables consulta `GET /v1/notification-template-variables`.
- Registros de envio consulta `GET /v1/notification-logs`.
- Las pantallas usan `AppPageScaffold`, busqueda, paginacion incremental y estados vacios/error comunes.

### Ajustado

- La pantalla de plantillas dejo de mostrar `Templates`; ahora usa textos en castellano: `Plantillas de notificacion`, `Buscar plantilla`, `Sin plantillas`.

### Pendiente para una pasada mas profunda

- Validar con datos reales si cada endpoint respeta tenant/seller y permisos.
- Revisar si tipos, plantillas, perfiles y variables necesitan acciones mobile de crear/editar o son solo lectura operativa.
- Revisar historico/cambio de estado si el backend lo expone para estos maestros.
