# Flujo Sales / Marketing / Purchases / Organization

## Objetivo

Conectar el ciclo comercial completo:

1. Marketing captura o asocia un lead.
2. Sales trabaja la cotizacion.
3. Organization mantiene clientes, proveedores, contactos y direcciones.
4. Purchases solicita presupuestos a proveedores, compara y adjudica.

## Servicios y rutas

- Sales: `/api/v1/quotes`
- Marketing: `/api/v1/leads`
- Organization:
  - `/api/v1/suppliers`
  - `/api/v1/customers`
  - `/api/v1/sellers/{sellerId}/addresses`
- Purchases: `/api/v1/purchase-requests`
- Projects: `/api/v1/project-management`

Gateway debe exponer estas rutas contra los servicios internos correspondientes.

## Flujo Sales -> Purchases

Desde una cotizacion o solicitud comercial, el front debe permitir seleccionar items y generar una `PurchaseRequest` con:

- `tenantId` y `sellerId` del contexto activo.
- `sourceType = SALES_QUOTE`.
- `sourceId = quoteId`.
- Items con snapshot de descripcion, producto, presentacion, unidad y cantidad.
- Lista de `supplierIds`.

Purchases permite crear solicitud, enviar a proveedores, cargar presupuesto proveedor, comparar por total y adjudicar.

## Flujo Sales -> Marketing / Organization

Cuando una cotizacion viene de una oportunidad:

- Si no existe lead asociado, Sales debe crear/asociar lead en Marketing.
- Al ganar la cotizacion, Organization debe crear o actualizar `Customer`.
- El `Customer` puede guardar `leadId` para trazabilidad.
- Contactos y direcciones quedan como entidades hijas de `customers`.

## Permisos IAM

Authorization mantiene el catalogo canonico y roles seedeados:

- `PURCHASES_ADMIN`, `PURCHASES_EDITOR`, `PURCHASES_VIEWER`.
- `PROJECTS_ADMIN`, `PROJECTS_EDITOR`, `PROJECTS_VIEWER`.
- Roles de Organization incorporan `Suppliers`, `Customers` y `SellerAddresses`.

Los microservicios Purchases, Projects y Organization tambien registran sus permisos al iniciar para evitar drift entre servicios.

## Front

El backoffice debe tener:

- Organization: ABM de proveedores y clientes.
- Purchases: lista, detalle, carga de presupuesto, comparacion y adjudicacion.
- Projects: entrada de modulo para presupuestos/obras.

## Pendientes

- Boton en detalle de cotizacion para crear `PurchaseRequest` desde items seleccionados.
- Costo sugerido desde costos historicos/proveedor.
- Conversion automatica de lead a customer al ganar cotizacion.
- Tests de contrato entre Sales, Marketing, Purchases y Organization.
