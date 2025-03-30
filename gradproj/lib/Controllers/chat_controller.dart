import 'package:supabase_flutter/supabase_flutter.dart';

class ChatController {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> fetchUserName(int userId) async {
    try {
      final response = await supabase
          .from('users')
          .select('firstname, lastname')
          .eq('id', userId)
          .single();

      if (response != null) {
        return {
          'fullName': '${response['firstname'] ?? 'Unknown'} ${response['lastname'] ?? 'User'}'
        };
      }
    } catch (e) {
      throw Exception('Error fetching user name for ID $userId: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> loadChats(int userId) async {
    final response = await supabase
        .from('messages')
        .select('property_id, sender_id, rec_id, content, created_at')
        .or('sender_id.eq.$userId,rec_id.eq.$userId')
        .order('created_at', ascending: false);

    final uniqueChats = <String, Map<String, dynamic>>{};
    for (var chat in response) {
      final chatKey =
          "${chat['property_id']}_${chat['sender_id']}_${chat['rec_id']}";
      if (!uniqueChats.containsKey(chatKey)) {
        uniqueChats[chatKey] = chat;
      }
    }
    return uniqueChats.values.toList();
  }

  Future<void> sendMessage({
    required int senderId,
    required int receiverId,
    required int propertyId,
    required String content,
  }) async {
    await supabase.from('messages').insert({
      'sender_id': senderId,
      'rec_id': receiverId,
      'property_id': propertyId,
      'content': content,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
