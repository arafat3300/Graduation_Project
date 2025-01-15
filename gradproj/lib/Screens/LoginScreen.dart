import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:gradproj/Controllers/google_controller.dart';
import 'package:gradproj/Controllers/login_controller.dart';
import 'package:gradproj/Screens/AdminDashboardScreen.dart';
import 'package:gradproj/Screens/PropertyListings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback toggleTheme;

  const LoginScreen({super.key, required this.toggleTheme});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // Controller and input management
  final LoginController _controller = LoginController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Animation controllers for login screen entrance
  late AnimationController _animationController;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();

    // Setup sliding animation for login screen
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    // Cleanup controllers
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Comprehensive login handler with role-based navigation
  Future<void> _handleLogin() async {
    // Trim and validate input
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Input validation
    if (!_controller.isValidEmail(email)) {
      _showErrorDialog("Please enter a valid email address!");
      return;
    }
    if (!_controller.isValidPassword(password)) {
      _showErrorDialog("Password cannot be empty!");
      return;
    }

    // Attempt login
    final message = await _controller.loginUser(email, password);

    if (message.contains("successful")) {
      // Print session token for debugging
      await _controller.printSessionToken();
      
      // Show success dialog and navigate
      _showSuccessDialog();
    } else {
      // Show error if login fails
      _showErrorDialog(message);
    }
  }

  /// Shows a success dialog and navigates based on user role
  void _showSuccessDialog() async {
    // Show initial success dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text("Success"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Login successful! Redirecting..."),
              SizedBox(height: 10),
              SpinKitCircle(
                color: Colors.green,
                size: 50.0,
              ),
            ],
          ),
        );
      },
    );

    // Navigate based on role after a short delay
    Future.delayed(const Duration(seconds: 3), () async {
      try {
        // Retrieve user role from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final role = prefs.getInt('role');

        // Determine target screen based on role
        Widget targetScreen;
        switch (role) {
          case 1: // Admin role
            targetScreen = AdminDashboardScreen();
            break;
          case 2: // Regular user role
            targetScreen = PropertyListScreen(toggleTheme: widget.toggleTheme);
            break;
          default:
            // Fallback to property list for unknown roles
            targetScreen = PropertyListScreen(toggleTheme: widget.toggleTheme);
            _showErrorDialog("Undefined user role. Redirecting to default screen.");
        }

        // Close success dialog and navigate
        Navigator.of(context).pop(); // Close success dialog
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => targetScreen),
        );
      } catch (e) {
        // Handle navigation errors
        print('Navigation error: $e');
        Navigator.of(context).pop(); // Close success dialog
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PropertyListScreen(toggleTheme: widget.toggleTheme),
          ),
        );
      }
    });
  }

  /// Error dialog for showing login and validation issues
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 10),
              Text("Error"),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  /// Builds styled input fields for email and password
  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white70, fontSize: 16),
        filled: true,
        fillColor: Colors.grey[800],
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
   final GoogleController _googleController = GoogleController();

  // Add this method to handle Google Sign In
  Future<void> _handleGoogleSignIn() async {
  final result = await _googleController.signInWithGoogle();
  
  if (result.success) {
    // Show success dialog and handle navigation
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text("Success"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(result.message),
              const SizedBox(height: 10),
              const SpinKitCircle(
                color: Colors.green,
                size: 50.0,
              ),
            ],
          ),
        );
      },
    );

    // Navigate after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pop(); // Close the dialog
      
      // Navigate based on role
      Widget targetScreen;
      switch (result.role) {
        case 1: // Admin role
          targetScreen = AdminDashboardScreen();
          break;
        case 2: // Regular user role
          targetScreen = PropertyListScreen(toggleTheme: widget.toggleTheme);
          break;
        default:
          targetScreen = PropertyListScreen(toggleTheme: widget.toggleTheme);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => targetScreen),
      );
    });
  } else {
    // Show error dialog
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 10),
              Text("Error"),
            ],
          ),
          content: Text(result.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }
} // Detailed login screen UI with blurred background and sliding animation
    return Scaffold(
      body: Stack(
        children: [
          // Blurred background
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('images/keyimage.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
          ),

          // Animated login content
          SlideTransition(
            position: _offsetAnimation,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Login form container
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          _buildInputField(
                            controller: _emailController,
                            hintText: 'Email',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 15),
                          _buildInputField(
                            controller: _passwordController,
                            hintText: 'Password',
                            obscureText: true,
                          ),
                          const SizedBox(height: 25),
                          // Login button
                          ElevatedButton(
                            onPressed: _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              padding: const EdgeInsets.symmetric(
                                horizontal: 50,
                                vertical: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'LOGIN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
  // Or divider with text
  Row(
    children: [
      const Expanded(child: Divider(color: Colors.grey)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Text(
          'OR',
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const Expanded(child: Divider(color: Colors.grey)),
    ],
  ),
  const SizedBox(height: 15),
  // Google Sign In button
  ElevatedButton.icon(
    onPressed: _handleGoogleSignIn,
    icon: Image.asset(
      'images/google-logo.png',
      height: 24,
      width: 24,
    ),
    label: const Text(
      'Sign in with Google',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
    ),
  ),
                    const SizedBox(height: 15),
                    // Forgot password section
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Forgot Password feature not implemented.")),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          shape: BoxShape.rectangle,
                          color: Colors.white,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}