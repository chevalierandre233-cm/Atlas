import 'message.dart';

class Conversation {
  final int id;
  String title;
  bool pinned;
  String? serverId; // identifiant de la conversation côté serveur
  final List<Message> messages;
  Conversation(this.id, this.title,
      {this.pinned = false, List<Message>? messages})
      : messages = messages ?? [];
}
