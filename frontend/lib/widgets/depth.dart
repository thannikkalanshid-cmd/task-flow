import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Dark gradient background with soft colored glows.
class AppBackdrop extends StatelessWidget {
  final Widget? child;
  const AppBackdrop({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.bg,
        gradient: RadialGradient(
          center: const Alignment(-0.9, -1),
          radius: 1.3,
          colors: [AppColors.primary.withOpacity(.30), Colors.transparent],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(1, 0.9),
            radius: 1.1,
            colors: [AppColors.cyan.withOpacity(.14), Colors.transparent],
          ),
        ),
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

/// A raised card: gradient face, light edge and layered shadow.
class DepthCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  const DepthCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 26,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceHi, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(.10)),
        boxShadow: AppShadows.lift,
      ),
      child: child,
    );
  }
}

/// A pressable 3D "key" button. Needs a bounded width (Column / SizedBox).
class DepthButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final Color top;
  final Color bottom;
  final Color edge;
  final double height;

  const DepthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.top = const Color(0xFF7C83F7),
    this.bottom = AppColors.primary,
    this.edge = AppColors.primaryEdge,
    this.height = 52,
  });

  /// Matching color presets.
  const DepthButton.success({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.height = 52,
  })  : top = const Color(0xFF4ADE80),
        bottom = const Color(0xFF16A34A),
        edge = const Color(0xFF14532D);

  const DepthButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.height = 52,
  })  : top = const Color(0xFFF87171),
        bottom = const Color(0xFFDC2626),
        edge = const Color(0xFF7F1D1D);

  @override
  State<DepthButton> createState() => _DepthButtonState();
}

class _DepthButtonState extends State<DepthButton> {
  bool _down = false;
  static const double _depth = 5;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final radius = BorderRadius.circular(16);
    final travel = (_down && enabled) ? _depth : 0.0;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: enabled ? widget.onPressed : null,
      child: Opacity(
        opacity: enabled || widget.loading ? 1 : 0.55,
        child: SizedBox(
          width: double.infinity,
          height: widget.height + _depth,
          child: Stack(
            children: [
              Positioned.fill(
                top: _depth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.edge,
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: widget.bottom.withOpacity(.45),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 80),
                top: travel,
                left: 0,
                right: 0,
                height: widget.height,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [widget.top, widget.bottom],
                    ),
                    borderRadius: radius,
                    border: Border.all(color: Colors.white.withOpacity(.25)),
                  ),
                  child: widget.loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(widget.icon, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              widget.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                shadows: [
                                  Shadow(color: Colors.black38, offset: Offset(0, 1))
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tilts its child in 3D toward the finger while touched.
class TiltOnTouch extends StatefulWidget {
  final Widget child;
  const TiltOnTouch({super.key, required this.child});

  @override
  State<TiltOnTouch> createState() => _TiltOnTouchState();
}

class _TiltOnTouchState extends State<TiltOnTouch> {
  double _rx = 0;
  double _ry = 0;

  void _update(Offset p) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    setState(() {
      _ry = ((p.dx / box.size.width) - .5) * .6;
      _rx = -((p.dy / box.size.height) - .5) * .6;
    });
  }

  void _reset() => setState(() {
        _rx = 0;
        _ry = 0;
      });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) => _update(e.localPosition),
      onPointerMove: (e) => _update(e.localPosition),
      onPointerUp: (_) => _reset(),
      onPointerCancel: (_) => _reset(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transformAlignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateX(_rx)
          ..rotateY(_ry),
        child: widget.child,
      ),
    );
  }
}
