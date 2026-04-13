/// Mapa de rutas a permisos requeridos (al menos uno debe estar presente)
const Map<String, List<String>> permissionGates = {
  '/iam/users': ['IAM.Users.List'],
  '/iam/invitations': ['IAM.Invitations.List', 'IAM.Invitations.Send'],
  '/authorization': ['IAM.Roles.List'],
  '/logs/audit': ['IAM.Audit.List'],
  '/logs/apitraces': ['Logs.ApiTraces.List'],
  '/logs/notifications': ['Logs.NotificationLogs.List'],
  '/admin/tenants': ['Organization.Listar', 'Organization.Admin'],
  '/admin/branches': ['Organization.Listar', 'Organization.Admin'],
  '/people': ['Persona.Ver'],
  '/products': ['Producto.VerProducto'],
  '/products/import': ['Producto.ImportarProductos'],
  '/marketing/leads': ['Marketing.VerLead'],
  '/marketing/destacados': ['Marketing.VerDestacados'],
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
