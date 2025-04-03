import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gradproj/Models/Admin.dart';
import 'package:gradproj/Models/Baseuser.dart';
import 'package:gradproj/Models/User.dart' as local;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:postgres/postgres.dart';
import '../config/database_config.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../Models/singletonSession.dart';
import 'dart:io';  // For SocketException
import 'dart:async';  // For TimeoutException

class LoginController {
  // final  supabase = supabase.instance.client;
  final Uuid _uuid = const Uuid();
  PostgreSQLConnection? _connection;
  bool _isConnected = false;

  LoginController() {
    _initializeConnection();
  }

  Future<void> _initializeConnection() async {
    try {
      debugPrint('\n=================== DATABASE CONNECTION ATTEMPT ===================');
      debugPrint('Time: ${DateTime.now()}');
      
      debugPrint('\nStep 1: Getting shared database connection...');
      _connection = await DatabaseConfig.getConnection();
      _isConnected = true;
      debugPrint('✓ Successfully connected to PostgreSQL database');
    } catch (e) {
      debugPrint('\n=================== CONNECTION ERROR ===================');
      debugPrint('Error Type: ${e.runtimeType}');
      debugPrint('Error Message: $e');
      debugPrint('\nTroubleshooting steps:');
      debugPrint('1. Verify PostgreSQL is running: services.msc');
      debugPrint('2. Check Windows Firewall allows port ${DatabaseConfig.port}');
      debugPrint('3. Verify hotspot connection between devices');
      debugPrint('4. Current connection details:');
      debugPrint('   - Host: ${DatabaseConfig.host}');
      debugPrint('   - Port: ${DatabaseConfig.port}');
      debugPrint('   - Database: ${DatabaseConfig.databaseName}');
      _isConnected = false;
      rethrow;
    }
  }

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
      if (!_isConnected) await _initializeConnection();
      debugPrint('\n=== Starting User Lookup ===');
      debugPrint('Looking for user/admin with email: $email');
      final normalizedEmail = email.trim().toLowerCase();
      debugPrint('Normalized email: $normalizedEmail');

      // Check regular users first
      debugPrint('\nQuerying users_users table...');
      final userResults = await _connection!.query(
        '''
        SELECT * FROM users_users 
        WHERE email = @email
        ''',
        substitutionValues: {'email': normalizedEmail},
      );
      debugPrint('Query results count: ${userResults.length}');

      if (userResults.isNotEmpty) {
        try {
          debugPrint('\nProcessing user data...');
          final userData = userResults.first.toColumnMap();
          debugPrint('Raw user data: $userData');
          
          debugPrint('\nAttempting to create User object...');
          final user = local.User.fromJson({
            'id': int.tryParse(userData['id']?.toString() ?? '0') ?? 0,
            'idd': userData['idd']?.toString(),
            'firstname': userData['firstname']?.toString() ?? '',
            'lastname': userData['lastname']?.toString() ?? '',
            'dob': userData['dob']?.toString() ?? '',
            'phone': userData['phone']?.toString() ?? '',
            'country': userData['country']?.toString() ?? '',
            'job': userData['job']?.toString() ?? '',
            'email': userData['email']?.toString() ?? '',
            'password': userData['password']?.toString() ?? '',
            'token': userData['token']?.toString() ?? '',
            'created_at': userData['created_at']?.toString(),
            'role': int.tryParse(userData['role']?.toString() ?? '2') ?? 2
          });
          debugPrint('User object created successfully');

          singletonSession().userId = user.id;
          debugPrint('User ID set in singleton session: ${user.id}');
          return user;
        } catch (mappingError, stackTrace) {
          debugPrint('\n=== Error Mapping User Record ===');
          debugPrint('Error type: ${mappingError.runtimeType}');
          debugPrint('Error message: $mappingError');
          debugPrint('Stack trace: $stackTrace');
          return null;
        }
      }

      // If no user found, check admin users
      debugPrint('\nNo regular user found, checking admin users...');
      final adminResults = await _connection!.query(
        '''
        SELECT * FROM real_estate_admins 
        WHERE email = @email
        ''',
        substitutionValues: {'email': normalizedEmail},
      );
      debugPrint('Admin query results count: ${adminResults.length}');

