import 'package:app_diceprojects_admin/core/ui/layout/app_drawer.dart';
import 'package:flutter/material.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  static final _scaffoldKey = GlobalKey<ScaffoldState>();

  const AppShell({super.key, required this.child});

  static void openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      body: child,
    );
  }
}
