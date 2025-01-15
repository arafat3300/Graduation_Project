import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:uuid/uuid.dart';
import 'package:gradproj/Models/User.dart' as local;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class SignUpController {
  final Uuid _uuid = const Uuid();
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;
  
  // JWT Configuration
  static const String _jwtSecret = 'samirencryption';
  // Set token duration to 5 minutes
  static const Duration _tokenDuration = Duration(minutes: 5);
  // Warning threshold for token expiration (1 minute before expiry)
  static const Duration _refreshThreshold = Duration(minutes: 1);
  static const String _issuer = 'samirencryption';

  // Storage Keys
  static const String _tokenKey = 'token';
  static const String _userIdKey = 'user_id';
  static const String _tokenExpiryKey = 'token_expiry';

  /// Saves session data including expiration time
  Future<void> _saveSession(String userId, String token, DateTime expiry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_tokenExpiryKey, expiry.toIso8601String());
  }

  /// Clears all session data
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_tokenExpiryKey);
  }

  /// Gets the token expiration time
  Future<DateTime?> getTokenExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString(_tokenExpiryKey);
    return expiryStr != null ? DateTime.parse(expiryStr) : null;
  }

  /// Generates a JWT token with 5-minute duration
  String generateJwtToken(String userId ){
   

    return userId;
  }

  /// Verifies token and checks expiration
  String? verifyTokenAndGetUserId(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_jwtSecret));
      
      final Map<String, dynamic> payload = jwt.payload;
      if (payload.containsKey('exp')) {
        final expiration = DateTime.fromMillisecondsSinceEpoch(payload['exp'] * 1000);
        if (DateTime.now().isBefore(expiration)) {
          return payload['sub'] as String;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Checks if token needs immediate refresh
  Future<bool> needsRefresh() async {
    final expiry = await getTokenExpiry();
    if (expiry == null) return true;
    
    final timeUntilExpiry = expiry.difference(DateTime.now());
    return timeUntilExpiry < _refreshThreshold;
  }

  /// Handles the sign-up process
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
      final userId = _uuid.v4();
      final sessionToken = generateJwtToken(userId);
      final expiryTime = DateTime.now().add(_tokenDuration);

      final userJob = job == 'Other' ? otherJob?.trim() ?? 'Unknown' : job;

      final user = local.User(
        idd: userId,
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

      await _supabase.from('users').upsert(user.toJson());
      await _saveSession(userId, sessionToken, expiryTime);
  

      return "User signed up successfully!";
    } on supabase.AuthException catch (e) {
      return "Authentication error: ${e.message}";
    } catch (error) {
      return "An error occurred: $error";
    }
  }

  /// Refreshes the token before it expires
  
  /// Validates all required user input fields
  /// Validates all required user input fields
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

  // Age validation
  try {
    final birthDate = DateTime.parse(dob);
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    
    // Adjust age if birthday hasn't occurred this year
    if (today.month < birthDate.month || 
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    
    if (age < 18) {
      return "You must be at least 18 years old to sign up!";
    }
  } catch (e) {
    return "Invalid date format. Please use YYYY-MM-DD format!";
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

  /// Hashes password for secure storage
  String hashPassword(String password) {
    final bytes = utf8.encode(password.trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Gets current user ID if available
  Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  /// Gets current token if available
  Future<String?> getCurrentToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Logs out user and clears session
  Future<void> logoutUser() async {
    await _supabase.auth.signOut();
    await _clearSession();
  }

  /// Gets user information from token
  Map<String, dynamic>? getUserFromToken(String token) {
    try {
      final userId = verifyTokenAndGetUserId(token);
      if (userId == null) {
        return null;
      }
      
      final jwt = JWT.verify(token, SecretKey(_jwtSecret));
      return {
        ...jwt.payload,
        'user_id': userId,
      };
    } catch (e) {
      return null;
    }
  }
}