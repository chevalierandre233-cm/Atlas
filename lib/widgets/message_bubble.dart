import 'package:flutter/material.dart';
import '../models/message.dart';
import '../theme/atlas_theme.dart';
import 'atlas_orb.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  /// Gardé pour compatibilité ; mettre false lorsque le streaming est désactivé.
  final bool streaming;

  const MessageBubble({super.key, required this.message, this.streaming = false});

  @override
  Widget build(BuildContext context) {
    final user = message.role == Role.user;
    final c = AtlasColors.of(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: child),
      ),
      child: Row(
        mainAxisAlignment: user ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!user) ...[
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: AtlasOrb(size: 28),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: user ? AtlasColors.gradient : null,
                  color: user ? null : c.panel,
                  border: user ? null : Border.all(color: c.line),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(user ? 18 : 4),
                    bottomRight: Radius.circular(user ? 4 : 18),
                  ),
                ),
                child: SelectableText(
                  message.content + (streaming ? ' ▍' : ''),
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.5,
                    color: user ? Colors.white : c.fg,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
