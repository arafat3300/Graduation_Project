import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:gradproj/Services/api_service.dart';
import '../models/Messages.dart';
import '../Controllers/user_controller.dart';

class MessagesScreen extends StatefulWidget {
  final int leadId;

  const MessagesScreen({super.key, required this.leadId});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late Future<List<Message>> _futureMessages;
final UserController _userController = UserController();
  @override
  void initState() {
    super.initState();
    Future email = _userController.getLoggedInUserEmail();
    print(email);
    _futureMessages = fetchMessages(); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.deepPurple,
      ),
      body: FutureBuilder<List<Message>>(
        future: _futureMessages,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          } else if (snapshot.hasData && snapshot.data!.isEmpty) {
            return const Center(child: Text('No messages found.'));
          }

          final messages = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final bool isAdmin = msg.author == "Administrator";

              return Align(
                alignment:
                    isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isAdmin
                        ? Colors.deepPurple.shade100
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isAdmin ? 16 : 0),
                      bottomRight: Radius.circular(isAdmin ? 0 : 16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isAdmin)
                        Text(
                          msg.author,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      Html(
                        data: msg.body.isNotEmpty
                            ? msg.body
                            : "<p><i>No content</i></p>",
                      ),
                      const SizedBox(height: 5),
                      Text(
                        msg.date,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
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
