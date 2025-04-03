import 'package:flutter/material.dart';
import 'package:gradproj/Controllers/chat_controller.dart';
import 'package:gradproj/Models/singletonSession.dart';
import './ChatScreen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  _ChatsScreenState createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<dynamic> _chats = [];
  bool _isLoading = true;
  Map<int, String> userNames = {};
  final ChatController _chatController = ChatController();

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      final userId = singletonSession().userId;
      if (userId == null) return;

      final loadedChats = await _chatController.loadChats(userId);

      // Preload names for all users in chats
      for (var chat in loadedChats) {
        final senderName = await _chatController.fetchUserName(chat['sender_id']);
        final receiverName = await _chatController.fetchUserName(chat['rec_id']);
        
        if (senderName != null) {
          userNames[chat['sender_id']] = senderName['fullName'];
        }
        if (receiverName != null) {
          userNames[chat['rec_id']] = receiverName['fullName'];
        }
      }

      setState(() {
        _chats = loadedChats;
        _isLoading = false;
      });
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
                    final isMe = chat['sender_id'] == singletonSession().userId;
                    final chatWith = isMe ? chat['rec_id'] : chat['sender_id'];
                    final userName = userNames[chatWith] ?? 'Loading...';

                    return ListTile(
                      leading: const Icon(Icons.chat),
                      title: Text('Chat with $userName'),
                      subtitle: Text(chat['content'] ?? 'No messages yet'),
                      onTap: () {
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

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }
}
