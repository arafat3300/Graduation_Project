import 'package:flutter/material.dart';
import 'package:gradproj/Screens/MessagesScreen.dart';
import 'package:gradproj/Services/api_service.dart';
import 'package:gradproj/Models/singletonSession.dart';

class LeadListScreen extends StatelessWidget {
  const LeadListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = singletonSession().userId;

    if (userId == null) {
      return const Scaffold(body: Center(child: Text("User not logged in.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Leads"),
        backgroundColor: Colors.deepPurple,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchLeadsByUser(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(child: Text("Error: ${snapshot.error}"));

          final leads = snapshot.data!;
          if (leads.isEmpty) return const Center(child: Text("No leads found."));

          return ListView.builder(
            itemCount: leads.length,
            itemBuilder: (context, index) {
              final lead = leads[index];
              return ListTile(
                title: Text(lead['name']),
                subtitle: Text("Stage: ${lead['stage']}"),
                trailing: const Icon(Icons.chat),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MessagesScreen(leadId: lead['id']),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
