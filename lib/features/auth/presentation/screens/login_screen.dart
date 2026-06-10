import 'dart:async';

import 'package:app_diceprojects_admin/app/theme_mode_provider.dart';
import 'package:app_diceprojects_admin/core/config/app_config.dart';
import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/fade_in_slide.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _rememberLogin = false;
  bool _biometricAvailable = false;
  bool _loadingBiometric = false;
  StreamSubscription<Uri>? _appLinkSub;

  @override
  void initState() {
    super.initState();
    _hydrateSavedLogin();
    _listenOAuthCallback();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    _appLinkSub?.cancel();
    super.dispose();
  }

  void _listenOAuthCallback() {
    final appLinks = AppLinks();
    appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleOAuthCallback(uri);
    }).catchError((_) {});
    _appLinkSub = appLinks.uriLinkStream.listen(_handleOAuthCallback);
  }

  Future<void> _handleOAuthCallback(Uri uri) async {
    if (uri.scheme != 'diceprojects' ||
        uri.host != 'oauth2' ||
        !uri.path.startsWith('/callback')) {
      return;
    }
    final fragment = Uri.splitQueryString(uri.fragment);
    final token = fragment['access_token'] ?? fragment['accessToken'];
    final authError = fragment['authError'];
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authError == null || authError.isEmpty
              ? 'No se pudo completar Google login.'
              : 'Google login rechazado: $authError'),
        ),
      );
      return;
    }
    await ref.read(authNotifierProvider.notifier).loginWithToken(token);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final loggedIn = await ref.read(authNotifierProvider.notifier).login(
          _usernameCtrl.text.trim(),
          _passwordCtrl.text.trimRight(),
        );
    if (!loggedIn) return;
    final biometricEnabled = await _offerBiometricEnrollmentIfAvailable();
    await _persistRememberedLoginIfNeeded(
      preserveBiometricCredentials: biometricEnabled,
    );
  }

  Future<void> _hydrateSavedLogin() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final remember =
          (await storage.read(AppConfig.rememberLoginKey)) == 'true';
      final biometricEnabled =
          (await storage.read(AppConfig.biometricLoginKey)) == 'true';
      final username = await storage.read(AppConfig.rememberedUsernameKey);
      final password = await storage.read(AppConfig.rememberedPasswordKey);
      final localAuth = LocalAuthentication();
      final supported = await localAuth.isDeviceSupported();
      final canCheck = await localAuth.canCheckBiometrics;
      if (!mounted) return;
      setState(() {
        _rememberLogin = remember;
        if (remember && username != null) _usernameCtrl.text = username;
        if (remember && password != null) _passwordCtrl.text = password;
        _biometricAvailable = biometricEnabled &&
            (username?.isNotEmpty ?? false) &&
            (password?.isNotEmpty ?? false) &&
            supported &&
            canCheck;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _biometricAvailable = false);
    }
  }

  Future<void> _persistRememberedLoginIfNeeded({
    bool preserveBiometricCredentials = false,
  }) async {
    final auth = ref.read(authNotifierProvider);
    final storage = ref.read(secureStorageProvider);
    if (!auth.isAuthenticated || auth.error != null) return;
    if (_rememberLogin) {
      await storage.write(AppConfig.rememberLoginKey, 'true');
      await storage.write(
          AppConfig.rememberedUsernameKey, _usernameCtrl.text.trim());
      await storage.write(
          AppConfig.rememberedPasswordKey, _passwordCtrl.text.trimRight());
    } else {
      await storage.write(AppConfig.rememberLoginKey, 'false');
      if (!preserveBiometricCredentials) {
        await storage.delete(AppConfig.biometricLoginKey);
        await storage.delete(AppConfig.rememberedUsernameKey);
        await storage.delete(AppConfig.rememberedPasswordKey);
      }
    }
    await _hydrateSavedLogin();
  }

  Future<bool> _offerBiometricEnrollmentIfAvailable() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final alreadyEnabled =
          (await storage.read(AppConfig.biometricLoginKey)) == 'true';
      if (alreadyEnabled) return true;

      final localAuth = LocalAuthentication();
      final supported = await localAuth.isDeviceSupported();
      final canCheck = await localAuth.canCheckBiometrics;
      if (!supported || !canCheck || !mounted) return false;

      final shouldEnable = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Activar ingreso con huella'),
          content: const Text(
            'Podés asociar este dispositivo a tu cuenta para ingresar con huella o biometría la próxima vez.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Activar'),
            ),
          ],
        ),
      );
      if (shouldEnable != true) return false;

      final authenticated = await localAuth.authenticate(
        localizedReason: 'Confirmá tu huella para activar el ingreso biométrico',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!authenticated) return false;

      await storage.write(AppConfig.biometricLoginKey, 'true');
      await storage.write(
          AppConfig.rememberedUsernameKey, _usernameCtrl.text.trim());
      await storage.write(
          AppConfig.rememberedPasswordKey, _passwordCtrl.text.trimRight());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loginWithBiometric() async {
    if (_loadingBiometric) return;
    setState(() => _loadingBiometric = true);
    try {
      final authenticated = await LocalAuthentication().authenticate(
        localizedReason: 'Usá tu huella para ingresar a DiceProjects',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!authenticated) return;
      final storage = ref.read(secureStorageProvider);
      final username = await storage.read(AppConfig.rememberedUsernameKey);
      final password = await storage.read(AppConfig.rememberedPasswordKey);
      if (username == null || password == null) return;
      _usernameCtrl.text = username;
      _passwordCtrl.text = password;
      await ref.read(authNotifierProvider.notifier).login(username, password);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo validar la huella en este dispositivo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingBiometric = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    final baseUrl = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
        : AppConfig.apiBaseUrl;
    final uri = Uri.parse('$baseUrl/auth/oauth2/google?client=mobile');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Gmail / Google.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final themeMode = ref.watch(themeModeProvider);
    final padding = MediaQuery.of(context).padding;
    final isDarkTheme = themeMode == ThemeMode.dark;
    final screenBg = isDarkTheme ? AppColors.background : AppColors.white;
    final formCardBg = AppColors.surfaceVariant;
    final logoBlendBg = isDarkTheme
        ? AppColors.surface.withValues(alpha: 0.65)
        : AppColors.surfaceVariant.withValues(alpha: 0.55);
    final logoBlendBorder = AppColors.border.withValues(alpha: 0.60);

    Widget logoImage = Image.asset(
      'assets/logo_lineal.png',
      height: 80,
      fit: BoxFit.contain,
    );
    if (isDarkTheme) {
      logoImage = ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        child: logoImage,
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: screenBg,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    padding.top -
                    padding.bottom,
              ),
              child: IntrinsicHeight(
                child: FadeInSlide(
                  delay: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Form(
                      key: _formKey,
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 18),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: IconButton(
                                  tooltip:
                                      isDarkTheme ? 'Modo claro' : 'Modo oscuro',
                                  onPressed: () => ref
                                      .read(themeModeProvider.notifier)
                                      .toggle(),
                                  icon: Icon(
                                    isDarkTheme
                                        ? Icons.light_mode_rounded
                                        : Icons.dark_mode_rounded,
                                    color: AppColors.accent,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 34),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: logoBlendBg,
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(color: logoBlendBorder),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x0D000000),
                                          blurRadius: 18,
                                          offset: Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 18,
                                    ),
                                    child: Center(child: logoImage),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Ingresar',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Accedé al panel de gestión con tu cuenta.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 26),
                            Container(
                              decoration: BoxDecoration(
                                color: formCardBg,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.border),
                              ),
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                children: [
                                  _LabelledField(
                                    label: 'Usuario',
                                    controller: _usernameCtrl,
                                    hint: 'Usuario o correo',
                                    helper: 'Ej: usuario@dominio.com',
                                    prefixIcon: Icons.person_outline_rounded,
                                    keyboardType:
                                        TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autofillHints:
                                        const [AutofillHints.username],
                                    onFieldSubmitted: (_) =>
                                        FocusScope.of(context)
                                            .requestFocus(_passwordFocus),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Ingresá tu usuario'
                                            : null,
                                  ),
                                  const SizedBox(height: 12),
                                  _LabelledField(
                                    label: 'Contraseña',
                                    controller: _passwordCtrl,
                                    hint: 'Contraseña',
                                    helper: 'Tu contraseña de acceso',
                                    prefixIcon:
                                        Icons.lock_outline_rounded,
                                    focusNode: _passwordFocus,
                                    obscureText: _obscure,
                                    textInputAction: TextInputAction.done,
                                    autofillHints:
                                        const [AutofillHints.password],
                                    onFieldSubmitted: (_) => _submit(),
                                    toggleObscure: () => setState(
                                        () => _obscure = !_obscure),
                                    validator: (v) =>
                                        (v == null || v.isEmpty)
                                            ? 'Ingresá tu contraseña'
                                            : null,
                                  ),
                                  if (auth.error != null) ...[
                                    const SizedBox(height: 12),
                                    _InlineError(message: auth.error!),
                                  ],
                                  const SizedBox(height: 18),
                                  _LoginButton(
                                    isLoading: auth.isLoading,
                                    onPressed: _submit,
                                  ),

                                  const SizedBox(height: 10),
                                  _RememberRow(
                                    value: _rememberLogin,
                                    onChanged: (value) {
                                      setState(() => _rememberLogin = value);
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _SecondaryLoginButton(
                                          icon: Icons.mail_outline_rounded,
                                          label: 'Gmail',
                                          onPressed:
                                              auth.isLoading ? null : _loginWithGoogle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _SecondaryLoginButton(
                                          icon: Icons.fingerprint_rounded,
                                          label: 'Huella',
                                          isLoading: _loadingBiometric,
                                          onPressed: auth.isLoading ||
                                                  !_biometricAvailable
                                              ? null
                                              : _loginWithBiometric,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  TextButton(
                                    onPressed: () {
                                      showDialog<void>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text(
                                            'Recuperar contraseña',
                                          ),
                                          content: const Text(
                                            'Por ahora la recuperación de contraseña no está disponible desde la app.\n\nContactá a soporte o a un administrador para resetear tu acceso.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(),
                                              child: const Text('Entendido'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.accent,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    child: const Text(
                                      '¿Olvidaste tu contraseña?',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Center(
                                child: Text(
                                  'DiceProjects © 2026',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Login options ────────────────────────────────────────────────────────────

class _RememberRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _RememberRow({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: value,
              activeColor: AppColors.accent,
              onChanged: (next) => onChanged(next ?? false),
            ),
            Expanded(
              child: Text(
                'Recordar usuario y contraseña en este dispositivo',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryLoginButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _SecondaryLoginButton({
    required this.icon,
    required this.label,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          disabledForegroundColor: AppColors.textMuted,
          backgroundColor: AppColors.surface,
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        icon: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              )
            : Icon(icon, size: 18, color: AppColors.accent),
        label: Text(label),
      ),
    );
  }
}

// ── Labelled Input Field ──────────────────────────────────────────────────────

class _LabelledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final String? helper;
  final IconData? prefixIcon;
  final bool obscureText;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final List<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final VoidCallback? toggleObscure;
  final String? Function(String?)? validator;

  const _LabelledField({
    required this.label,
    required this.controller,
    required this.hint,
    this.helper,
    this.prefixIcon,
    this.obscureText = false,
    this.focusNode,
    this.textInputAction,
    this.keyboardType,
    this.autofillHints,
    this.onFieldSubmitted,
    this.toggleObscure,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDarkTheme ? AppColors.surface : AppColors.white;

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      validator: validator,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      onFieldSubmitted: onFieldSubmitted,
      style: TextStyle(
        color: AppColors.ink,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        hintText: hint,
        prefixIcon: prefixIcon == null
            ? null
          : Icon(prefixIcon, color: AppColors.accent, size: 20),
        hintStyle: TextStyle(
          color: AppColors.textMuted,
          fontSize: 15,
        ),
        labelStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        helperStyle: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
        ),
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.accent,
                  size: 20,
                ),
                onPressed: toggleObscure,
              )
            : null,
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppColors.borderFocus, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
        errorStyle: const TextStyle(
          color: AppColors.error,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ── Inline Error ──────────────────────────────────────────────────────────────

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.error_outline_rounded,
            size: 15,
            color: AppColors.error,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Login button ──────────────────────────────────────────────────────────────

class _LoginButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  const _LoginButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          disabledBackgroundColor: AppColors.border,
          foregroundColor: Colors.white,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ingresar',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    );
  }
}


