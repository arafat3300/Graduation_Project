import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

class SignUpController {
  final Uuid _uuid = const Uuid();

  /// Save session token in SharedPreferences
  Future<void> _saveSession(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  /// Clear session token from SharedPreferences
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  /// Validate user input
  String? validateInputs({
    required String firstName,
    required String lastName,
    required String dob,
    required String phone,
    required String email,
    required String password,
    required String confirmPassword,
  }) {
    if (firstName.isEmpty ||
        lastName.isEmpty ||
        dob.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      return "Please fill in all required fields!";
    }

    if (phone.length < 8 || !RegExp(r'^[0-9]+$').hasMatch(phone)) {
      return "Phone number must be at least 8 digits long!";
    }

    if (!RegExp(
            r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+$")
        .hasMatch(email)) {
      return "Invalid email address!";
    }

    if (password != confirmPassword) {
      return "Passwords do not match!";
    }

    return null;
  }

  /// Hash the password using SHA-256
  String hashPassword(String password) {
    final bytes = utf8.encode(password.trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generate session token
  String generateSessionToken(String id) {
   
    return id;
  }

  /// Handle sign-up logic
  Future<String> handleSignUp({
    required String firstName,
    required String lastName,
    required String dob,
    required String phone,
    required String country,
    required String job,
    required String email,
    required String password,
    required String confirmPassword,
    String? otherJob,
  }) async {
    // Validate inputs
    final validationError = validateInputs(
      firstName: firstName,
      lastName: lastName,
      dob: dob,
      phone: phone,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
    );

    if (validationError != null) {
      return validationError; // Return the error message
    }

    // Generate a unique user ID and session token
    final id = _uuid.v4();
    final sessionToken = generateSessionToken(id);

    // Determine the user's job
    final userJob = job == 'Other' ? otherJob?.trim() ?? 'Unknown' : job;

    // Create the user object
    final user = User(
      id: id,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      dob: dob.trim(),
      phone: phone.trim(),
      country: country,
      job: userJob ?? 'Unknown',
      email: email.trim(),
      password: hashPassword(password.trim()),
      token: sessionToken,
    );

    // Attempt to save the user
    return await signUpUser(user);
  }

  /// Send user data to the backend for sign-up
    /// Send user data to the backend for sign-up
  Future<String> signUpUser(User user) async {
    try {
      final url = Uri.https(
        'property-finder-3a4b1-default-rtdb.firebaseio.com',
        '/users/${user.id}.json', // Use the user ID as the key
      );

      final response = await http.put(
        url, // Use PUT instead of POST to set the ID as the key
        headers: {'Content-Type': 'application/json'},
        body: json.encode(user.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Save the session token
        await _saveSession(user.token);
        return "User signed up successfully!";
      } else {
        return "Failed to sign up: ${response.body}";
      }
    } catch (error) {
      return "An error occurred: $error";
    }
  }


  /// Logout the user
  Future<void> logoutUser() async {
    await _clearSession();
  }
}
