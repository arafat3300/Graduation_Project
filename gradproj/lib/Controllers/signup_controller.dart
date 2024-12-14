import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../models/user.dart';
import 'package:http/http.dart' as http;

class SignUpController {
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

  /// Validate if phone number contains only numbers and is at least 8 digits
  bool isValidPhone(String phone) {
    return phone.length >= 8 && RegExp(r'^[0-9]+$').hasMatch(phone);
  }

  /// Validate that no fields are empty
  bool areFieldsValid({
    required String firstName,
    required String lastName,
    required String dob,
    required String phone,
    required String email,
    required String password,
    required String confirmPassword,
  }) {
    return firstName.isNotEmpty &&
        lastName.isNotEmpty &&
        dob.isNotEmpty &&
        phone.isNotEmpty &&
        email.isNotEmpty &&
        password.isNotEmpty &&
        confirmPassword.isNotEmpty;
  }

  /// Check if a user with the same email already exists in the database
  Future<bool> doesUserExist(String email) async {
    try {
      final url = Uri.https(
        'arafatsprojects-default-rtdb.firebaseio.com',
        '/users.json',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data != null) {
          for (var user in data.values) {
            if (user['email'] == email) {
              return true; // User exists
            }
          }
        }
      }
      return false; // User does not exist
    } catch (error) {
      debugPrint("Error checking user existence: $error");
      return false;
    }
  }

  /// Send user data to the backend for signup
  Future<String> signUpUser(User user) async {
  try {
    // Check if the user already exists
    final userExists = await doesUserExist(user.email);
    if (userExists) {
      return "A user with this email already exists!";
    }

    // Check if the password is already hashed
    String hashedPassword;
    if (user.password.length == 64 && user.password.contains(RegExp(r'^[a-f0-9]+$'))) {
      hashedPassword = user.password; // Use the already hashed password
    } else {
      hashedPassword = hashPassword(user.password); // Hash the raw password
    }

    final newUser = User(
      firstName: user.firstName,
      lastName: user.lastName,
      email: user.email,
      password: hashedPassword, // Store the hashed password
      dob: user.dob,
      phone: user.phone,
      id: user.id,
      job: user.job,
      country: user.country,
    );

    final url = Uri.https(
      'arafatsprojects-default-rtdb.firebaseio.com',
      '/users.json',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(newUser.toJson()),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      debugPrint("Raw password during signup: '${user.password}'");
      debugPrint("Hashed password during signup: '$hashedPassword'");
      return "User signed up successfully!";
    } else {
      return "Failed to sign up: ${response.body}";
    }
  } catch (error) {
    return "An error occurred: $error";
  }
}
}