import 'package:flutter/material.dart';
import '../models/Messages.dart';
import '../services/api_service.dart';

class MessagesScreen extends StatefulWidget {
  final int leadId; // ID of the property inquiry (lead) from Odoo

  const MessagesScreen({super.key, required this.leadId});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late Future<List<Message>> _futureMessages;

  @override
  void initState() {
    super.initState();
    _futureMessages = fetchMessages(widget.leadId);
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
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  title: Text(msg.author),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.body,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        msg.date,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
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
