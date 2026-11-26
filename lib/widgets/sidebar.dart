import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../theme/atlas_theme.dart';
import 'atlas_orb.dart';

class Sidebar extends StatelessWidget {
  final List<Conversation> convs;
  final int activeId;
  final bool isDark;
  final ValueChanged<int> onSelect;
  final VoidCallback onNew;
  final VoidCallback onToggleTheme;

  const Sidebar({
    super.key,
    required this.convs,
    required this.activeId,
    required this.isDark,
    required this.onSelect,
    required this.onNew,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final c = AtlasColors.of(context);
    final pinned = convs.where((e) => e.pinned).toList();
    final rest = convs.where((e) => !e.pinned).toList();

    Widget item(Conversation e) => _Tile(
          label: e.title,
          selected: e.id == activeId,
          onTap: () => onSelect(e.id),
        );

    return Container(
      width: 288,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.panel,
        border: Border(right: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const AtlasOrb(size: 34),
              const SizedBox(width: 12),
              Text('Atlas', style: AtlasTheme.display(18, c.fg)),
            ]),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: AtlasColors.gradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onNew,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Nouvelle conversation',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  if (pinned.isNotEmpty) ...[
                    _Heading('Épinglées', c.mute, Icons.push_pin_outlined),
                    ...pinned.map(item),
                    const SizedBox(height: 16),
                  ],
                  _Heading('Récentes', c.mute, null),
                  ...rest.map(item),
                  if (convs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Aucune conversation pour le moment.',
                          style: TextStyle(color: c.mute, fontSize: 13)),
                    ),
                ],
              ),
            ),
            Divider(color: c.line),
            _Tile(label: 'Paramètres', icon: Icons.settings_outlined, onTap: () {}),
            _Tile(
              label: isDark ? 'Mode clair' : 'Mode sombre',
              icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              onTap: onToggleTheme,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: AtlasColors.gradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Votre profil', style: TextStyle(fontSize: 14)),
                  Text('Compte local', style: TextStyle(fontSize: 12, color: c.mute)),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const _Heading(this.text, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
          ],
          Text(text, style: TextStyle(fontSize: 12, color: color)),
        ]),
      );
}

class _Tile extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _Tile({required this.label, required this.onTap, this.icon, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AtlasColors.violet.withValues(alpha: .14) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        hoverColor: AtlasColors.violet.withValues(alpha: .10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 12)],
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14))),
          ]),
        ),
      ),
    );
  }
}
