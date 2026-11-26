import 'dart:convert';
import 'dart:io' show Platform;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// Couche service : communique avec le serveur ATLAS (port 3000).
class AtlasService {
  /// Windows : 127.0.0.1. Émulateur Android : 10.0.2.2 (= le PC).
  /// Téléphone Android réel : remplace cette adresse par l'IP Wi-Fi du PC.
  static String get baseUrl {
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://127.0.0.1:3000';
  }

  static Future<String> createConversation() async {
    final res = await http
        .post(Uri.parse('$baseUrl/conversations'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 201) {
      throw Exception('Création impossible (${res.statusCode}) : ${res.body}');
    }
    return jsonDecode(res.body)['conversation']['id'] as String;
  }

  /// Envoie du texte et, si nécessaire, des fichiers en multipart.
  /// La réponse reste lue progressivement pour conserver le streaming.
  static Stream<String> stream(
    String conversationId,
    String message, {
    List<PlatformFile> attachments = const [],
  }) async* {
    final client = http.Client();
    try {
      late http.StreamedResponse response;

      if (attachments.isEmpty) {
        final request = http.Request('POST', Uri.parse('$baseUrl/chat/stream'))
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode({
            'message': message,
            'conversationId': conversationId,
          });
        response = await client.send(request).timeout(const Duration(seconds: 120));
      } else {
        final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/chat/stream'))
          ..fields['message'] = message
          ..fields['conversationId'] = conversationId;

        for (final file in attachments) {
          final bytes = file.bytes;
          if (bytes == null) {
            throw Exception('Impossible de lire le fichier ${file.name}. Réessaie de le sélectionner.');
          }
          request.files.add(http.MultipartFile.fromBytes(
            'files',
            bytes,
            filename: file.name,
          ));
        }
        response = await client.send(request).timeout(const Duration(seconds: 180));
      }

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception('Serveur ${response.statusCode} : $body');
      }
      yield* response.stream.transform(utf8.decoder);
    } finally {
      client.close();
    }
  }
}
