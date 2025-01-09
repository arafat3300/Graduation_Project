import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class LoginController {
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;

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
    final bytes = utf8.encode(password.trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
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
  try {
    // 1. Fetch users from Supabase table
    final response = await _supabase
        .from('users')
        .select()
        .eq('email', email.trim())
        .single();

    // 2. Check if user exists
    if (response == null) {
      return "No user found with this email.";
    }

    // 3. Hash the provided password
    final hashedPassword = hashPassword(password.trim());

    // 4. Compare hashed passwords
    if (hashedPassword != response['password']) {
      return "Incorrect password.";
    }

    // 5. Generate or retrieve session token
    // Using the user's ID as the token (similar to your previous implementation)
    final sessionToken = response['token'];

    // 6. Save the session token
    await _saveSession(sessionToken);

    return "Login successful!";
  } catch (error) {
    debugPrint("Login error: $error");
    return "An unexpected error occurred during login.";
  }
}



  /// Logout the user by clearing the session
  Future<void> logoutUser() async {
    await _clearSession();
  }
  


Future<bool> isLoggedIn() async {
  try {
    // 1. Retrieve the session token from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    // 2. Check if a token exists
    if (token == null) {
      return false;
    }

    // 3. Verify the token by attempting to fetch the user
    final response = await _supabase
        .from('users')
        .select()
        .eq('id', token)
        .single();

    // 4. Return true if a user is found with this token
    return response != null;
  } catch (error) {
    // Log the error for debugging
    debugPrint("Login status check error: $error");
    
    // In case of any error, consider the user not logged in
    return false;
  }
}
}