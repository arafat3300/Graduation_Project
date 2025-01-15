import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class EmailSenderScreen extends StatefulWidget {
  const EmailSenderScreen({super.key});

  @override
  State<EmailSenderScreen> createState() => _EmailSenderScreenState();
}

class _EmailSenderScreenState extends State<EmailSenderScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'openid',
      'https://www.googleapis.com/auth/gmail.send',
      'https://www.googleapis.com/auth/userinfo.email',
    ],
    signInOption: SignInOption.standard,
  );

  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;

  bool _isSending = false;
  String? _userEmail;
  int? _userRole;
  String? _accessToken;
  String? _idToken;
  int? _expiresAt;

  @override
  void initState() {
    super.initState();
    _loadUserSession();
  }

  Future<void> _loadUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userEmail = prefs.getString('email');
        _userRole = prefs.getInt('role');
        _accessToken = prefs.getString('access_token');
        _idToken = prefs.getString('id_token');
        _expiresAt = prefs.getInt('expires_at');
      });
    } catch (e) {
      _logAndShowError('Session Load Error', e);
    }
  }

Future<Map<String, String>?> _authenticateAndGetTokens() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    final email = prefs.getString('email');
    final expiresAt = prefs.getInt('expires_at');

    if (accessToken != null &&
        email != null &&
        expiresAt != null &&
        expiresAt > DateTime.now().millisecondsSinceEpoch) {
      return {
        'access_token': accessToken,
        'email': email,
      };
    } else {
      return null;
    }
  } catch (e) {
    print('Error retrieving tokens: $e');
    return null;
  }
}
  Future<void> sendEmailViaGmailAPI() async {
  if (_isSending) return;

  setState(() {
    _isSending = true;
  });

  try {
    // Role-based access control
    if (_userRole == null || _userRole! > 2) {
      _showErrorSnackBar("Insufficient permissions");
      return;
    }

    // Check if user is signed in and has valid tokens
    var tokens = await _authenticateAndGetTokens();
    if (tokens == null) {
      // If no valid tokens, attempt to sign in
      final signedIn = await _handleSignIn();
      if (!signedIn) {
        _showErrorSnackBar("Failed to sign in. Please try again.");
        return;
      }
      // Retrieve tokens after successful sign-in
      tokens = await _authenticateAndGetTokens();
    }

    if (tokens == null) {
      _showErrorSnackBar("Failed to obtain authentication tokens");
      return;
    }

    // Use Gmail API for sending email
    final response = await _sendEmailUsingGmailAPI(
      tokens['access_token']!,
      tokens['email']!,
    );

    if (response) {
      _showSuccessSnackBar("Email Sent Successfully via Gmail API");
    } else {
      _showErrorSnackBar("Failed to send email via Gmail API");
    }
  } catch (e, stackTrace) {
    _logAndShowError('Email Sending Error', e, stackTrace);
  } finally {
    setState(() {
      _isSending = false;
    });
  }
}
Future<bool> _handleSignIn() async {
  try {
    print("Starting Google Sign-In process");
    
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    
    if (googleUser == null) {
      print("Sign-in process was cancelled by the user");
      _showErrorSnackBar("Sign-in was cancelled");
      return false;
    }

    print("User signed in: ${googleUser.email}");

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    
    if (googleAuth.accessToken == null) {
      print("Failed to retrieve access token");
      _showErrorSnackBar("Failed to get authentication token");
      return false;
    }

    print("Successfully retrieved auth token");
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', googleAuth.accessToken!);
    await prefs.setString('email', googleUser.email);
    
    final expiresAt = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
    await prefs.setInt('expires_at', expiresAt);

    setState(() {
      _userEmail = googleUser.email;
      _accessToken = googleAuth.accessToken;
      _expiresAt = expiresAt;
    });

    print("Sign-in process completed successfully");
    return true;
  } catch (e) {
    print("Error during sign-in process: $e");
    _logAndShowError('Sign-In Error', e);
    return false;
  }
}
  Future<bool> _sendEmailUsingGmailAPI(String accessToken, String userEmail) async {
    try {
      // Gmail API endpoint for sending mail
      final Uri url = Uri.parse(
        'https://gmail.googleapis.com/gmail/v1/users/me/messages/send',
      );

      // Prepare email message
      final emailMessage = _base64UrlEncode(
        'From: $userEmail\n'
        'To: $userEmail\n'
        'Subject: Test Email from Flutter App\n\n'
        'This is a test email sent using Gmail API',
      );

      // Prepare request body
      final body = json.encode({
        'raw': emailMessage,
      });

      // Send email via Gmail API
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      // Check response status
      debugPrint('Gmail API Response: ${response.statusCode}');
      debugPrint('Gmail API Response Body: ${response.body}');

      return response.statusCode == 200;
    } catch (e, stackTrace) {
      _logAndShowError('Gmail API Email Send Error', e, stackTrace);
      return false;
    }
  }

  // Base64 URL encoding for raw email message
  String _base64UrlEncode(String input) {
    return base64Url.encode(utf8.encode(input));
  }

  // Utility method for comprehensive error logging
  void _logAndShowError(String context, Object error, [StackTrace? stackTrace]) {
    debugPrint('$context: $error');
    if (stackTrace != null) {
      debugPrint('Stack Trace: $stackTrace');
    }
    _showErrorSnackBar(error.toString());
  }

  // User existence check remains the same
  Future<UserData?> _checkUserExists(String email) async {
    try {
      final List<dynamic> response = await _supabase
          .from('users')
          .select()
          .eq('email', email)
          .limit(1);

      if (response.isEmpty) {
        debugPrint('No user found with email: $email');
        return null;
      }

      return UserData.fromMap(response.first as Map<String, dynamic>);
    } catch (e, stackTrace) {
      _logAndShowError('User Existence Check Error', e, stackTrace);
      return null;
    }
  }

  // SnackBar methods remain the same
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Method to display tokens
  void _displayTokens() {
    if (_accessToken == null || _idToken == null) {
      _showErrorSnackBar("No tokens available. Please sign in first.");
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Google Tokens"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Access Token: $_accessToken"),
              const SizedBox(height: 10),
              Text("ID Token: $_idToken"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Sender'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Logged in as: ${_userEmail ?? "Not logged in"}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: sendEmailViaGmailAPI,
              child: _isSending
                  ? const CircularProgressIndicator()
                  : const Text("Send Test Email via Gmail API"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _displayTokens,
              child: const Text("Display Tokens"),
            ),
          ],
        ),
      ),
    );
  }
}

// UserData class remains the same
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