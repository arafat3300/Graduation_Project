// import 'package:flutter/material.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:gradproj/Controllers/emailsender_controller.dart';
// import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

// class EmailSenderScreen extends StatefulWidget {
//   const EmailSenderScreen({super.key});

//   @override
//   State<EmailSenderScreen> createState() => _EmailSenderScreenState();
// }

// class _EmailSenderScreenState extends State<EmailSenderScreen> {
//   // Initialize controller with dependencies
//   late EmailSenderController _controller;

//   @override
//   void initState() {
//     super.initState();
    
//     // Initialize Google Sign In with required scopes
//     final googleSignIn = GoogleSignIn(
//       scopes: [
//         'email',
//         'openid',
//         'https://www.googleapis.com/auth/gmail.send',
//         'https://www.googleapis.com/auth/userinfo.email',
//         'https://www.googleapis.com/auth/gmail.settings.sharing',
//       ],
//       signInOption: SignInOption.standard,
//     );

//     // Initialize controller with dependencies
//     _controller = EmailSenderController(
//       googleSignIn: googleSignIn,
//       supabase: supabase.Supabase.instance.client,
//       onError: _showErrorSnackBar,
//       onSuccess: _showSuccessSnackBar,
//     );
//   }

//   void _showSuccessSnackBar(String message) {
//     if (!mounted) return;
    
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(
//           message,
//           style: const TextStyle(fontSize: 16, color: Colors.white),
//         ),
//         backgroundColor: Colors.green,
//         duration: const Duration(seconds: 3),
//       ),
//     );
//   }

//   void _showErrorSnackBar(String message) {
//     if (!mounted) return;
    
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(
//           message,
//           style: const TextStyle(fontSize: 16, color: Colors.white),
//         ),
//         backgroundColor: Colors.red,
//         duration: const Duration(seconds: 3),
//       ),
//     );
//   }

//   void _displayTokens() async {
//     if (!_controller.isAuthenticated) {
//       _showErrorSnackBar("No tokens available. Please sign in first.");
//       return;
//     }

//     final sessionData = await _controller.printSessionData();
//     if (sessionData == null) return;

//     if (!mounted) return;

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Session Data'),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text('Email: ${sessionData['email']}'),
//               const SizedBox(height: 8),
//               Text('Role: ${sessionData['role']}'),
//               const SizedBox(height: 8),
//               Text('Access Token: ${sessionData['accessToken']}'),
//               const SizedBox(height: 8),
//               Text('ID Token: ${sessionData['idToken']}'),
//               const SizedBox(height: 8),
//               Text('Phone: ${sessionData['phone']}'),
//               const SizedBox(height: 8),
//               Text('Expires At: ${sessionData['expiresAt']}'),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Email Sender'),
//       ),
//       body: ListenableBuilder(
//         listenable: _controller,
//         builder: (context, _) {
//           final state = _controller.state;
          
//           return Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Text('Logged in as: ${state.userEmail ?? "Not logged in"}'),
//                 const SizedBox(height: 20),
//                 ElevatedButton(
//                   onPressed: state.isSending ? null : _controller.sendEmail,
//                   child: state.isSending
//                       ? const CircularProgressIndicator()
//                       : const Text("Send Test Email via Gmail API"),
//                 ),
//                 const SizedBox(height: 20),
//                 ElevatedButton(
//                   onPressed: _displayTokens,
//                   child: const Text("Display Tokens"),
//                 ),
//                 const SizedBox(height: 20),
//                 ElevatedButton(
//                   onPressed: _controller.printSessionData,
//                   child: const Text("Print All Session Data"),
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
// }