import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:uuid/uuid.dart';
import 'package:gradproj/Models/User.dart' as local;
import 'package:crypto/crypto.dart';
import 'dart:convert';

class SignUpController {
  final Uuid _uuid = const Uuid();
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;

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
      return validationError;
    }

    try {
      // // Use Supabase Auth to create user
      // final authResponse = await _supabase.auth.signUp(
      //   email: email.trim(),
      //   password: password.trim(),
      // );

      // // Get the user ID from the auth response
      // final userId = authResponse.user?.id;
      // if (userId == null) {
      //   return "Failed to create user";
      // }
      final id=_uuid.v4();
      // Generate session token using the original method
      final sessionToken = generateSessionToken(id);

      // Determine the user's job
      final userJob = job == 'Other' ? otherJob?.trim() ?? 'Unknown' : job;

      // Create the user object
      final user = local.User(
        idd: id,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        dob: dob.trim(),
        phone: phone.trim(),
        country: country,
        job: userJob ?? 'Unknown',
        email: email.trim(),
        password: hashPassword(password.trim()),
        token: sessionToken,
        createdAt: DateTime.now(),
        role: 2
      );

      // Insert user details into users table
      await _supabase.from('users').upsert(user.toJson());

      // Save the session token using the original method
      await _saveSession(sessionToken);

      return "User signed up successfully!";
    } on supabase.AuthException catch (e) {
      return "Authentication error: ${e.message}";
    } catch (error) {
      return "An error occurred: $error";
    }
  }

  /// Logout the user
  Future<void> logoutUser() async {
    await _supabase.auth.signOut();
    await _clearSession();
  }
}