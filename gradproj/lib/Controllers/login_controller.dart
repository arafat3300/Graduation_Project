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
  // Initialize Supabase client for database operations
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;

  /// Save all session information in SharedPreferences
  /// Stores token, role, and phone number for the logged-in user
  Future<void> _saveSession(String token, int role, String? phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save all user-specific information
      await prefs.setString('token', token);
      await prefs.setInt("role", role);
      await prefs.setString("phone", phone ?? ''); // Store empty string if phone is null
      
      // Log successful session storage
      debugPrint('Session saved successfully for role: $role');
    } catch (e) {
      debugPrint('Error saving session: $e');
      throw Exception('Failed to save session data');
    }
  }

  /// Retrieve session token from SharedPreferences
  Future<String?> _getSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e) {
      debugPrint('Error retrieving session: $e');
      return null;
    }
  }

  /// Validate password is not empty
  bool isValidPassword(String password) {
    return password.isNotEmpty;
  }

  /// Validate email format using regex
  bool isValidEmail(String email) {
    final RegExp emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    );
    return emailRegex.hasMatch(email);
  }

  /// Clear all session data from SharedPreferences during logout
  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('role');
      await prefs.remove('phone');
      await prefs.remove('user_type');
      debugPrint('Session cleared successfully');
    } catch (e) {
      debugPrint('Error clearing session: $e');
      throw Exception('Failed to clear session data');
    }
  }

  /// Hash the password using SHA-256 for secure storage
  String hashPassword(String password) {
    final bytes = utf8.encode(password.trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

Future<BaseUser?> getUserByEmail(String email) async {
  try {
    print('Looking for user/admin with email: $email');
    final normalizedEmail = email.trim().toLowerCase();

    // Check regular users first
    final userResponse = await _supabase
        .from('users')
        .select()
        .eq('email', normalizedEmail)
        .maybeSingle();

    print('Raw User Response: $userResponse');

    if (userResponse != null) {
      try {
        // Detailed mapping with error handling for user
        final user = User.fromJson({
          'id' : userResponse['id'],
          'idd': userResponse['idd'],
          'firstname': userResponse['firstname'] ?? userResponse['first_name'],
          'lastname': userResponse['lastname'] ?? userResponse['last_name'],
          'dob': userResponse['dob'],
          'phone': userResponse['phone'],
          'country': userResponse['country'],
          'job': userResponse['job'],
          'email': userResponse['email'],
          'password': userResponse['password'],
          'token': userResponse['token'] ?? '', // Default empty string
          'created_at': userResponse['created_at'],
          'role': userResponse['role']
        });

        singletonSession().userId=user.id;
      
        
        debugPrint('Successfully mapped user: ${user.email}');
        return user;
      } catch (mappingError) {
        debugPrint('Error mapping user record: $mappingError');
        debugPrint('Problematic map: $userResponse');
        return null;
      }
    }

    // If no user found, check admin users
    final adminResponse = await _supabase
        .from('admins')
        .select()
        .eq('email', normalizedEmail)
        .maybeSingle();

    print('Raw Admin Response: $adminResponse');

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
        debugPrint('user id : ${singletonSession().userId}');
        
        debugPrint('Successfully mapped admin: ${admin.email}');
        singletonSession().userId=admin.id;
        return admin;
      } catch (mappingError) {
        debugPrint('Error mapping admin record: $mappingError');
        debugPrint('Problematic map: $adminResponse');
        return null;
      }
    }

    return null;
  } catch (error) {
    print('Detailed error fetching user: $error');
    return null;
  }
}

  /// Login method combining previous and new approaches
  Future<String> loginUser(String email, String password) async {
    try {
      // Attempt to fetch user data
      final user = await getUserByEmail(email);

      // Check if user exists
      if (user == null) {
        return "No user found with this email.";
      }

      // Hash the provided password for comparison
      final hashedPassword = hashPassword(password.trim());

      // Validate password
      if (!user.validatePassword(password)) {
        return "Incorrect password.";
      }

      // Get SharedPreferences instance
      final prefs = await SharedPreferences.getInstance();
      
      // Handle session storage based on user type
      String? phoneNumber;
      if (user is User) {
        // For regular users, get their phone number
        phoneNumber = user.getPhone();
        await prefs.setString('user_type', 'User');
      } else {
        // For admin users
        await prefs.setString('user_type', 'AdminRecord');
      }

      // Save all session data
      await _saveSession(user.getToken(), user.getRole(), phoneNumber);

      return "Login successful!";
    } catch (error) {
      debugPrint('Login error: $error');
      return "An unexpected error occurred during login.";
    }
  }

  /// Print current session token for debugging
  Future<void> printSessionToken() async {
    final token = await _getSession();
    if (token != null) {
      debugPrint("Session Token: $token");
    } else {
      debugPrint("No session token found.");
    }
  }

  /// Print all session data including phone number
  Future<void> printSessionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final role = prefs.getInt('role');
      final phone = prefs.getString('phone');
      final userType = prefs.getString('user_type');

      debugPrint('\n=== Session Data ===');
      debugPrint('Token: ${token ?? 'Not set'}');
      debugPrint('Role: ${role ?? 'Not set'}');
      debugPrint('Phone: ${phone ?? 'Not set'}');
      debugPrint('User Type: ${userType ?? 'Not set'}');
      debugPrint('==================\n');
    } catch (e) {
      debugPrint('Error printing session data: $e');
    }
  }

  /// Check if user is currently logged in
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userType = prefs.getString('user_type');

      // Basic validation of stored session data
      if (token == null || userType == null) {
        return false;
      }

      // Verify token by attempting to fetch user data
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

      return user != null;
    } catch (error) {
      debugPrint("Login status check error: $error");
      return false;
    }
  }

  /// Logout user and clear all session data
  Future<void> logoutUser() async {
    await _clearSession();
  }

  /// Determine initial app route based on user type
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

  /// Get stored phone number from session
  Future<String?> getStoredPhoneNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('phone');
    } catch (e) {
      debugPrint('Error retrieving phone number: $e');
      return null;
    }
  }
}