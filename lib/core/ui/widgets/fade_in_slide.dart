import 'package:flutter/material.dart';

/// Wraps [child] with a fade + slide-up entrance animation.
/// Use [delay] (seconds) to stagger multiple items.
class FadeInSlide extends StatefulWidget {
  final Widget child;
  final int durationMs;
  final double delay;
  final Offset beginOffset;

  const FadeInSlide({
    super.key,
    required this.child,
    this.durationMs = 380,
    this.delay = 0,
    this.beginOffset = const Offset(0, 0.06),
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.durationMs),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _offset = Tween<Offset>(begin: widget.beginOffset, end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    if (widget.delay > 0) {
      Future.delayed(
        Duration(milliseconds: (widget.delay * 1000).round()),
        () {
          if (mounted) _ctrl.forward();
        },
      );
    } else {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