      if (adminResults.isNotEmpty) {
        try {
          debugPrint('\nProcessing admin data...');
          final adminData = adminResults.first.toColumnMap();
          debugPrint('Raw admin data: $adminData');
          
          debugPrint('\nAttempting to create Admin object...');
          final admin = AdminRecord.fromMap({
            'id': adminData['id'],
            'email': adminData['email'],
            'first_name': adminData['first_name'],
            'last_name': adminData['last_name'],
            'password': adminData['password'],
            'token': adminData['token'] ?? '',
            'idd': adminData['idd']
          });
          debugPrint('Admin object created successfully');

          singletonSession().userId = admin.id;
          debugPrint('Admin ID set in singleton session: ${admin.id}');
          return admin;
        } catch (mappingError, stackTrace) {
          debugPrint('\n=== Error Mapping Admin Record ===');
          debugPrint('Error type: ${mappingError.runtimeType}');
          debugPrint('Error message: $mappingError');
          debugPrint('Stack trace: $stackTrace');
          return null;
        }
      }

      debugPrint('\nNo user or admin found with email: $email');
      return null;
    } catch (error, stackTrace) {
      debugPrint('\n=== Error in getUserByEmail ===');
      debugPrint('Error type: ${error.runtimeType}');
      debugPrint('Error message: $error');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Login method combining previous and new approaches
  Future<String> loginUser(String email, String password) async {
    try {
      debugPrint('\n=== Starting Login Process ===');
      debugPrint('Email: $email');
      
      if (email.trim().isEmpty) {
        debugPrint('Error: Email is empty');
        return "Email is required.";
      }
      if (password.trim().isEmpty) {
        debugPrint('Error: Password is empty');
        return "Password is required.";
      }

      if (!isValidEmail(email)) {
        debugPrint('Error: Invalid email format');
        return "Invalid email format.";
      }

      debugPrint('\nFetching user by email...');
      final user = await getUserByEmail(email);

      if (user == null) {
        debugPrint('Error: No user found with email: $email');
        return "No account found with the provided email.";
      }

      debugPrint('\nValidating password...');
      final hashedPassword = hashPassword(password.trim());
      debugPrint('Hashed input password: $hashedPassword');

      if (!user.validatePassword(password)) {
        debugPrint('Error: Password validation failed');
        return "Incorrect password.";
      }

      debugPrint('\nSaving session data...');
      final prefs = await SharedPreferences.getInstance();
      
      String? phoneNumber;
      if (user is local.User) {
        phoneNumber = user.getPhone();
        await prefs.setString('user_type', 'User');
        debugPrint('User type set to: User');
      } else {
        await prefs.setString('user_type', 'AdminRecord');
        debugPrint('User type set to: AdminRecord');
      }

      await _saveSession(user.getToken(), user.getRole(), phoneNumber);
      debugPrint('Session saved successfully');

      debugPrint('\nLogin successful!');
      return "Login successful!";
    } catch (error, stackTrace) {
      debugPrint('\n=== Login Error ===');
      debugPrint('Error type: ${error.runtimeType}');
      debugPrint('Error message: $error');
      debugPrint('Stack trace: $stackTrace');
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
      if (!_isConnected) await _initializeConnection();

      if (userType == 'User') {
        final results = await _connection!.query(
          '''
          SELECT * FROM users_users 
          WHERE id = @token
          ''',
          substitutionValues: {'token': token},
        );
        return results.isNotEmpty;
      } else if (userType == 'AdminRecord') {
        final results = await _connection!.query(
          '''
          SELECT * FROM real_estate_admins 
          WHERE id = @token
          ''',
          substitutionValues: {'token': token},
        );
        return results.isNotEmpty;
      }

      return false;
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

  Future<void> dispose() async {
    if (_isConnected && _connection != null) {
      await _connection!.close();
      _isConnected = false;
      debugPrint('Disconnected from PostgreSQL database');
    }
  }
}