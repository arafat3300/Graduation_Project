import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class OdooConnection extends StatelessWidget {
  const OdooConnection({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Odoo CRM Input',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const CRMInputScreen(),
    );
  }
}

class CRMInputScreen extends StatefulWidget {
  const CRMInputScreen({super.key});

  @override
  _CRMInputScreenState createState() => _CRMInputScreenState();
}

class _CRMInputScreenState extends State<CRMInputScreen> {
  final TextEditingController _controller = TextEditingController();
  final String baseUrl = "http://10.0.2.2:8069"; // Change if needed
  final String dbName = "PropertyFinder"; // Odoo database name
  final String username =  "aly2108454@miuegypt.edu.eg"; // Odoo username
  final String password ="lilO_khaled20"; // Odoo password

  String message = "";
  final http.Client _client = http.Client();
  String? sessionId; // Stores Odoo session ID

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  // Authenticate and store session
  Future<void> _authenticate() async {
    final url = Uri.parse("$baseUrl/web/session/authenticate");
    final response = await _client.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
          "db": dbName,
          "login": username,
          "password": password,
        },
        "id": 1,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['result'] != null) {
        setState(() {
          sessionId = response.headers['set-cookie']; // Save session
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

  // Send lead data to Odoo
  Future<void> _sendToCRM(String inputText) async {
  if (sessionId == null) {
    setState(() {
      message = "Not authenticated. Please log in.";
    });
    return;
  }

  final url = Uri.parse("$baseUrl/jsonrpc");
  final response = await _client.post(
    url,
    headers: {
      "Content-Type": "application/json",
      "Cookie": sessionId!, // Attach session
    },
    body: jsonEncode({
      "jsonrpc": "2.0",
      "method": "call",
      "params": {
        "service": "object", // REQUIRED for Odoo
        "method": "execute_kw",
        "args": [
          dbName, // Database Name
          2,      // User ID (will replace with authenticated user ID)
          password, // User Password
          "crm.lead", // Model
          "create", 
          [
            {
              "name": inputText,
              "contact_name": "Samir Samkara",
              "email_from": "wooohoooooo@example.com"
            }
          ]
        ]
      },
      "id": 2,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (data['result'] != null) {
      setState(() {
        message = "Lead Created Successfully!";
      });
    } else {
      setState(() {
        message = "Failed: ${data['error']['data']['message']}";
      });
    }
  } else {
    setState(() {
      message = "Error: ${response.statusCode} ${response.reasonPhrase}";
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Odoo CRM Input")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: "Enter Lead Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
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
              child: const Text("Submit to Odoo CRM"),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(fontSize: 16, color: Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}
