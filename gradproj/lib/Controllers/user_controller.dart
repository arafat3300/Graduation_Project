import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gradproj/Models/User.dart' as local;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class UserController {
  // Initialize Supabase client
  final _supabase = Supabase.instance.client;
  
  // Constants for token storage and JWT encryption
  static const String tokenKey = 'token';
  static const String _jwtSecret = 'samirencryption';

  /// Check if the token is a UUID
  bool _isUUID(String token) {
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false
    );
    return uuidPattern.hasMatch(token);
  }

  /// Save session token in SharedPreferences
  Future<void> saveSessionToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(tokenKey, token);
      debugPrint("Token saved successfully");
    } catch (e) {
      debugPrint("Error saving token: $e");
      rethrow;
    }
  }

  /// Retrieve session token from SharedPreferences
  Future<String?> getSessionToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(tokenKey);
      if (token == null) {
        debugPrint("No token found in SharedPreferences");
      }
      return token;
    } catch (e) {
      debugPrint("Error retrieving token: $e");
      return null;
    }
  }

  /// Get user by their unique identifier
  Future<local.User?> getUserById(String userId) async {
    try {
      debugPrint("Attempting to get user with ID: $userId");

      // Query the users table using the provided ID
      final response = await _supabase
          .from('users')
          .select()
          .eq('idd', userId)
          .single();

      debugPrint("Raw User Response: $response");

      if (response == null) {
        debugPrint("No user found with ID: $userId");
        return null;
      }

      // Convert the response into a User object
      return local.User(
        idd: response['idd'] ?? response['id']?.toString(),
        firstName: response['first_name'] ?? response['firstname'] ?? '',
        lastName: response['last_name'] ?? response['lastname'] ?? '',
        dob: response['dob'] ?? '',
        phone: response['phone'] ?? '',
        country: response['country'] ?? '',
        job: response['job'] ?? '',
        email: response['email'] ?? '',
        password: '', // Never retrieve password
        token: '', // No token needed for ID-based lookup
        role: response['role'] ?? '2',
        createdAt: response['created_at'] != null 
            ? DateTime.parse(response['created_at'])
            : DateTime.now()
      );
    } catch (e) {
      debugPrint("Error fetching user by ID: $e");
      return null;
    }
  }

  /// Get user by token (supports both UUID and JWT)
  Future<local.User?> getUserByToken(String token) async {
    try {
      debugPrint("Attempting to get user with token: $token");

      final response = await _supabase
          .from('users')
          .select()
          .eq(_isUUID(token) ? 'token' : 'idd', 
              (_isUUID(token) ? token : _getUserIdFromJwt(token)) as Object)
          .single();

      debugPrint("Raw User Response: $response");

      if (response == null) {
        debugPrint("No user found with provided token");
        return null;
      }

      return local.User(
        idd: response['idd'] ?? response['id']?.toString(),
        id:response['id'] as int ,
        firstName: response['first_name'] ?? response['firstname'] ?? '',
        lastName: response['last_name'] ?? response['lastname'] ?? '',
        dob: response['dob'] ?? '',
        phone: response['phone'] ?? '',
        country: response['country'] ?? '',
        job: response['job'] ?? '',
        email: response['email'] ?? '',
        password: '', // Never retrieve password
        token: token,
        role: response['role'] ?? '2',
        createdAt: response['created_at'] != null 
            ? DateTime.parse(response['created_at'])
            : DateTime.now()
      );
    } catch (e) {
      debugPrint("Error fetching user: $e");
      return null;
    }
  }

  /// Extract user ID from JWT token
  String? _getUserIdFromJwt(String token) {
    try {
      if (_isUUID(token)) return null;
      final jwt = JWT.verify(token, SecretKey(_jwtSecret));
      return jwt.payload['sub'] as String?;
    } catch (e) {
      debugPrint("Error extracting user ID from JWT: $e");
      return null;
    }
  }

  /// Verify if token is valid
  bool isTokenValid(String token) {
    if (_isUUID(token)) {
      return true; // UUID tokens don't expire
    }
    
    try {
      final jwt = JWT.verify(token, SecretKey(_jwtSecret));
      if (jwt.payload.containsKey('exp')) {
        final expiration = DateTime.fromMillisecondsSinceEpoch(jwt.payload['exp'] * 1000);
        return DateTime.now().isBefore(expiration);
      }
      return false;
    } catch (e) {
      debugPrint("Token verification failed: $e");
      return false;
    }
  }

  /// Get logged-in user
  Future<local.User?> getLoggedInUser() async {
    try {
      final token = await getSessionToken();
      if (token == null) {
        debugPrint("No session token found");
        return null;
      }

      if (!isTokenValid(token)) {
        debugPrint("Token is invalid or expired");
        await clearSessionToken();
        return null;
      }

      final user = await getUserByToken(token);
      if (user == null) {
        debugPrint("Failed to retrieve user details. Redirecting to login.");
      }
      return user;
    } catch (e) {
      debugPrint("Error fetching logged-in user: $e");
      return null;
    }
  }

  /// Get logged-in user's email
  Future<String?> getLoggedInUserEmail() async {
    final user = await getLoggedInUser();
    return user?.email;
  }

  /// Get logged-in user's full name
  Future<String?> getLoggedInUserName() async {
    final user = await getLoggedInUser();
    if (user == null) return null;
    return '${user.firstName} ${user.lastName}'.trim();
  }

  /// Get logged-in user's phone number
  Future<String?> getLoggedInUserNumber() async {
    final user = await getLoggedInUser();
    return user?.phone;
  }
   Future<int?> getLoggedInUserIndexId() async {
    final user = await getLoggedInUser();
    return user?.id;
  }

  /// Clear session token
  Future<void> clearSessionToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(tokenKey);
      debugPrint("Token cleared successfully");
    } catch (e) {
      debugPrint("Error clearing token: $e");
      rethrow;
    }
  }

  /// Check if user is currently logged in
  Future<bool> isUserLoggedIn() async {
    try {
      final token = await getSessionToken();
      if (token == null) return false;
      
      if (!isTokenValid(token)) {
        await clearSessionToken();
        return false;
      }

      final user = await getUserByToken(token);
      return user != null;
    } catch (e) {
      debugPrint("Error checking login status: $e");
      return false;
    }
  }
}