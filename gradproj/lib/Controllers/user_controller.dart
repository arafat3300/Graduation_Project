import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gradproj/Models/User.dart' as local;

class UserController {
  final _supabase = Supabase.instance.client;

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

  Future<local.User?> getUserById(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('idd', userId)
          .single();

      if (response != null) {
        return local.User(
          idd: response['idd'],
          firstName: response['first_name'] ?? response['firstname'] ?? '',
          lastName: response['last_name'] ?? response['lastname'] ?? '',
          dob: response['dob'] ?? '',
          phone: response['phone'] ?? '',
          country: response['country'] ?? '',
          job: response['job'] ?? '',
          email: response['email'] ?? '',
          password: '', // Never retrieve password
          token: response['idd'] ?? '',
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

      // 2. Fetch user details using the token
      final user = await getUserById(token);
      
      // 3. Return the email if user is found
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

      // 2. Fetch user details using the token
      final user = await getUserById(token);
      
      // 3. Construct and return full name
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

      // 2. Fetch user details using the token
      final user = await getUserById(token);
      
      // 3. Return phone number
      return user?.phone;
    } catch (error) {
      debugPrint("Error while fetching logged-in user's number: $error");
      return null;
    }
  }
}