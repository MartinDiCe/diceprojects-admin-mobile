class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.diceprojects.com/api',
  );
  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://diceprojects.com/privacidad',
  );
  static const String contactUrl = String.fromEnvironment(
    'CONTACT_URL',
    defaultValue:
        'https://backoffice.diceprojects.com/public/lead-forms/diceprojects-backoffice-access',
  );
  static const String leadFormKey = String.fromEnvironment(
    'BACKOFFICE_ACCESS_LEAD_FORM_KEY',
    defaultValue: 'diceprojects-backoffice-access',
  );
  static const String publicWebBaseUrl = String.fromEnvironment(
    'PUBLIC_WEB_BASE_URL',
    defaultValue: 'https://backoffice.diceprojects.com',
  );
  static const String appVersionName = String.fromEnvironment(
    'APP_VERSION_NAME',
    defaultValue: '1.0.6',
  );
  static const String appBuildNumber = String.fromEnvironment(
    'APP_BUILD_NUMBER',
    defaultValue: '42',
  );
  static const String reviewerUsername = String.fromEnvironment(
    'REVIEWER_USERNAME',
    defaultValue: '',
  );
  static const String reviewerPassword = String.fromEnvironment(
    'REVIEWER_PASSWORD',
    defaultValue: '',
  );

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const String tokenKey = 'access_token';
  static const String refreshTokenKey = 'mobile_refresh_token';
  static const String refreshDeviceIdKey = 'mobile_refresh_device_id';
  static const String rememberLoginKey = 'auth_remember_login';
  static const String biometricLoginKey = 'auth_biometric_login';
  static const String rememberedUsernameKey = 'auth_remembered_username';
  static const String rememberedPasswordKey = 'auth_remembered_password';

  static const int defaultPageSize = 10;

  static String get publicLeadFormUrl {
    final explicit = contactUrl.trim();
    if (explicit.isNotEmpty && !explicit.endsWith('/contacto')) {
      return explicit;
    }
    final base = publicWebBaseUrl.endsWith('/')
        ? publicWebBaseUrl.substring(0, publicWebBaseUrl.length - 1)
        : publicWebBaseUrl;
    return '$base/public/lead-forms/$leadFormKey';
  }
}
