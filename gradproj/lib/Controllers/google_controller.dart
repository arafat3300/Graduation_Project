import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:uuid/uuid.dart';
import 'package:gradproj/Models/User.dart' as local;

// Define a class to represent user data from Supabase
class UserData {
  final String id;
  final String email;
  final int role;

  UserData({
    required this.id,
    required this.email,
    required this.role,
  });

  // Create from Supabase map with null safety
  static UserData? fromMap(Map<String, dynamic> map) {
    try {
      return UserData(
        id: map['idd']?.toString() ?? '',
        email: map['email']?.toString() ?? '',
        role: map['role'] as int? ?? 2,
      );
    } catch (e) {
      debugPrint('Error creating UserData from map: $e');
      return null;
    }
  }
}

class SignInResult {
  final bool success;
  final String message;
  final String? email;
  final int? role;

  SignInResult({
    required this.success,
    required this.message,
    this.email,
    this.role,
  });
}

class GoogleController {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    signInOption: SignInOption.standard,
  );
  
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  // Enhanced user existence check with proper null safety
  Future<UserData?> _checkUserExists(String email) async {
    try {
      final List<dynamic> response = await _supabase
          .from('users')
          .select()
          .eq('email', email)
          .limit(1);
      
      if (response.isEmpty) {
        return null;
      }

      // Safely convert the response to UserData
      final userData = UserData.fromMap(response.first as Map<String, dynamic>);
      if (userData == null) {
        debugPrint('Failed to parse user data from response');
        return null;
      }

      return userData;
    } catch (e) {
      debugPrint('Error checking user existence: $e');
      return null;
    }
  }

  // Enhanced session saving with null checks
  Future<void> _saveSession(String userId, String email, int role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', userId);
      await prefs.setString('email', email);
      await prefs.setInt('role', role);
      await prefs.setBool('is_logged_in', true);
    } catch (e) {
      debugPrint('Error saving session: $e');
      // Re-throw to handle in the calling method
      rethrow;
    }
  }

  Future<SignInResult> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      
      if (account == null) {
        return SignInResult(
          success: false,
          message: "Sign in cancelled",
        );
      }

      try {
        final existingUser = await _checkUserExists(account.email);

        if (existingUser != null) {
          // Handle existing user
          await _saveSession(
            existingUser.id,
            existingUser.email,
            existingUser.role
          );
          
          return SignInResult(
            success: true,
            message: "Welcome back!",
            email: existingUser.email,
            role: existingUser.role,
          );
        } else {
          // Create new user with safe string handling
          final String userId = _uuid.v4();
          final List<String> nameParts = (account.displayName ?? '').split(' ');
          final String firstName = nameParts.isNotEmpty ? nameParts.first.trim() : 'Unknown';
          final String lastName = nameParts.length > 1 ? nameParts.last.trim() : 'Unknown';

          // Create user with all required fields
          final user = local.User(
            idd: userId,
            firstName: firstName,
            lastName: lastName,
            email: account.email,
            dob: '',
            phone: '',
            country: 'Unknown',
            job: 'Unknown',
            password: '',
            token: userId,
            createdAt: DateTime.now(),
            role: 2,
          );

          // Insert new user with error handling
          await _supabase
              .from('users')
              .insert(user.toJson());
          
          // Save session for new user
          await _saveSession(userId, account.email, 2);
          
          return SignInResult(
            success: true,
            message: "Account created successfully!",
            email: account.email,
            role: 2,
          );
        }
      } catch (e) {
        debugPrint('Database error: $e');
        return SignInResult(
          success: false,
          message: "Error processing account. Please try again later.",
        );
      }
    } catch (error) {
      debugPrint('Sign in error: $error');
      return SignInResult(
        success: false,
        message: "Authentication failed. Please verify your connection.",
      );
    }
  }

  Future<int?> getUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('role');
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return null;
    }
  }
}