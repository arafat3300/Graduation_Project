import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Odoo CRM Input',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: CRMInputScreen(),
    );
  }
}

class CRMInputScreen extends StatefulWidget {
  @override
  _CRMInputScreenState createState() => _CRMInputScreenState();
}

class _CRMInputScreenState extends State<CRMInputScreen> {
  final TextEditingController _controller = TextEditingController();
  final String baseUrl = "http://10.0.2.2:8069"; // Use appropriate URL
  final String dbName = "Test_data"; // Odoo database name
  final String username = "aliarafat534@gmail.com"; // Odoo username
  final String password = "12345678"; // Odoo password
  String message = "";


  final http.Client _client = http.Client(); // HTTP client to manage cookies

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  // Authenticate with Odoo and store cookies automatically
  Future<void> _authenticate() async {
    final url = Uri.parse("$baseUrl/web/session/authenticate");
    final response = await _client.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "params": {
          "db": dbName,
          "login": username,
          "password": password,
        }
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['result'] != null) {
        setState(() {
          message = "Connected to Odoo CRM";
        });
      } else {
        setState(() {
          message = "Failed to authenticate: ${data['error']['data']['message']}";
        });
      }
    } else {
      setState(() {
        message = "Failed to connect: ${response.statusCode} ${response.reasonPhrase}";
      });
    }
  }

  // Send text input to Odoo CRM as a new lead
  Future<void> _sendToCRM(String inputText) async {
    final url = Uri.parse("$baseUrl/jsonrpc");
    final response = await _client.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
          "model": "crm.lead",
          "method": "create",
          "args": [],
          "kwargs": {
            "values": {
              "name": inputText,
                'contact_name': 'samir samkara',
                'email_from': 'wooohoooooo@example.com' // Lead name from user input
            }
          },
        },
        "id": 1,
      }),
    );

    if (response.statusCode == 200) {
      setState(() {
        message = "Successfully created lead in Odoo CRM";
      });
    } else {
      setState(() {
        message = "Failed to create lead in Odoo";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Odoo CRM Input")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: "Enter Lead Name",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  _sendToCRM(_controller.text);
                  _controller.clear();
                } else {
                  setState(() {
                    message = "Please enter text";
                  });
                }
              },
              child: Text("Submit to Odoo CRM"),
            ),
            SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}
