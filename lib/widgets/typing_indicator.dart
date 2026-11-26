import 'package:flutter/material.dart';

import '../theme/atlas_theme.dart';
import 'atlas_orb.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AtlasColors est une palette, pas une ThemeExtension.
    final colors = AtlasColors.of(context);

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AtlasOrb(size: 26),
          const SizedBox(width: 10),
          Text(
            'Atlas écrit…',
            style: TextStyle(color: colors.mute),
          ),
          const SizedBox(width: 8),
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final activeDot = (controller.value * 3).floor();

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  return Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AtlasColors.cyan.withValues(
                        alpha: activeDot == index ? 1.0 : 0.3,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}
