import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:uuid/uuid.dart';
import 'package:gradproj/Models/User.dart' as local;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class UserData {
  final String id;
  final String email;
  final int role;

  UserData({
    required this.id,
    required this.email,
    required this.role,
  });

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
  // Configuration constants
  static const String _jwtSecret = 'samirencryption';
  static const Duration _jwtDuration = Duration(minutes: 5);
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    signInOption: SignInOption.standard,
  );
  
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  // Generate JWT token with standard claims
  String _generateJwtToken(String userId, String email, int role) {
    final jwt = JWT(
      {
        'sub': userId,
        'email': email,
        'role': role,
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'exp': DateTime.now().add(_jwtDuration).millisecondsSinceEpoch ~/ 1000,
        'jti': _uuid.v4(),
      },
      issuer: 'samirencryption',
      subject: userId,
    );

    return jwt.sign(SecretKey(_jwtSecret));
  }

  // Verify JWT token and return payload if valid
  Map<String, dynamic>? _verifyJwtToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_jwtSecret));
      
      // Check expiration
      final Map<String, dynamic> payload = jwt.payload;
      if (payload.containsKey('exp')) {
        final expiration = DateTime.fromMillisecondsSinceEpoch(payload['exp'] * 1000);
        if (DateTime.now().isBefore(expiration)) {
          return payload;
        }
      }
      return null;
    } catch (e) {
      debugPrint('JWT verification failed: $e');
      return null;
    }
  }

  Future<UserData?> _checkUserExists(String email) async {
    try {
      final List<dynamic> response = await _supabase
          .from('users')
          .select()
          .eq('email', email)
          .limit(1);
      
      if (response.isEmpty) return null;

      return UserData.fromMap(response.first as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error checking user existence: $e');
      return null;
    }
  }

  // Enhanced session saving with both JWT and OAuth tokens
  Future<void> _saveSession(
    String userId,
    String email,
    int role,
    String accessToken,
    String idToken,
  ) async {
    try {
      // Generate JWT token
      final jwtToken = _generateJwtToken(userId, email, role);
      
      // Calculate JWT expiration
      final jwtExpiration = DateTime.now().add(_jwtDuration);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', userId);
      await prefs.setString('email', email);
      await prefs.setInt('role', role);
      await prefs.setString('access_token', accessToken);    // Google access token
      await prefs.setString('id_token', idToken);           // Google ID token
      await prefs.setString('token', jwtToken);         // Our JWT token
      await prefs.setString('jwt_expiry', jwtExpiration.toIso8601String());
      await prefs.setBool('is_logged_in', true);
    } catch (e) {
      debugPrint('Error saving session: $e');
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

        final GoogleSignInAuthentication authentication = await account.authentication;
        final accessToken = authentication.accessToken ?? '';
        final idToken = authentication.idToken ?? '';

        if (existingUser != null) {
          // Handle existing user
          await _saveSession(
            existingUser.id,
            existingUser.email,
            existingUser.role,
            accessToken,
            idToken,
          );
          
          return SignInResult(
            success: true,
            message: "Welcome back!",
            email: existingUser.email,
            role: existingUser.role,
          );
        } else {
          // Create new user
          final String userId = _uuid.v4();
          final List<String> nameParts = (account.displayName ?? '').split(' ');
          final String firstName = nameParts.isNotEmpty ? nameParts.first.trim() : 'Unknown';
          final String lastName = nameParts.length > 1 ? nameParts.last.trim() : 'Unknown';

          // Generate JWT token for the new user
          final jwtToken = _generateJwtToken(userId, account.email, 2);

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
            token: jwtToken,  // Store JWT token instead of Google token
            createdAt: DateTime.now(),
            role: 2,
          );

          await _supabase
              .from('users')
              .insert(user.toJson());
          
          await _saveSession(
            userId,
            account.email,
            2,
            accessToken,
            idToken
          );
          
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

  // Get stored JWT token
  Future<String?> getJwtToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e) {
      debugPrint('Error getting JWT token: $e');
      return null;
    }
  }

  // Get Google access token
  Future<String?> getAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('access_token');
    } catch (e) {
      debugPrint('Error getting access token: $e');
      return null;
    }
  }

  // Get Google ID token
  Future<String?> getIdToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('id_token');
    } catch (e) {
      debugPrint('Error getting ID token: $e');
      return null;
    }
  }

  // Get user role from stored data
  Future<int?> getUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('role');
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return null;
    }
  }

  // Check if JWT token is valid
  Future<bool> isJwtValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return false;
      
      return _verifyJwtToken(token) != null;
    } catch (e) {
      debugPrint('Error checking JWT validity: $e');
      return false;
    }
  }

  // Refresh JWT token if needed
  Future<bool> refreshJwtIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final email = prefs.getString('email');
      final role = prefs.getInt('role');
      
      if (userId == null || email == null || role == null) {
        return false;
      }

      // Check if current token is near expiration
      if (!await isJwtValid()) {
        // Generate new JWT token
        final newToken = _generateJwtToken(userId, email, role);
        final newExpiry = DateTime.now().add(_jwtDuration);
        
        // Save new token
        await prefs.setString('token', newToken);
        await prefs.setString('jwt_expiry', newExpiry.toIso8601String());
        
        // Update token in database
        await _supabase
            .from('users')
            .update({'token': newToken})
            .eq('idd', userId);
            
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error refreshing JWT: $e');
      return false;
    }
  }

  // Sign out user
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }
}