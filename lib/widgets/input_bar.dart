import 'dart:io' show Platform;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../theme/atlas_theme.dart';

/// Zone de saisie : texte, pièces jointes et dictée vocale.
/// Entrée envoie ; Maj + Entrée ajoute une nouvelle ligne sur ordinateur.
class InputBar extends StatefulWidget {
  final void Function(String text, List<PlatformFile> attachments) onSend;
  final bool busy;

  const InputBar({super.key, required this.onSend, required this.busy});

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  final _ctrl = TextEditingController();
  late final FocusNode _focus;
  final List<PlatformFile> _attachments = [];
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _hasText = false;
  bool _listening = false;
  bool _speechInitialized = false;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode(onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        _submit();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    });
    _focus.addListener(_refresh);
    _ctrl.addListener(_refresh);
  }

  void _refresh() {
    if (!mounted) return;
    final has = _ctrl.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  Future<void> _pickFiles() async {
    if (widget.busy || _picking) return;
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'txt', 'png', 'jpg', 'jpeg', 'webp'],
        allowMultiple: true,
        withData: true,
      );
      if (result == null || !mounted) return;

      final accepted = <PlatformFile>[];
      var exceededLimit = false;
      for (final file in result.files) {
        if (file.size > 12 * 1024 * 1024) {
          _showMessage('${file.name} dépasse la limite de 12 Mo.');
        } else if (file.bytes == null) {
          _showMessage('Impossible de lire ${file.name}. Réessaie.');
        } else if (_attachments.length + accepted.length < 5) {
          accepted.add(file);
        } else {
          exceededLimit = true;
        }
      }
      setState(() => _attachments.addAll(accepted));
      if (exceededLimit) _showMessage('ATLAS accepte au maximum 5 fichiers par message.');
    } catch (error) {
      _showMessage('Sélection impossible : $error');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _toggleDictation() async {
    if (widget.busy) return;

    // speech_to_text ne fournit pas de moteur Windows desktop fiable.
    if (!kIsWeb && Platform.isWindows) {
      _showMessage('La dictée vocale est actuellement disponible sur Android, pas sur Windows.');
      return;
    }

    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    try {
      if (!_speechInitialized) {
        _speechInitialized = await _speech.initialize(
          onStatus: (status) {
            if ((status == 'done' || status == 'notListening') && mounted) {
              setState(() => _listening = false);
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() => _listening = false);
              _showMessage('Erreur microphone : ${error.errorMsg}');
            }
          },
        );
      }
      if (!_speechInitialized) {
        _showMessage('Reconnaissance vocale indisponible. Vérifie les autorisations du microphone.');
        return;
      }

      setState(() => _listening = true);
      await _speech.listen(
        localeId: 'fr_FR',
        listenFor: const Duration(minutes: 1),
        pauseFor: const Duration(seconds: 4),
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _ctrl.text = result.recognizedWords;
            _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
          });
        },
      );
    } catch (error) {
      if (mounted) {
        setState(() => _listening = false);
        _showMessage('Impossible de démarrer le microphone : $error');
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if ((text.isEmpty && _attachments.isEmpty) || widget.busy) return;
    if (_listening) _speech.stop();
    widget.onSend(text, List<PlatformFile>.from(_attachments));
    _ctrl.clear();
    setState(() => _attachments.clear());
  }

  @override
  void dispose() {
    _ctrl.removeListener(_refresh);
    _focus.removeListener(_refresh);
    _ctrl.dispose();
    _focus.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AtlasColors.of(context);
    final focused = _focus.hasFocus;
    final canSend = (_hasText || _attachments.isNotEmpty) && !widget.busy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_attachments.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final file in _attachments)
                          Chip(
                            avatar: const Icon(Icons.insert_drive_file_outlined, size: 17),
                            label: SizedBox(
                              width: 125,
                              child: Text(file.name, overflow: TextOverflow.ellipsis),
                            ),
                            onDeleted: widget.busy
                                ? null
                                : () => setState(() => _attachments.remove(file)),
                          ),
                      ],
                    ),
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: c.panel,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: _listening ? Colors.redAccent : (focused ? AtlasColors.violet : c.line)),
                  boxShadow: focused
                      ? [BoxShadow(color: AtlasColors.violet.withValues(alpha: .3), blurRadius: 26)]
                      : [],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Joindre un fichier',
                      onPressed: widget.busy || _picking ? null : _pickFiles,
                      icon: _picking
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(Icons.attach_file, color: c.mute),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          minLines: 1,
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                          cursorColor: AtlasColors.violetLight,
                          decoration: InputDecoration(
                            hintText: 'Écris à Atlas…',
                            hintStyle: TextStyle(color: c.mute),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _listening ? 'Arrêter la dictée' : 'Dicter un message',
                      onPressed: widget.busy ? null : _toggleDictation,
                      icon: Icon(_listening ? Icons.mic : Icons.mic_none,
                          color: _listening ? Colors.redAccent : c.mute),
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: canSend ? 1 : .4,
                      child: Tooltip(
                        message: 'Envoyer',
                        child: GestureDetector(
                          onTap: canSend ? _submit : null,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: canSend ? AtlasColors.gradient : null,
                              color: canSend ? null : AtlasColors.violet.withValues(alpha: .3),
                              shape: BoxShape.circle,
                              boxShadow: canSend
                                  ? [BoxShadow(color: AtlasColors.violet.withValues(alpha: .45), blurRadius: 18)]
                                  : [],
                            ),
                            child: const Icon(Icons.arrow_upward, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Entrée pour envoyer, Maj + Entrée pour un retour à la ligne',
                style: TextStyle(color: c.mute, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
