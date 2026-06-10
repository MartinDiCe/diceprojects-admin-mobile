/// Mapa de rutas a permisos requeridos (al menos uno debe estar presente)
const Map<String, List<String>> permissionGates = {
  '/iam/users/new': ['IAM.Users.Create', 'IAM.Invitations.Send', 'IAM.Users.Admin'],
  '/iam/users': ['IAM.Users.List', 'IAM.Users.View', 'IAM.Users.Admin'],
  '/iam/invitations': ['IAM.Invitations.List', 'IAM.Invitations.Send'],
  '/authorization': ['IAM.Roles.List'],
  '/logs/audit': ['IAM.Audit.List'],
  '/logs/apitraces': ['Logs.ApiTraces.List'],
  '/logs/notifications': ['Logs.NotificationLogs.List'],
  '/admin/tenants/new': [
    'Organization.Tenants.Create',
    'Organization.Admin',
  ],
  '/admin/tenants/': [
    'Organization.Tenants.Edit',
    'Organization.Admin',
  ],
  '/admin/tenants': [
    'Organization.Tenants.List',
    'Organization.Tenants.View',
    'Organization.Listar',
    'Organization.Admin',
  ],
  '/admin/branches': [
    'Organization.Branches.List',
    'Organization.Listar',
    'Organization.Admin',
  ],
  '/organization/sellers/new': [
    'Organization.Sellers.Create',
    'Organization.Admin',
  ],
  '/organization/sellers/': [
    'Organization.Sellers.Edit',
    'Organization.Admin',
  ],
  '/organization/sellers': [
    'Organization.Sellers.List',
    'Organization.Sellers.View',
    'Organization.Admin',
  ],
  '/people/new': ['People.Create', 'People.Admin'],
  '/people/': ['People.Edit', 'People.Admin'],
  '/people': ['People.List', 'People.View', 'Persona.Ver', 'People.Admin'],
  '/products/import': [
    'Products.Articles.Import',
    'Producto.ImportarProductos',
    'Products.Admin',
  ],
  '/products/new': [
    'Products.Articles.Create',
    'Producto.CrearProducto',
    'Products.Admin',
  ],
  '/products/': [
    'Products.Articles.Edit',
    'Producto.EditarProducto',
    'Products.Admin',
  ],
  '/products': [
    'Products.Articles.List',
    'Products.Articles.View',
    'Producto.VerProducto',
    'Products.Admin',
  ],
  '/sales/quotes': ['Sales.Quotes.List', 'Sales.Quotes.View', 'Sales.Admin'],
  '/warehouse/stock': [
    'Warehouse.Stock.List',
    'Warehouse.Stock.View',
    'Warehouse.Admin',
  ],
  '/warehouse': [
    'Warehouse.Warehouses.List',
    'Warehouse.Warehouses.View',
    'Warehouse.Admin',
  ],
  '/marketing/leads': [
    'Marketing.Leads.List',
    'Marketing.Leads.View',
    'Marketing.VerLead',
    'Marketing.Admin',
  ],
  '/marketing/destacados': [
    'Marketing.FeaturedProducts.List',
    'Marketing.FeaturedProducts.View',
    'Marketing.VerDestacados',
    'Marketing.Admin',
  ],
  '/notifications/types': ['Notification.Listar', 'Notification.Admin', 'Notificacion.VerTipos'],
  '/notifications/templates': ['Notification.Listar', 'Notification.Admin', 'Notificacion.VerPlantillas'],
  '/notifications/sender-profiles': [
    'Notification.Listar',
    'Notification.Admin'
  ],
  '/notifications/variables': [
    'Notification.Listar',
    'Notification.Admin',
    'Notificacion.VerPlantillas',
  ],
  '/core/currencies': ['Core.VerMoneda', 'Currencies.Admin'],
  '/core/languages': ['Core.VerIdioma', 'Languages.Admin'],
  '/core/geo/countries': ['Core.VerGeografia', 'Countries.Admin'],
  '/core/geo/states': ['Core.VerGeografia'],
  '/core/geo/cities': ['Core.VerGeografia'],
  '/core/toggles': ['Core.VerToggle', 'Core.Toggles.Admin'],
  '/core/parameters': ['Core.Parameters.Ver'],
};
