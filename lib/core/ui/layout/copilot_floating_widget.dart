import 'dart:math' as math;

import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/features/manuals/presentation/screens/manuals_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CopilotFloatingWidget extends StatefulWidget {
  const CopilotFloatingWidget({super.key});

  @override
  State<CopilotFloatingWidget> createState() => _CopilotFloatingWidgetState();
}

class _CopilotFloatingWidgetState extends State<CopilotFloatingWidget> {
  static const _fabXKey = 'copilot.fab.x';
  static const _fabYKey = 'copilot.fab.y';
  static const _fabSize = 56.0;
  static const _fabMargin = 18.0;

  bool _isOpen = false;
  bool _hasEverOpened = false;
  Offset? _fabOffset;

  @override
  void initState() {
    super.initState();
    _loadFabOffset();
  }

  Future<void> _loadFabOffset() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_fabXKey);
    final y = prefs.getDouble(_fabYKey);
    if (!mounted || x == null || y == null) return;
    setState(() => _fabOffset = Offset(x, y));
  }

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

  Offset _defaultFabOffset(Size size, EdgeInsets padding) {
    return Offset(
      size.width - _fabSize - _fabMargin,
      size.height - padding.bottom - _fabSize - 22,
    );
  }

  Offset _clampFabOffset(Offset offset, Size size, EdgeInsets padding) {
    const minX = _fabMargin;
    final maxX = math.max(minX, size.width - _fabSize - _fabMargin);
    final minY = padding.top + 8;
    final maxY = math.max(minY, size.height - padding.bottom - _fabSize - 8);

    return Offset(
      offset.dx.clamp(minX, maxX),
      offset.dy.clamp(minY, maxY),
    );
  }

  void _moveFab(DragUpdateDetails details, Size size, EdgeInsets padding) {
    final current = _fabOffset ?? _defaultFabOffset(size, padding);
    setState(() {
      _fabOffset = _clampFabOffset(current + details.delta, size, padding);
    });
  }

  Future<void> _saveFabOffset() async {
    final offset = _fabOffset;
    if (offset == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fabXKey, offset.dx);
    await prefs.setDouble(_fabYKey, offset.dy);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final padding = media.padding;
    final fabOffset = _clampFabOffset(
      _fabOffset ?? _defaultFabOffset(size, padding),
      size,
      padding,
    );

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
            if (!_isOpen)
              _CopilotFab(
                offset: fabOffset,
                onTap: _open,
                onPanUpdate: (details) => _moveFab(details, size, padding),
                onPanEnd: (_) => _saveFabOffset(),
              ),
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
  final Offset offset;
  final VoidCallback onTap;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  const _CopilotFab({
    required this.offset,
    required this.onTap,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: SafeArea(
        top: false,
        child: Tooltip(
          message: 'Copiloto IA',
          child: Semantics(
            button: true,
            label: 'Abrir Copiloto IA',
            child: GestureDetector(
              onPanUpdate: onPanUpdate,
              onPanEnd: onPanEnd,
              child: FloatingActionButton(
                heroTag: 'copilot-floating-fab',
                onPressed: onTap,
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.white,
                elevation: 10,
                child: const Icon(Icons.auto_awesome_rounded),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
