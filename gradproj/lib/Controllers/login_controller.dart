import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginController {
  /// Save session token in SharedPreferences
  Future<void> _saveSession(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  /// Retrieve session token from SharedPreferences
  Future<String?> _getSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// Clear session token from SharedPreferences
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  /// Hash the password using SHA-256
  String hashPassword(String password) {
    final bytes = utf8.encode(password.trim()); // Trim and convert password to bytes
    final digest = sha256.convert(bytes); // Perform SHA-256 hashing
    return digest.toString(); // Return hashed password as a string
  }

  /// Validate if email is in correct format
  bool isValidEmail(String email) {
    final RegExp emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    );
    return emailRegex.hasMatch(email);
  }

  /// Validate if password is not empty
  bool isValidPassword(String password) {
    return password.isNotEmpty;
  }
/// Retrieve and print the session token
Future<void> printSessionToken() async {
  final token = await _getSession();
  if (token != null) {
    debugPrint("Session Token: $token");
  } else {
    debugPrint("No session token found.");
  }
}

  /// Login the user by verifying credentials
  Future<String> loginUser(String email, String password) async {
  const databaseUrl =
      "https://property-finder-3a4b1-default-rtdb.firebaseio.com/users.json";

  try {
    final response = await http.get(Uri.parse(databaseUrl));

    if (response.statusCode == 200) {
      final Map<String, dynamic> users = json.decode(response.body);

      final hashedPassword = hashPassword(password);
      debugPrint("Raw password during login: '$password', Hashed password: '$hashedPassword'");

      for (var userId in users.keys) {
        final user = users[userId];
        if (user['email'] == email) {
          if (user['password'] == hashedPassword) {
            final sessionToken = user['token'] ?? userId;
            await _saveSession(sessionToken);
            return "Login successful!";
           
          } else {
            return "Incorrect password.";
          }
        }
      }

      return "No user found with this email.";
    } else {
      debugPrint("Server error: ${response.body}");
      return "Server error: ${response.statusCode}";
    }
  } catch (error) {
    if (error is FormatException) {
      debugPrint("Unexpected server response: $error");
      return "Unexpected server response. Please check the database URL.";
    }
    return "An unexpected error occurred: $error";
  }
}


  /// Logout the user by clearing the session
  Future<void> logoutUser() async {
    await _clearSession();
  }

  /// Check if the user is logged in by verifying session token
  Future<bool> isLoggedIn() async {
    final token = await _getSession();
    return token != null;
  }
}
