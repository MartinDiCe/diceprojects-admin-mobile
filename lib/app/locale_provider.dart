import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPrefKey = 'ui.locale';

const appSupportedLocales = [
  Locale('es'),
  Locale('en'),
  Locale('pt'),
];

class AppLocaleNotifier extends StateNotifier<Locale> {
  AppLocaleNotifier() : super(_deviceLocale()) {
    _load();
  }

  static Locale _deviceLocale() {
    final languageCode = ui.PlatformDispatcher.instance.locale.languageCode;
    return _normalize(languageCode);
  }

  static Locale _normalize(String? languageCode) {
    switch ((languageCode ?? '').toLowerCase()) {
      case 'en':
        return const Locale('en');
      case 'pt':
        return const Locale('pt');
      default:
        return const Locale('es');
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefKey);
    if (raw != null && raw.isNotEmpty) {
      state = _normalize(raw);
    }
  }

  Future<void> setLocale(Locale locale) async {
    final next = _normalize(locale.languageCode);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, next.languageCode);
  }
}

final appLocaleProvider =
    StateNotifierProvider<AppLocaleNotifier, Locale>((ref) {
  return AppLocaleNotifier();
});
