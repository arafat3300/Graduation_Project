import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gradproj/Models/User.dart' as local;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class UserController {
  final _supabase = Supabase.instance.client;
  static const String _jwtSecret = 'samirencryption';

  /// Save session token in SharedPreferences
  Future<void> saveSessionToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  /// Retrieve session token from SharedPreferences
  Future<String?> getSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// Get user ID from JWT token
  String? getUserIdFromToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_jwtSecret));
      return jwt.payload['sub'] as String?;
    } catch (e) {
      debugPrint("Error decoding token: $e");
      return null;
    }
  }

  /// Verify if token is valid and not expired
  bool isTokenValid(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_jwtSecret));
      
      final Map<String, dynamic> payload = jwt.payload;
      if (payload.containsKey('exp')) {
        final expiration = DateTime.fromMillisecondsSinceEpoch(payload['exp'] * 1000);
        return DateTime.now().isBefore(expiration);
      }
      return false;
    } catch (e) {
      debugPrint("Token verification failed: $e");
      return false;
    }
  }

  /// Get user by JWT token
  Future<local.User?> getUserByToken(String token) async {
    try {
      // First verify token and get user ID
      final userId = getUserIdFromToken(token);
      if (userId == null) {
        debugPrint("Could not extract user ID from token");
        return null;
      }

      // Fetch user data from database
      final response = await _supabase
          .from('users')
          .select()
          .eq('idd', userId)
          .single();

      if (response != null) {
        return local.User(
          idd: response['idd'],
          id : response['id'] ,
          firstName: response['first_name'] ?? response['firstname'] ?? '',
          lastName: response['last_name'] ?? response['lastname'] ?? '',
          dob: response['dob'] ?? '',
          phone: response['phone'] ?? '',
          country: response['country'] ?? '',
          job: response['job'] ?? '',
          email: response['email'] ?? '',
          password: '', // Never retrieve password
          token: token, // Use the actual JWT token
          role: response['role'],
          createdAt: response['created_at'] != null 
              ? DateTime.parse(response['created_at'])
              : DateTime.now()
        );
      }
      return null;
    } catch (error) {
      debugPrint("Error fetching user: $error");
      return null;
    }
  }

  /// Get logged-in user's email
  Future<String?> getLoggedInUserEmail() async {
    try {
      // 1. Retrieve the stored session token
      final token = await getSessionToken();
      
      if (token == null) {
        debugPrint("No session token found.");
        return null;
      }

      // 2. Verify token is valid
      if (!isTokenValid(token)) {
        debugPrint("Token is invalid or expired.");
        return null;
      }

      // 3. Fetch user details using the token
      final user = await getUserByToken(token);
      
      // 4. Return the email if user is found
      return user?.email;
    } catch (error) {
      debugPrint("Error while fetching logged-in user's email: $error");
      return null;
    }
  }

  /// Get logged-in user's full name
  Future<String?> getLoggedInUserName() async {
    try {
      // 1. Retrieve the stored session token
      final token = await getSessionToken();
      
      if (token == null) {
        debugPrint("No session token found.");
        return null;
      }

      // 2. Verify token is valid
      if (!isTokenValid(token)) {
        debugPrint("Token is invalid or expired.");
        return null;
      }

      // 3. Fetch user details using the token
      final user = await getUserByToken(token);
      
      // 4. Construct and return full name
      if (user == null) return null;
      
      return '${user.firstName} ${user.lastName}'.trim();
    } catch (error) {
      debugPrint("Error while fetching logged-in user's name: $error");
      return null;
    }
  }

  /// Get logged-in user's phone number
  Future<String?> getLoggedInUserNumber() async {
    try {
      // 1. Retrieve the stored session token
      final token = await getSessionToken();
      
      if (token == null) {
        debugPrint("No session token found.");
        return null;
      }

      // 2. Verify token is valid
      if (!isTokenValid(token)) {
        debugPrint("Token is invalid or expired.");
        return null;
      }

      // 3. Fetch user details using the token
      final user = await getUserByToken(token);
      
      // 4. Return phone number
      return user?.phone;
    } catch (error) {
      debugPrint("Error while fetching logged-in user's number: $error");
      return null;
    }
  }

  /// Get currently logged-in user
  Future<local.User?> getLoggedInUser() async {
    try {
      // 1. Retrieve the stored session token
      final token = await getSessionToken();
      
      if (token == null) {
        debugPrint("No session token found.");
        return null;
      }

      // 2. Verify token is valid
      if (!isTokenValid(token)) {
        debugPrint("Token is invalid or expired.");
        return null;
      }

      // 3. Return user details
      return await getUserByToken(token);
    } catch (error) {
      debugPrint("Error while fetching logged-in user: $error");
      return null;
    }
  }
Future<int?> getUserId() async {
  try {
    final token = await getSessionToken();
    if (token == null) {
      debugPrint("No session token found.");
      return null;
    }

    if (!isTokenValid(token)) {
      debugPrint("Token is invalid or expired.");
      return null;
    }

    final user = await getUserByToken(token);
    if (user == null) {
      debugPrint("No user found for the provided token.");
      return null;
    }

    return user.id;
  } catch (error) {
    debugPrint("Error while fetching logged-in user's ID: $error");
    return null;
  }
}

}