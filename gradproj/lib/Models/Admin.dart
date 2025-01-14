import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'Baseuser.dart';

class AdminRecord extends BaseUser {
  final String password;
  final int id;
  final String first_name;  // Add this property
  final String last_name; 
  final String token;



  const AdminRecord({
    String? idd,
    required this.id,
    required String email,
    required this.first_name,
    required this.last_name,
    required this.password,
    required this.token
  }) : super(
          email: email,
          firstName: first_name,
          lastName: last_name,
          role: 1, 
        );

  factory AdminRecord.fromMap(Map<String, dynamic> map) {
    return AdminRecord(
      id: map['id'] as int,
      token: map['token'] as String,
      email: map['email'] as String,
      first_name: map['first_name'] as String,
      last_name: map['last_name'] as String,
      password: map['password'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'password': password,
      'token':token
    };
  }

   String hashPassword(String password) {
    final bytes = utf8.encode(password.trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  @override
  bool validatePassword(String inputPassword) {
  final hashedInputPassword = hashPassword(inputPassword);
  
  // Compare with the stored hashed password
  return hashedInputPassword == password;  }
  
  @override
  String getToken()
  {
      return this.token;
  }
    @override
  int getRole()
  {
    return this.role;
  }
}