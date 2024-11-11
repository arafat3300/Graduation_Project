import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SignupPage extends StatefulWidget {
  const SignupPage({Key? key}) : super(key: key);

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  Future<void> saveItem(String name, String password, String email) async {
    final url = Uri.https('arafatsprojects-default-rtdb.firebaseio.com', 'Mydata.json');

    try {
      final response = await http.post(
        url,
        headers: {'content-type': 'application/json'},
        body: json.encode({
          'name': name,
          'password': password,
          'email': email,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('Data saved successfully!');
      } else {
        print('Failed to save data: ${response.body}');
      }
    } catch (error) {
      print('Error occurred: $error');
    }
  }

  @override
  void dispose() {
    // Clean up controllers
    nameController.dispose();
    passwordController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Signup Page"),
      ),
      body: Center(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          width: 500,
          height: 500,
          padding: EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Name:"),
              TextField(controller: nameController),
              Text("Password:"),
              TextField(controller: passwordController, obscureText: true),
              Text("Email:"),
              TextField(controller: emailController),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Capture and save data
                  saveItem(
                    nameController.text,
                    passwordController.text,
                    emailController.text,
                  );
                  Navigator.pushNamed(context, '/');
                },
                child: Text("Submit"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/');
                },
                child: Text("Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
