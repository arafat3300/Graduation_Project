class Message {
  final String author;
  final String body;
  final String date;

  Message({
    required this.author,
    required this.body,
    required this.date,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      author: json['author'] ?? 'Unknown',
      body: json['body'] ?? '',
      date: json['date'] ?? '',
    );
  }
}
