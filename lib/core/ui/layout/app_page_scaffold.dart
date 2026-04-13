import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Standard page scaffold with flat white AppBar + optional search row in body.
/// The accent color is only used for actions (FAB, buttons), not chrome.
class AppPageScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final String? searchHint;
  final ValueChanged<String>? onSearch;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const AppPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.searchHint,
    this.onSearch,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final location = GoRouterState.of(context).matchedLocation;
    final isDashboard = location == '/dashboard';
    final canPop = router.canPop();
    final shouldInterceptSystemBack = !isDashboard && !canPop;

    void handleBack() {
      if (canPop) {
        context.pop();
        return;
      }
      if (!isDashboard) {
        context.go('/dashboard');
      }
    }

    return PopScope(
      canPop: !shouldInterceptSystemBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (shouldInterceptSystemBack) {
          handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: floatingActionButton == null
            ? null
            : SafeArea(top: false, child: floatingActionButton!),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: Column(
          children: [
            _FlatAppBar(
              title: title,
              actions: actions,
              isDashboard: isDashboard,
              onBack: handleBack,
            ),
            if (searchHint != null && onSearch != null)
              _SearchRow(hint: searchHint!, onChanged: onSearch!),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

// ── Flat white AppBar ─────────────────────────────────────────────────────────

class _FlatAppBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final bool isDashboard;
  final VoidCallback onBack;

  const _FlatAppBar({
    required this.title,
    this.actions,
    required this.isDashboard,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final overlay = (AppColors.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark)
        .copyWith(statusBarColor: Colors.transparent);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Container(
        padding: EdgeInsets.fromLTRB(4, topPadding + 2, 8, 0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            bottom: BorderSide(color: AppColors.border),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                isDashboard ? Icons.menu_rounded : Icons.arrow_back_rounded,
                color: AppColors.ink,
                size: 22,
              ),
              onPressed: isDashboard ? AppShell.openDrawer : onBack,
            ),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            if (actions != null) ...actions!,
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

// ── Search row (below AppBar, part of body section) ──────────────────────────

class _SearchRow extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchRow({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          style: TextStyle(color: AppColors.ink, fontSize: 14),
          cursorColor: AppColors.accent,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
            prefixIcon:
                Icon(Icons.search_rounded, color: AppColors.textMuted, size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
