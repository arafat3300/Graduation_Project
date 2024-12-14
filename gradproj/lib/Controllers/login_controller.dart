import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';

class LoginController {
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

  /// Login the user by verifying credentials
  Future<String> loginUser(String email, String password) async {
    const databaseUrl =
        "https://arafatsprojects-default-rtdb.firebaseio.com/users.json";

    try {
      // Fetch all users from the database
      final response = await http.get(Uri.parse(databaseUrl));

      if (response.statusCode == 200) {
        // Parse the database response
        final Map<String, dynamic> users = json.decode(response.body);

        // Hash the entered password
        final hashedPassword = hashPassword(password);
        debugPrint("############################################################################################################################################");
      debugPrint("Raw password during login: '$password'");
debugPrint("Hashed password during login: '${hashPassword(password)}'");


        // Check if the user exists
        for (var userId in users.keys) {
          final user = users[userId];
          if (user['email'] == email) {
            // Check if the hashed password matches
            if (user['password'] == hashedPassword) {
              return "Login successful!";
            } else {
              return "Incorrect password.";
            }
          }
        }

        return "No user found with this email.";
      } else {
        return "Server error: ${response.statusCode}";
      }
    } catch (error) {
      return "An unexpected error occurred: $error";
    }
  }
}
