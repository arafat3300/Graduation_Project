import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/Messages.dart';
import '../controllers/user_controller.dart';
import '../models/singletonSession.dart';
import '../models/User.dart' as local;

Future<List<Message>> fetchMessagesByLead({required int leadId}) async {
  final userController = UserController();
  final userId = singletonSession().userId;

  if (userId == null) throw Exception("❌ User ID not found in session");

final user = await userController.getUserBySessionId(userId);
if (user?.email == null || user!.email.isEmpty) {
  throw Exception("❌ Email is null or empty");
}

  final response = await http.post(
    Uri.parse('http://192.168.1.43:8069/crm/messages/lead'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': user.email, 'lead_id': leadId}),
  );

  if (response.statusCode == 200) {
    List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => Message.fromJson(json)).toList();
  } else {
    throw Exception("❌ Failed to fetch: ${response.body}");
  }
}

Future<void> sendMessageToLead({
  required int leadId,
  required String message,
}) async {
  final userId = singletonSession().userId;
  final userController = UserController();
final user = await userController.getUserBySessionId(userId);
if (user?.email == null || user!.email.isEmpty) {
  throw Exception("❌ Email is null or empty");
}

  if (user == null || user.email.isEmpty) throw Exception("❌ No email");

  final response = await http.post (
    Uri.parse('http://192.168.1.43:8069/crm/messages/send'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': user.email,
      'lead_id': leadId,
      'message': message,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception("Failed to send message: ${response.body}");
  }
}
Future<List<Map<String, dynamic>>> fetchLeadsByUser(int userId) async {
  final userController = UserController();
  final user = await userController.getUserBySessionId(userId);

  if (user?.email == null || user!.email.isEmpty) {
    throw Exception("❌ Email is null or empty");
  }

  final response = await http.post(
    Uri.parse('http://192.168.1.43:8069/crm/leads/user'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': user.email}),
  );

  if (response.statusCode == 200) {
    final List<dynamic> jsonList = jsonDecode(response.body);
    return jsonList.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
  } else {
    throw Exception("❌ Failed to fetch leads: ${response.body}");
  }
}
