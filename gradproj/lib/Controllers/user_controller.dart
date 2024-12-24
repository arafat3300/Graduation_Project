import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:gradproj/Models/User.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserController {
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


  Future<User?> getUserById(String userId) async {
    const databaseUrl =
        "https://property-finder-3a4b1-default-rtdb.firebaseio.com/users";

    try {
      final url = Uri.parse("$databaseUrl/$userId.json");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic>? userData = json.decode(response.body);
        if (userData != null) {
          return User(
            id: userData['id'],
            firstName: userData['firstName'],
            lastName: userData['lastName'],
            dob: userData['dob'],
            phone: userData['phone'],
            country: userData['country'],
            job: userData['job'],
            email: userData['email'],
            password: userData['password'],
            token: userData['token'],
          );
        } else {
          return null; 
        }
      } else {
        throw Exception("Failed to fetch user: ${response.statusCode}");
      }
    } catch (error) {
      debugPrint("Error fetching user: $error");
      return null;
    }
  }

  Future<String?> getLoggedInUserEmail() async {
    try {
      final token = await getSessionToken();
      debugPrint("Session Token: $token");

      if (token == null) {
        debugPrint("No session token found.");
        return null;
      }

      
      debugPrint("Extracted User ID: $token");

      if (token == null) {
        debugPrint("Invalid session token format.");
        return null;
      }

      final user = await getUserById(token);
      debugPrint("User Data for Logged-in User: $user");

      return user?.email; 
    } catch (error) {
      debugPrint("Error while fetching logged-in user's email: $error");
      return null;
    }
  }
  Future<String?> getLoggedInUserName() async {
    try {
      final token = await getSessionToken();
      debugPrint("Session Token: $token");

      if (token == null) {
        debugPrint("No session token found.");
        return null;
      }

      
      debugPrint("Extracted User ID: $token");

      if (token == null) {
        debugPrint("Invalid session token format.");
        return null;
      }

      final user = await getUserById(token);
      debugPrint("User Data for Logged-in User: $user");
String name='${user?.firstName ?? ''}'+' ' + ' ${user?.lastName ??''}';//?? 3shan law empty ahot el maben el quotations
      return name; 
    } catch (error) {
      debugPrint("Error while fetching logged-in user's name: $error");
      return null;
    }
  }
}
