
import 'package:flutter/material.dart';
import '../theme/atlas_theme.dart';

class AtlasOrb extends StatefulWidget {
  const AtlasOrb({
    super.key,
    this.size = 44,
  });

  final double size;

  @override
  State<AtlasOrb> createState() => _AtlasOrbState();
}

class _AtlasOrbState extends State<AtlasOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.94 + controller.value * 0.1,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AtlasColors.cyan,
                  AtlasColors.violet,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AtlasColors.cyan.withValues(alpha: 0.25),
                  blurRadius: 18 + controller.value * 10,
                ),
                BoxShadow(
                  color: AtlasColors.violet.withValues(alpha: 0.2),
                  blurRadius: 25,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: widget.size * 0.34,
                height: widget.size * 0.34,
                decoration: const BoxDecoration(
                  color: Color(0xFF07101D),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
