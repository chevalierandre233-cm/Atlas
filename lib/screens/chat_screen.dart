import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../services/atlas_service.dart';
import '../theme/atlas_theme.dart';
import '../widgets/atlas_orb.dart';
import '../widgets/input_bar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/sidebar.dart';
import '../widgets/typing_indicator.dart';

class ChatScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  const ChatScreen({super.key, required this.isDark, required this.onToggleTheme});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scroll = ScrollController();
  bool _busy = false;
  int _activeId = 1;
  final List<Conversation> _convs = [
    Conversation(1, 'Nouvelle conversation'),
  ];

  static const _suggestions = [
    ('Organiser ma semaine', 'Priorités, créneaux, pauses'),
    ('Expliquer un concept', 'Simple, avec des exemples'),
    ('Relire un texte', 'Clarté, ton, fautes'),
    ('Trouver des idées', 'Projets, noms, cadeaux'),
  ];

  Conversation get _conv => _convs.firstWhere((c) => c.id == _activeId);

  void _newConv() => setState(() {
        final c = Conversation(DateTime.now().millisecondsSinceEpoch, 'Nouvelle conversation');
        _convs.insert(0, c);
        _activeId = c.id;
      });

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      });

  Future<void> _send(String text, [List<PlatformFile> attachments = const []]) async {
    if (text.trim().isEmpty && attachments.isEmpty) return;
    final conv = _conv;
    final displayText = [
      text.trim(),
      if (attachments.isNotEmpty) '📎 ${attachments.map((file) => file.name).join(', ')}',
    ].where((part) => part.isNotEmpty).join('\n');
    final reply = Message(Role.assistant, '');
    setState(() {
      if (conv.messages.isEmpty) {
        final titleSource = text.trim().isNotEmpty ? text.trim() : attachments.first.name;
        conv.title = titleSource.length > 32 ? titleSource.substring(0, 32) : titleSource;
      }
      conv.messages
        ..add(Message(Role.user, displayText))
        ..add(reply);
      _busy = true;
    });
    _scrollDown();
    try {
      // La conversation est créée sur le serveur au premier message.
      conv.serverId ??= await AtlasService.createConversation();
      await for (final chunk in AtlasService.stream(
        conv.serverId!,
        text,
        attachments: attachments,
      )) {
        if (!mounted) return;
        setState(() => reply.content += chunk);
        _scrollDown();
      }
    } catch (error) {
      if (mounted) {
        setState(() => reply.content += reply.content.isEmpty
            ? 'Impossible d’envoyer le message : $error'
            : '\n\n[Réponse interrompue : $error]');
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _sidebar({bool closeOnSelect = false}) => Sidebar(
        convs: _convs,
        activeId: _activeId,
        isDark: widget.isDark,
        onToggleTheme: widget.onToggleTheme,
        onNew: () {
          _newConv();
          if (closeOnSelect) Navigator.pop(context);
        },
        onSelect: (id) {
          setState(() => _activeId = id);
          if (closeOnSelect) Navigator.pop(context);
        },
      );

  Widget _welcome(AtlasColors c) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutBack,
                builder: (_, v, child) => Opacity(
                    opacity: v.clamp(0.0, 1.0),
                    child: Transform.scale(scale: .8 + .2 * v, child: child)),
                child: const AtlasOrb(size: 96),
              ),
              const SizedBox(height: 56),
              Text('Bonjour, que veux-tu faire aujourd’hui ?',
                  textAlign: TextAlign.center, style: AtlasTheme.display(30, c.fg)),
              const SizedBox(height: 12),
              Text('Choisis un point de départ ou écris directement ta demande.',
                  textAlign: TextAlign.center, style: TextStyle(color: c.mute)),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final s in _suggestions)
                    SizedBox(
                      width: 300,
                      child: Material(
                        color: c.panel,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: c.line),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          hoverColor: AtlasColors.violet.withValues(alpha: .10),
                          onTap: _busy ? null : () => _send(s.$1),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(s.$2, style: TextStyle(color: c.mute, fontSize: 13.5)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messages() {
    final conv = _conv;
    final last = conv.messages.last;
    final waiting = _busy && last.role == Role.assistant && last.content.isEmpty;
    final visible = conv.messages
        .where((m) => !(m.role == Role.assistant && m.content.isEmpty))
        .toList();
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      itemCount: visible.length + (waiting ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (_, i) {
        if (i == visible.length) return const TypingIndicator();
        final m = visible[i];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: MessageBubble(message: m, streaming: _busy && identical(m, last)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AtlasColors.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final main = Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.3),
          radius: 1.0,
          colors: [Color(0x384338CA), Colors.transparent],
        ),
      ),
      child: Column(children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: KeyedSubtree(
              key: ValueKey(_activeId),
              child: _conv.messages.isEmpty ? _welcome(c) : _messages(),
            ),
          ),
        ),
        InputBar(onSend: (text, files) => _send(text, files), busy: _busy),
      ]),
    );

    return Scaffold(
      backgroundColor: c.bg,
      appBar: wide
          ? null
          : AppBar(
              backgroundColor: c.bg,
              elevation: 0,
              title: Text('Atlas', style: AtlasTheme.display(18, c.fg)),
            ),
      drawer: wide ? null : Drawer(backgroundColor: c.panel, child: _sidebar(closeOnSelect: true)),
      body: wide ? Row(children: [_sidebar(), Expanded(child: main)]) : main,
    );
  }
}
