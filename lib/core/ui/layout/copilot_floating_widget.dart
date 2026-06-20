import 'dart:math' as math;

import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/features/manuals/presentation/screens/manuals_screen.dart';
import 'package:flutter/material.dart';

class CopilotFloatingWidget extends StatefulWidget {
  const CopilotFloatingWidget({super.key});

  @override
  State<CopilotFloatingWidget> createState() => _CopilotFloatingWidgetState();
}

class _CopilotFloatingWidgetState extends State<CopilotFloatingWidget> {
  bool _isOpen = false;
  bool _hasEverOpened = false;

  void _open() {
    setState(() {
      _isOpen = true;
      _hasEverOpened = true;
    });
  }

  void _minimize() {
    if (!mounted || !_isOpen) return;
    setState(() => _isOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: PopScope(
        canPop: !_isOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _isOpen) {
            _minimize();
          }
        },
        child: Stack(
          children: [
            if (_isOpen)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _minimize,
                  child: Container(color: Colors.black.withValues(alpha: 0.18)),
                ),
              ),
            if (_isOpen || _hasEverOpened)
              _FloatingPanel(
                isOpen: _isOpen,
                hasEverOpened: _hasEverOpened,
                onClose: _minimize,
                onMinimize: _minimize,
              ),
            if (!_isOpen) _CopilotFab(onTap: _open),
          ],
        ),
      ),
    );
  }
}

class _FloatingPanel extends StatelessWidget {
  final bool isOpen;
  final bool hasEverOpened;
  final VoidCallback onClose;
  final VoidCallback onMinimize;

  const _FloatingPanel({
    required this.isOpen,
    required this.hasEverOpened,
    required this.onClose,
    required this.onMinimize,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final height = media.size.height;
    final panelWidth = math.min(width - 20, 460.0);
    final panelHeight = width < 720
        ? math.min(height * 0.84, height - media.padding.top - 18)
        : math.min(height - 120, 640.0);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: width < 720 ? 10 : null,
      right: 10,
      bottom: isOpen ? 0 : -panelHeight - 24,
      width: width < 720 ? null : panelWidth,
      height: panelHeight,
      child: Material(
        color: AppColors.background,
        elevation: 20,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: hasEverOpened
            ? BackofficeCopilotPanel(
                showHeader: true,
                onClose: onClose,
                onMinimize: onMinimize,
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _CopilotFab extends StatelessWidget {
  final VoidCallback onTap;

  const _CopilotFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Positioned(
      right: 18,
      bottom: bottomPadding + 22,
      child: SafeArea(
        top: false,
        child: FloatingActionButton.extended(
          heroTag: 'copilot-floating-fab',
          onPressed: onTap,
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.white,
          elevation: 10,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text(
            'Chat IA',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
