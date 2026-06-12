import 'dart:async';

import 'package:app_diceprojects_admin/app/router.dart';
import 'package:app_diceprojects_admin/app/theme.dart';
import 'package:app_diceprojects_admin/app/theme_mode_provider.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/notifications/data/notification_inbox_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> {
  StreamSubscription<RemoteMessage>? _foregroundPushSubscription;

  @override
  void initState() {
    super.initState();
    _foregroundPushSubscription = FirebaseMessaging.onMessage.listen((_) {
      if (ref.read(authNotifierProvider).isAuthenticated) {
        ref.read(notificationInboxProvider.notifier).refresh(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _foregroundPushSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    final platformBrightness = View.of(context).platformDispatcher.platformBrightness;
    final isDark = switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformBrightness == Brightness.dark,
    };

    AppColors.setVariant(isDark ? AppThemeVariant.dark : AppThemeVariant.light);

    return MaterialApp.router(
      key: ValueKey(isDark),
      title: 'DiceProjects Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
