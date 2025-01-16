import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradproj/Controllers/emailsender_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

final emailSenderProvider = Provider<EmailSenderController>((ref) {
  return EmailSenderController(
    googleSignIn: GoogleSignIn(),
    supabase: Supabase.instance.client,
    onError: (error) => print('Error: $error'),
    onSuccess: (success) => print('Success: $success'),
  );
});