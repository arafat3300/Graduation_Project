// email_sender_controller.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:gradproj/Controllers/feedback_controller.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

// State class to hold all the user session data
class EmailSenderState {
  String? userEmail;
  int? userRole;
  String? accessToken;
  String? idToken;
  int? expiresAt;
  bool isSending;

  EmailSenderState({
    this.userEmail,
    this.userRole,
    this.accessToken,
    this.idToken,
    this.expiresAt,
    this.isSending = false,
  });

  // Create a copy of the current state with some fields updated
  EmailSenderState copyWith({
    String? userEmail,
    int? userRole,
    String? accessToken,
    String? idToken,
    int? expiresAt,
    bool? isSending,
  }) {
    return EmailSenderState(
      userEmail: userEmail ?? this.userEmail,
      userRole: userRole ?? this.userRole,
      accessToken: accessToken ?? this.accessToken,
      idToken: idToken ?? this.idToken,
      expiresAt: expiresAt ?? this.expiresAt,
      isSending: isSending ?? this.isSending,
    );
  }
}

class EmailSenderController extends ChangeNotifier {
  final GoogleSignIn _googleSignIn;
  final supabase.SupabaseClient _supabase;
  final void Function(String) onError;
  final void Function(String) onSuccess;

  EmailSenderState _state = EmailSenderState();

 EmailSenderController({
    required GoogleSignIn googleSignIn,
    required supabase.SupabaseClient supabase,
    required this.onError,
    required this.onSuccess,
  })  : _googleSignIn = googleSignIn,
        _supabase = supabase {
    _loadUserSession();
  }

  EmailSenderState get state => _state;
  bool get isAuthenticated => _state.accessToken != null;

  Future<void> _loadUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _state = _state.copyWith(
        userEmail: prefs.getString('email'),
        userRole: prefs.getInt('role'),
        accessToken: prefs.getString('access_token'),
        idToken: prefs.getString('id_token'),
        expiresAt: prefs.getInt('expires_at'),
      );
      notifyListeners();
    } catch (e) {
      _handleError('Session Load Error', e);
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
      }
      return null;
    } catch (e) {
      _handleError('Authentication Error', e);
      return null;
    }
  }

  Future<bool> handleSignIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        onError("Sign-in was cancelled");
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null) {
        onError("Failed to get authentication token");
        return false;
      }
      
      await _saveSessionData(googleUser, googleAuth);
      return true;
    } catch (e) {
      _handleError('Sign-In Error', e);
      return false;
    }    
  }

  Future<void> _saveSessionData(
    GoogleSignInAccount user, 
    GoogleSignInAuthentication auth
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAt = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;

    await prefs.setString('access_token', auth.accessToken!);
    await prefs.setString('email', user.email);
    await prefs.setInt('expires_at', expiresAt);

    _state = _state.copyWith(
      userEmail: user.email,
      accessToken: auth.accessToken,
      expiresAt: expiresAt,
    );
    notifyListeners();
  }

   Future<void> sendEmail({
  required int propertyId,
  required int userId,
  required String feedbackText,
}) async {
  if (_state.isSending) return;

  _state = _state.copyWith(isSending: true);
  notifyListeners();

  try {
    if (_state.userRole == null || _state.userRole! > 2) {
      onError("Insufficient permissions");
      return;
    }

    var tokens = await _authenticateAndGetTokens();
    if (tokens == null) {
      final signedIn = await handleSignIn();
      if (!signedIn) {
        onError("Failed to sign in. Please try again.");
        return;
      }
      tokens = await _authenticateAndGetTokens();
    }

    if (tokens == null) {
      onError("Failed to obtain authentication tokens");
      return;
    }

    // Fetch user details
    final userResponse = await _supabase
        .from('users')
        .select('firstname, lastname')
        .eq('id', userId)
        .single();

    final userName = '${userResponse['firstname']} ${userResponse['lastname']}';

    // Fetch property details
    final propertyResponse = await _supabase
        .from('properties')
        .select('compound, city, price')
        .eq('id', propertyId)
        .single();

    final propertyCompound = propertyResponse['compound'];
    final propertyCity = propertyResponse['city'];
    final propertyPrice = propertyResponse['price'];

    final success = await _sendEmailUsingGmailAPI(
      tokens['access_token']!,
      tokens['email']!,
      propertyId: propertyId,
      userId: userId,
      feedbackText: feedbackText,
      userName: userName,
      propertyCompound: propertyCompound,
      propertyCity: propertyCity,
      propertyPrice: propertyPrice,
    );

    if (success) {
      onSuccess("Email Sent Successfully via Gmail API");
    } else {
      onError("Failed to send email via Gmail API");
    }
  } catch (e) {
    _handleError('Email Sending Error', e);
  } finally {
    _state = _state.copyWith(isSending: false);
    notifyListeners();
  }
}

  Future<bool> _sendEmailUsingGmailAPI(
  String accessToken,
  String userEmail, {
  required int propertyId,
  required int userId,
  required String feedbackText,
  required String userName,
  required String propertyCompound,
  required String propertyCity,
  required int propertyPrice,
}) async {
  try {
    final Uri url = Uri.parse(
      'https://gmail.googleapis.com/gmail/v1/users/me/messages/send',
    );

    final String senderEmail = "abdelrahman.200300@gmail.com";

    final emailBody = """
   Subject: Exclusive Property Alert: $propertyCompound in $propertyCity

   Hi $userName,

   I thought of you when I saw this exceptional property at $propertyCompound in $propertyCity. Priced at \$$propertyPrice, it offers outstanding value in one of our most desirable neighborhoods.

   Would you like to schedule a viewing this week? I'd be happy to show you around personally.

   Best regards,
   Samirzzz


    """;

    final emailMessage = 'From: $senderEmail\n'
        'To: $userEmail\n'
        'Subject: New Feedback Submitted\n\n'
        '$emailBody';

    final encodedMessage = base64UrlEncode(emailMessage);

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode({'raw': encodedMessage}),
    );

    return response.statusCode == 200;
  } catch (e) {
    _handleError('Gmail API Email Send Error', e);
    return false;
  }
}

  String base64UrlEncode(String input) {
    return base64Url.encode(utf8.encode(input));
  }


  void _handleError(String context, Object error, [StackTrace? stackTrace]) {
    debugPrint('$context: $error');
    if (stackTrace != null) {
      debugPrint('Stack Trace: $stackTrace');
    }
    onError(error.toString());
  }

 

  String _formatExpirationTime(int? timestamp) {
    if (timestamp == null) return 'Not set';
    return DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal().toString();
  }



  @override
  void dispose() {
    _googleSignIn.disconnect();
    super.dispose();
  }
}