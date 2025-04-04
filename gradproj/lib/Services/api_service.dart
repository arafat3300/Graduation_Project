import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/Messages.dart';
import '../controllers/user_controller.dart';
import '../models/singletonSession.dart';

Future<List<Message>> fetchMessages() async {
  final userController = UserController();

  try {
    final userId = singletonSession().userId;

    if (userId == null) {
      throw Exception("User ID not found in session.");
    }

    final user = await userController.getUserBySessionId(userId);

    if (user == null || user.email.isEmpty) {
      throw Exception("User not found or missing email.");
    }

    final userEmail = user.email;
    print("📧 Fetched email from session: $userEmail");

    final response = await http.post(
      Uri.parse('http://192.168.1.43:8069/crm/messages/user'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'email': userEmail}),
    );

    print("📩 Status Code: ${response.statusCode}");
    print("📩 Response Body: ${response.body}");

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Message.fromJson(json)).toList();
    } else {
      throw Exception('Failed: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    print("❌ Error in fetchMessages: $e");
    rethrow;
  }
}
