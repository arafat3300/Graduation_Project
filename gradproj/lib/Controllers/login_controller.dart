import 'package:flutter/material.dart';
import 'package:gradproj/Models/Admin.dart';
import 'package:gradproj/Models/Baseuser.dart';
import 'package:gradproj/Models/User.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../Models/singletonSession.dart';
import 'package:crypto/crypto.dart';
class LoginController {
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;

  /// Save session token in SharedPreferences
  Future<void> _saveSession(String token,int role) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save user-specific information
    await prefs.setString('token', token);
    await prefs.setInt("role", role);

  }

  /// Retrieve session token from SharedPreferences
  Future<String?> _getSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

   bool isValidPassword(String password) {
    return password.isNotEmpty;
  }

   bool isValidEmail(String email) {
    final RegExp emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    );
    return emailRegex.hasMatch(email);
  }

  /// Clear session token from SharedPreferences
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role');
  }

  /// Hash the password using SHA-256
  String hashPassword(String password) {
    final bytes = utf8.encode(password.trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

Future<BaseUser?> getUserByEmail(String email) async {
  try {
    print('Looking for user/admin with email: $email');
    final normalizedEmail = email.trim().toLowerCase();

    // Check regular users
    final userResponse = await _supabase
        .from('users')
        .select()
        .eq('email', normalizedEmail)
        .maybeSingle(); // Allow for no rows without throwing an error

    if (userResponse != null) {
      print('User found: $userResponse');
      return User.fromJson({
        'id': userResponse['id'],
        'idd': userResponse['idd'],
        'firstname': userResponse['firstname'] ?? userResponse['first_name'],
        'lastname': userResponse['lastname'] ?? userResponse['last_name'],
        'dob': userResponse['dob'],
        'phone': userResponse['phone'],
        'country': userResponse['country'],
        'job': userResponse['job'],
        'email': userResponse['email'],
        'password': userResponse['password'],
        'token': userResponse['token'] ?? '',
        'created_at': userResponse['created_at'],
        'role': userResponse['role'],
      });
    }

    // Check admin users
    final adminResponse = await _supabase
        .from('admins')
        .select()
        .eq('email', normalizedEmail)
        .maybeSingle();

    if (adminResponse != null) {
      try {
        // Detailed mapping with error handling for admin
        final admin = AdminRecord.fromMap({
          'id': adminResponse['id'],
          'email': adminResponse['email'],
          'first_name': adminResponse['first_name'],
          'last_name': adminResponse['last_name'],
          'password': adminResponse['password'],
          'token': adminResponse['token'] ?? '', // Default empty string
          'idd': adminResponse['idd'] // Optional field
          
        });
        singletonSession().userId = admin.id;
        
        
        debugPrint('Successfully mapped admin: ${admin.email}');
        return admin;
      } catch (mappingError) {
        debugPrint('Error mapping admin record: $mappingError');
        debugPrint('Problematic map: $adminResponse');
        return null;
      }
    }

    return null;
  } catch (error) {
    debugPrint('Detailed error fetching user: $error');
    return null;
  }
}


  Future<String> loginUser(String email, String password) async {
    try {
      // Fetch user
      final user = await getUserByEmail(email);

      // Validate user existence
      if (user == null) {
        return "No user found with this email.";
      }

      // Hash the provided password
      final hashedPassword = hashPassword(password.trim());

      // Validate password
      if (!user.validatePassword(password)) {
        return "Incorrect password.";
      }

      // Save session
      await _saveSession(user.getToken(),user.getRole());

      // Return success message
      return "Login successful!";
    } catch (error) {
      print('Login error: $error');
      return "An unexpected error occurred during login.";
    }
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

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      // 1. Retrieve the session token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userType = prefs.getString('user_type');

      // 2. Check if token and user type exist
      if (token == null || userType == null) {
        return false;
      }

      // 3. Verify the token by attempting to fetch the user
      BaseUser? user;
      if (userType == 'User') {
        user = await _supabase
            .from('users')
            .select()
            .eq('id', token)
            .single()
            .then((response) => 
                response != null ? User.fromJson(response) : null);
      } else if (userType == 'AdminRecord') {
        user = await _supabase
            .from('admin')
            .select()
            .eq('id', token)
            .single()
            .then((response) => 
                response != null ? AdminRecord.fromMap(response) : null);
      }

      // 4. Return true if a user is found with this token
      return user != null;
    } catch (error) {
      // Log the error for debugging
      debugPrint("Login status check error: $error");
      
      // In case of any error, consider the user not logged in
      return false;
    }
  }

  /// Logout the user by clearing the session
  Future<void> logoutUser() async {
    await _clearSession();
  }

  /// Determine initial route based on user type
  Future<String> determineInitialRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final userType = prefs.getString('user_type');

    switch (userType) {
      case 'User':
        return '/user-dashboard';
      case 'AdminRecord':
        return '/admin-dashboard';
      default:
        return '/login';
    }
  }
}


  