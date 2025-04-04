import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import '../config/database_config.dart';  // your PostgreSQL config


/// OdooRPCController:
/// Handles authenticating with Odoo and sending test feedback via JSON‑RPC.
class OdooRPCController {
  // For an Android emulator, use 10.0.2.2; adjust for iOS/physical devices as needed.
final String odooUrl = "http://192.168.1.9:8069";
  final String dbName = "oodo18v3"; // Odoo database name
  final String username = "admin";  // Odoo username
  final String password = "1234";   // Odoo password
// odoo database bet3et aly 
    // Odoo API Details
    // const String odooUrl = "http://10.0.2.2:8069/jsonrpc";
    // const String odooDb = "PropertyFinder";
    // const String odooUsername = "aliarafat534@gmail.com";
    // const String odooPassword = "lilO_khaled20";
  late int uid;

  OdooRPCController();

  /// Check if the connection to the Odoo server is successful using JSON‑RPC.
  Future<bool> checkConnection() async {
    final url = Uri.parse('$odooUrl/jsonrpc');
    final body = jsonEncode({
      "jsonrpc": "2.0",
      "method": "call",
      "params": {
        "service": "common",
        "method": "version",
        "args": []
      },
      "id": null
    });

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["result"] != null &&
            data["result"]["server_version"] != null) {
          print("Connection successful! Odoo version: ${data["result"]["server_version"]}");
          return true;
        } else {
          print("Connection failed: ${data["error"] ?? data["result"]}");
          return false;
        }
      } else {
        print("HTTP error: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Error during connection check: $e");
      return false;
    }
  }

  /// Authenticate the user with Odoo via JSON‑RPC.
  Future<bool> authenticate() async {
    final url = Uri.parse('$odooUrl/jsonrpc');
    final body = jsonEncode({
      "jsonrpc": "2.0",
      "method": "call",
      "params": {
        "service": "common",
        "method": "authenticate",
        "args": [dbName, username, password, {}]
      },
      "id": null
    });

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["result"] != null && data["result"] is int) {
          uid = data["result"];
          print("Authentication successful! UID: $uid");
          return true;
        } else {
          print("Authentication failed: ${data["error"] ?? data["result"]}");
          return false;
        }
      } else {
        print("HTTP error: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Error during authentication: $e");
      return false;
    }
  }

  /// Submit test feedback to Odoo using the 'feedback_module' model via JSON‑RPC.
  Future<bool> submitTestFeedback() async {
    // First, authenticate the user.
    if (!await authenticate()) return false;

    final url = Uri.parse('$odooUrl/jsonrpc');

    // Define test data for feedback submission.
    final Map<String, dynamic> testFeedbackData = {
      "name": "Recommendation",
      "feedback": "الشقة سعرها مناسب و المساحة ممتازة بالنسبة لعائلة متوسطة",
      "feedback_property_id":120,
      "feedback_property_name":"HydePark Tagamo3",
      "customer_name":"Samir",
      "customer_id":1,

    };

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "method": "call",
      "params": {
        "service": "object",
        "method": "execute_kw",
        "args": [
          dbName,
          uid,
          password,
          "property.recommendation", 
          "create",
          [testFeedbackData]
        ]
      },
      "id": null
    });

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["result"] != null && data["result"] is int) {
          print("Test feedback submitted successfully with ID: ${data["result"]}");
          return true;
        } else {
          print("Failed to submit test feedback: ${data["error"] ?? data["result"]}");
          return false;
        }
      } else {
        print("HTTP error: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Error while submitting test feedback: $e");
      return false;
    }


    
  }


  Future<bool> createLeadFromPostgres({
  required int userId,
  required int propertyId,
  required double propertyPrice,
}) async {
  PostgreSQLConnection? _connection;

  try {
    _connection = await DatabaseConfig.getConnection();

    // 🧠 Fetch user data from PostgreSQL (replace Supabase)
    final userResult = await _connection.query(
      '''
      SELECT firstname, lastname, email, phone, job 
      FROM users_users 
      WHERE id = @userId
      ''',
      substitutionValues: {'userId': userId},
    );

    if (userResult.isEmpty) {
      throw Exception("User not found");
    }

    final user = userResult.first.toColumnMap();
    final userName = "${user['firstname']} ${user['lastname']}";
    final userEmail = user['email'] ?? "No Email";
    final userPhone = user['phone'] ?? "No Phone";
    final job = user['job'] ?? "No Job";

 
    const String odooUrl = "http://10.0.2.2:8069/jsonrpc";
    const String odooDb = "PropertyFinder";
    const String odooUsername = "aliarafat534@gmail.com";
    const String odooPassword = "lilO_khaled20";

    final authResponse = await http.post(
      Uri.parse(odooUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
          "service": "common",
          "method": "authenticate",
          "args": [odooDb, odooUsername, odooPassword, {}]
        }
      }),
    );

    final authData = jsonDecode(authResponse.body);
    final userIdOdoo = authData['result'];

    if (userIdOdoo == null) {
      throw Exception("Failed to authenticate with Odoo");
    }

    final leadResponse = await http.post(
      Uri.parse(odooUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
          "service": "object",
          "method": "execute_kw",
          "args": [
            odooDb,
            userIdOdoo,
            odooPassword,
            "crm.lead",
            "create",
            [
              {
                "name": "Property Inquiry: $propertyId",
                "contact_name": userName,
                "email_from": userEmail,
                "phone": userPhone,
                "expected_revenue": propertyPrice,
                "function": job,
                "description":
                    "User $userName is interested in property with the ID of : $propertyId, priced at \$$propertyPrice and his job is $job",
              }
            ]
          ],
        },
      }),
    );

    final leadData = jsonDecode(leadResponse.body);
    return leadData['result'] != null;
  } catch (e) {
    debugPrint("Error creating lead: $e");
    return false;
  } finally {
    await _connection?.close();
  }
}





}
