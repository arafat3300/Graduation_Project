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
  // Initialize Google Sign In with required scopes
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'openid',
      'https://www.googleapis.com/auth/gmail.send',
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/gmail.settings.sharing',
    ],
    signInOption: SignInOption.standard,
  );

  // Initialize Supabase client  
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;

  // State variables
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

  // Load saved session data when the screen initializes
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

  // Check for valid authentication tokens
  Future<Map<String, String>?> _authenticateAndGetTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final email = prefs.getString('email');
      final expiresAt = prefs.getInt('expires_at');

      // Return tokens only if they exist and haven't expired
      if (accessToken != null && 
          email != null &&
          expiresAt != null &&  
          expiresAt > DateTime.now().millisecondsSinceEpoch) {
        return {
          'access_token': accessToken,
          'email': email,
        }; 
      }
      return null;
    } catch (e) {
      debugPrint('Error retrieving tokens: $e');
      return null;
    }
  }

  // Handle the Google Sign-In process
  Future<bool> _handleSignIn() async {
    try {
      debugPrint("Starting Google Sign-In process");
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        debugPrint("Sign-in process was cancelled by the user");
        _showErrorSnackBar("Sign-in was cancelled");
        return false;
      }

      debugPrint("User signed in: ${googleUser.email}");

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null) {
        debugPrint("Failed to retrieve access token");
        _showErrorSnackBar("Failed to get authentication token");
        return false;
      }

      debugPrint("Successfully retrieved auth token");
      
      // Save session data to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', googleAuth.accessToken!);
      await prefs.setString('email', googleUser.email);
      
      // Set token expiration to 1 hour from now
      final expiresAt = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;  
      await prefs.setInt('expires_at', expiresAt);

      // Update state with new session data
      setState(() {
        _userEmail = googleUser.email;
        _accessToken = googleAuth.accessToken;
        _expiresAt = expiresAt;
      });

      debugPrint("Sign-in process completed successfully");
      return true;
    } catch (e) {
      debugPrint("Error during sign-in process: $e");
      _logAndShowError('Sign-In Error', e);
      return false;
    }    
  }

  // Main email sending function using Gmail API
  Future<void> sendEmailViaGmailAPI() async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Check user role permissions
      if (_userRole == null || _userRole! > 2) {
        _showErrorSnackBar("Insufficient permissions");
        return;
      } 

      // Verify authentication
      var tokens = await _authenticateAndGetTokens();
      if (tokens == null) {
        final signedIn = await _handleSignIn();
        if (!signedIn) {
          _showErrorSnackBar("Failed to sign in. Please try again.");
          return;
        }
        tokens = await _authenticateAndGetTokens();
      }

      if (tokens == null) {
        _showErrorSnackBar("Failed to obtain authentication tokens");
        return;
      }

      // Send the email
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

  // Function to actually send the email using Gmail API
  Future<bool> _sendEmailUsingGmailAPI(String accessToken, String userEmail) async {
    try {
      final Uri url = Uri.parse(
        'https://gmail.googleapis.com/gmail/v1/users/me/messages/send',
      );

      final String senderEmail = "your-sender-email@gmail.com"; // Replace with your email
      
      final emailMessage = _base64UrlEncode(
        'From: $senderEmail\n'
        'To: $userEmail\n'
        'Subject: Test Email from Flutter App\n\n'
        'This is a test email sent using Gmail API',
      );

      final body = json.encode({
        'raw': emailMessage,
      });

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      // Log response for debugging
      debugPrint('Gmail API Response: ${response.statusCode}');
      debugPrint('Gmail API Response Body: ${response.body}');
      
      if (response.statusCode != 200) {
        debugPrint('Sender Email: $senderEmail');
        debugPrint('Recipient Email: $userEmail');
        debugPrint('Full Response Headers: ${response.headers}');
      }

      return response.statusCode == 200;
    } catch (e, stackTrace) {
      _logAndShowError('Gmail API Email Send Error', e, stackTrace);
      return false;
    }
  }

  // Helper function to encode email content
  String _base64UrlEncode(String input) {
    return base64Url.encode(utf8.encode(input));
  }

  // Error logging utility
  void _logAndShowError(String context, Object error, [StackTrace? stackTrace]) {
    debugPrint('$context: $error');
    if (stackTrace != null) {
      debugPrint('Stack Trace: $stackTrace');
    }
    _showErrorSnackBar(error.toString());
  }

  // Check if user exists in Supabase
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

  // Success message display
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

  // Error message display  
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

  // Function to print all session data
Future<void> printSessionData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Get all session values
    final email = prefs.getString('email') ?? 'Not set';
    final accessToken = prefs.getString('access_token') ?? 'Not set';
    final idToken = prefs.getString('id_token') ?? 'Not set';
    final role = prefs.getInt('role')?.toString() ?? 'Not set';
    final phone = prefs.getString('phone') ?? 'Not set';  // Correctly get phone
    final expiresAt = prefs.getInt('expires_at');  // Get actual expiration time
    
    // Format expiration time
    String expirationFormatted = 'Not set';
    if (expiresAt != null) {
      final expirationDate = DateTime.fromMillisecondsSinceEpoch(expiresAt);
      expirationFormatted = expirationDate.toLocal().toString();
    }

    // Print to debug console  
    debugPrint('\n=== Session Data ===');
    debugPrint('Email: $email');
    debugPrint('Role: $role'); 
    debugPrint('Access Token: ${_truncateToken(accessToken)}');
    debugPrint('ID Token: ${_truncateToken(idToken)}');
    debugPrint('Phone: $phone');  // Add phone number display
    debugPrint('Expires At: $expirationFormatted');
    debugPrint('==================\n');
    
    // Show in UI
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Data'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Email: $email'),
              const SizedBox(height: 8),
              Text('Role: $role'),
              const SizedBox(height: 8),
              Text('Access Token: ${_truncateToken(accessToken)}'),
              const SizedBox(height: 8),
              Text('ID Token: ${_truncateToken(idToken)}'),
              const SizedBox(height: 8),
              Text('Phone: $phone'),  // Add phone display
              const SizedBox(height: 8),
              Text('Expires At: $expirationFormatted'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  } catch (e, stackTrace) {
    _logAndShowError('Session Data Print Error', e, stackTrace);
  }
}

  // Helper to truncate long tokens for display
  String _truncateToken(String token) {
    if (token == 'Not set') return token;
    if (token.length <= 20) return token;
    return '${token.substring(0, 10)}...${token.substring(token.length - 10)}';
  }

  // Display tokens in a dialog
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: printSessionData,
              child: const Text("Print All Session Data"),
            ),
          ],
        ),
      ),
    );
  }
}

// User data model
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