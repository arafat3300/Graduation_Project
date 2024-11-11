import 'package:flutter/material.dart';
import 'Screens/SignupPage.dart';
import 'Screens/LoginPage.dart';
import 'package:http/http.dart' as http;
import'dart:convert';


Future<void> saveitem() async {
  final url = Uri.https('https://arafatsprojects-default-rtdb.firebaseio.com/', 'Mydata.json');

  try {
    final response = await http.post(
      url,
      headers: {'content-type': 'application/json'},
      body: json.encode({'name': 'samir', 'NAME': 'arafat'}),
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

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
title:'MY Training demo',
theme:ThemeData(
primarySwatch: Colors.red

),
initialRoute: '/',
routes: {
  '/':(context)=>LoginPage(),
  '/signup':(context)=>SignupPage()
},



    );
  }
  
}
