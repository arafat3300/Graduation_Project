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
      // Use Supabase authentication
      final authResponse = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Check if user exists and authentication was successful
      final user = authResponse.user;
      if (user != null) {
        // Save the session token
        await _saveSession(authResponse.session?.accessToken ?? '');
        return "Login successful!";
      } else {
        return "Authentication failed.";
      }
    } on supabase.AuthException catch (e) {
      // Handle specific authentication errors
      debugPrint("Login error: ${e.message}");
      
      if (e.message.contains('Invalid login credentials')) {
        return "Incorrect email or password.";
      }
      
      return "Login error: ${e.message}";
    } catch (error) {
      debugPrint("Unexpected login error: $error");
      return "An unexpected error occurred: $error";
    }
  }

  /// Logout the user by clearing the session
  Future<void> logoutUser() async {
    await _supabase.auth.signOut();
    await _clearSession();
  }

  /// Check if the user is logged in by verifying session
  Future<bool> isLoggedIn() async {
    final session = _supabase.auth.currentSession;
    return session != null;
  }
}