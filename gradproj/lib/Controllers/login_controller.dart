import 'package:firebase_auth/firebase_auth.dart';

class LoginController {
  /// Validates the email format.
  bool isValidEmail(String email) {
    final RegExp emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    );
    return emailRegex.hasMatch(email);
  }

  /// Checks if the password is empty or null.
  bool isValidPassword(String password) {
    return password.isNotEmpty;
  }

  /// Logs in the user using Firebase Authentication.
  Future<String> loginUser(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return "Login successful!";
    } catch (error) {
      return "Login failed: $error";
    }
  }
}
