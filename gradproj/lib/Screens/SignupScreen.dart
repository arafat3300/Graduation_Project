import 'dart:convert';
import 'dart:ui';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:gradproj/Controllers/signup_controller.dart';
import 'package:gradproj/Screens/LoginScreen.dart';
import '../models/user.dart';
import 'PropertyListings.dart';
import 'package:uuid/uuid.dart';

class SignUpScreen extends StatefulWidget {
   final VoidCallback toggleTheme;

  const SignUpScreen({super.key, required this.toggleTheme});
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final SignUpController _controller = SignUpController();
  // Text controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _otherJobController = TextEditingController();

  String? _selectedCountry;
  String? _selectedJob;
final Uuid _uuid = const Uuid();

  // Dropdown options
  final List<String> _countries = [
    'United States',
    'Canada',
    'United Kingdom',
    'India',
    'Germany',
    'Australia',
    'Japan',
    'China',
    'France',
    'Brazil',
    'Other',
  ];
  final List<String> _jobs = ['Engineer', 'Lawyer', 'Doctor', 'Other'];

  // Animation controller
  late AnimationController _animationController;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();

    // Animation setup
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
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blue,
              surface: Colors.grey,
            ),
            dialogBackgroundColor: Colors.black87,
          ),
          child: child!,
        );
      },
    );

    setState(() {
      _dobController.text =
          "${pickedDate?.year}-${pickedDate?.month.toString().padLeft(2, '0')}-${pickedDate?.day.toString().padLeft(2, '0')}";
    });
    }


  Future<void> _handleSignUp() async {
  final message = await _controller.handleSignUp(
   
    firstName: _firstNameController.text,
    lastName: _lastNameController.text,
    dob: _dobController.text,
    phone: _phoneController.text,
    country: _selectedCountry ?? 'Unknown',
    job: _selectedJob ?? 'Unknown',
    email: _emailController.text,
    password: _passwordController.text,
    confirmPassword: _confirmPasswordController.text,
    otherJob: _selectedJob == 'Other' ? _otherJobController.text : null,
  );

  if (message.contains("successfully")) {
    _showSuccessDialog();

  } else {
    _showErrorDialog(message);
  }
}


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
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog() {
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
              Text("You have successfully signed up!"),
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

   
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pop(); // Close the success dialog
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) =>  LoginScreen(toggleTheme: widget.toggleTheme)),
      );
    });
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'OpenSans',
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white, fontSize: 16),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        filled: true,
        fillColor: Colors.grey[800],
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String hint,
    required List<T> items,
    required T? value,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white, fontSize: 16),
        filled: true,
        fillColor: Colors.grey[800],
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dropdownColor: Colors.grey[900],
      iconEnabledColor: Colors.white,
      items: items
          .map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(
                  item.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Blurred background image
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
          SlideTransition(
            position: _offsetAnimation,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.vpn_key, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Sign Up',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildInputField(
                                  controller: _firstNameController,
                                  hintText: 'First Name',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildInputField(
                                  controller: _lastNameController,
                                  hintText: 'Last Name',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildInputField(
                            controller: _dobController,
                            hintText: 'Date of Birth',
                            readOnly: true,
                            onTap: _selectDate,
                          ),
                          const SizedBox(height: 10),
                          _buildInputField(
                            controller: _phoneController,
                            hintText: 'Phone Number',
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 10),
                          _buildDropdown<String>(
                            hint: 'Select Country',
                            items: _countries,
                            value: _selectedCountry,
                            onChanged: (value) {
                              setState(() {
                                _selectedCountry = value;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildDropdown<String>(
                            hint: 'Select Job',
                            items: _jobs,
                            value: _selectedJob,
                            onChanged: (value) {
                              setState(() {
                                _selectedJob = value;
                              });
                            },
                          ),
                          if (_selectedJob == 'Other') ...[
                            const SizedBox(height: 10),
                            _buildInputField(
                              controller: _otherJobController,
                              hintText: 'Specify Your Job',
                            ),
                          ],
                          const SizedBox(height: 10),
                          _buildInputField(
                            controller: _emailController,
                            hintText: 'Email',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 10),
                          _buildInputField(
                            controller: _passwordController,
                            hintText: 'Password',
                            obscureText: true,
                          ),
                          const SizedBox(height: 10),
                          _buildInputField(
                            controller: _confirmPasswordController,
                            hintText: 'Confirm Password',
                            obscureText: true,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _handleSignUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              'SIGN UP',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/login');
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          shape: BoxShape.rectangle,
                          color: Colors.white
                          
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                        'Already have an Account? Sign In',
                        style: TextStyle(
                           fontWeight: FontWeight.bold,
                         
                          color: Colors.grey,
                          fontSize: 16,
                          
                        ),
                      ),)
                          
                          
                      )
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
