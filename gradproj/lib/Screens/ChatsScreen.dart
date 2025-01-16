import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gradproj/Models/singletonSession.dart';
import './ChatScreen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  _ChatsScreenState createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<dynamic> _chats = []; // Use dynamic to handle varied response structures
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = singletonSession().userId;

      // Fetch unique chats involving the current user
      final response = await supabase
          .from('messages')
          .select(
              'property_id, sender_id, rec_id, content, created_at') // Fetch specific fields
          .or('sender_id.eq.$userId,rec_id.eq.$userId')
          .order('created_at', ascending: false);

      if (response is List) {
        // Group chats by property_id and rec_id/sender_id
        final uniqueChats = <String, Map<String, dynamic>>{};
        for (var chat in response) {
          final chatKey =
              "${chat['property_id']}_${chat['sender_id']}_${chat['rec_id']}";
          if (!uniqueChats.containsKey(chatKey)) {
            uniqueChats[chatKey] = chat;
          }
        }

        setState(() {
          _chats = uniqueChats.values.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading chats: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: const Color(0xFF398AE5),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? const Center(
                  child: Text(
                    'No chats yet.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    final isMe =
                        chat['sender_id'] == singletonSession().userId;
                    final chatWith = isMe ? chat['rec_id'] : chat['sender_id'];

                    return ListTile(
                      leading: const Icon(Icons.chat),
                      title: Text('Chat with User ID: $chatWith'),
                      subtitle: Text(chat['content'] ?? 'No messages yet'),
                      onTap: () {
                        // Navigate to ChatScreen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              propertyId: chat['property_id'],
                              senderId: singletonSession().userId!,
                              receiverId: chatWith,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
