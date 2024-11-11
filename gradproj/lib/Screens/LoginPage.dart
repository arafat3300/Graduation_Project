import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
       AppBar(
        title: const Text(
          "Login",
          style: TextStyle(fontSize: 40),
        ),
        centerTitle: true,
      ),



      body: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50, // Background color for the container
            borderRadius: BorderRadius.circular(10),
          ),
          width: 500,
          height: 500, // Width of the container to control its size
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TextField(
                decoration: InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10), // Spacing between fields
              const TextField(
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/home');
                },
                child: const Text('Login'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/signup');
                },
                child: const Text('Signup'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/listings');
                },
                child: const Text('view listing'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
