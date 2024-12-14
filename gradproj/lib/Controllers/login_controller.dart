import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginController {
  /// Validates the email format.
  bool isValidEmail(String email) {
    final RegExp emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    );
    return emailRegex.hasMatch(email);
  }

  /// Checks if the password is empty or null.
  bool isValidPassword(String password) {
    return password.isNotEmpty;
  }

 Future<String> loginUser(String email, String password) async {
  const databaseUrl = "https://arafatsprojects-default-rtdb.firebaseio.com/users.json";

  try {
    // Fetch all users from the database
    final response = await http.get(Uri.parse(databaseUrl));

    if (response.statusCode == 200) {
      // Parse the database response
      final Map<String, dynamic> users = json.decode(response.body);

      // Check if the user exists
      for (var userId in users.keys) {
        final user = users[userId];
        if (user['email'] == email) {
          // Check if the password matches
          if (user['password'] == password) {
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