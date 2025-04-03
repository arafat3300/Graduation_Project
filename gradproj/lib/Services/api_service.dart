import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/Messages.dart';

Future<List<Message>> fetchMessages(int leadId) async {
  final response = await http.get(
    Uri.parse('http://10.0.2.2:8069/crm/messages/$leadId'),
    headers: {
      'Content-Type': 'application/json',
    },
  );


  if (response.statusCode == 200) {
    List<dynamic> data = json.decode(response.body);
    return data.map((json) => Message.fromJson(json)).toList();
  } else {
    print('Response code: ${response.statusCode}');
print('Response body: ${response.body}');
    throw Exception('Failed to load messages');
  }
}
