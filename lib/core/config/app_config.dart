class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.diceprojects.com/api',
  );

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const String tokenKey = 'access_token';
  static const String rememberLoginKey = 'auth_remember_login';
  static const String rememberedUsernameKey = 'auth_remembered_username';
  static const String rememberedPasswordKey = 'auth_remembered_password';

  static const int defaultPageSize = 10;
}
