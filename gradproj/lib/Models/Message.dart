class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final int propertyId; // Changed to int to match the schema
  final String content;
  final DateTime createdAt;
  final String? senderName;
  final String? recrName;



  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.propertyId,
    required this.content,
    required this.createdAt,
    this.recrName,
    this.senderName
  });

  // Factory method to create a Message from a map
  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'].toString(),
      senderId: map['sender_id'].toString(),
      receiverId: map['rec_id'].toString(),
      propertyId: map['property_id'] as int,
      content: map['content'] as String,
      createdAt: map['created_at'] is DateTime
          ? map['created_at']
          : DateTime.parse(map['created_at'] as String),
    );
  }

  // Method to convert a Message into a map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'rec_id': receiverId,
      'property_id': propertyId, // Store property_id as int
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
