enum Role { user, assistant }

class Message {
  final Role role;
  String content;
  Message(this.role, this.content);
}
