// class User {
//   final String? idd;
//   final String firstName;
//   final String lastName;
//   final String dob;
//   final String? phone;
//   final String? country;
//   final String? job;
//   final String email;
//   final String password;
//   final String token;
//   final DateTime? createdAt;
//   final int role;

//   User({
//     this.idd,
//     required this.firstName,
//     required this.lastName,
//     required this.dob,
//     this.phone,
//     this.country,
//     this.job,
//     required this.email,
//     required this.password,
//     required this.token,
//     this.createdAt,
//     required this.role
//   });

//   Map<String, dynamic> toJson() {
//     return {
//       'idd': idd,
//       'firstname': firstName,
//       'lastname': lastName,
//       'dob': dob,
//       'phone': phone,
//       'country': country,
//       'job': job,
//       'email': email,
//       'password': password, 
//       'token': token,
//       'created_at': createdAt?.toIso8601String(),
//       'role':role
//     };
//   }

//   factory User.fromJson(Map<String, dynamic> json) {
//     return User(
//       idd: json['idd'],
//       firstName: json['firstname'] ?? json['firstName'],
//       lastName: json['lastname'] ?? json['lastName'],
//       dob: json['dob'],
//       phone: json['phone'],
//       country: json['country'],
//       job: json['job'],
//       email: json['email'],
//       password: json['password'],
//       token: json['token'],
//       createdAt: json['created_at'] != null 
//         ? DateTime.parse(json['created_at']) 
//         : null,
//       role: json['role']
   
//     );
//   }
// }

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'Baseuser.dart';

class User extends BaseUser {
  final String dob;
  final String phone;
  final String? country;
  final String? job;
  final String password;
  final String token;
  final String? idd;
  final int? id ;

  const User({
    this.idd,
    required String firstName,
    required String lastName,
    required this.dob,
    required this.phone,
    this.country,
    this.job,
    this.id,
    required String email,
    required this.password,
    required this.token,
    DateTime? createdAt,
    required int role,
  }) : super(
          email: email,
          firstName: firstName,
          lastName: lastName,
          role: 2,
          createdAt: createdAt,
        );

  @override
  Map<String, dynamic> toJson() {
    return {
      'firstname': firstName,
      'lastname': lastName,
      'dob': dob,
      'phone': phone,
      'country': country,
      'job': job,
      'email': email,
      'password': password,
      'token': token,
      'created_at': createdAt?.toIso8601String(),
      'role': role,
      'idd':idd
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      idd: json['idd'],
      id: json['id'],
      firstName: json['firstname'] ?? json['firstName'],
      lastName: json['lastname'] ?? json['lastName'],
      dob: json['dob'],
      phone: json['phone'],
      country: json['country'],
      job: json['job'],
      email: json['email'],
      password: json['password'],
      token: json['token'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      role: json['role'],
    );
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
 String getPhone()
  {
    return this.phone;
  }
}