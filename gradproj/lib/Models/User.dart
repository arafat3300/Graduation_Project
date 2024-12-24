class User {
  final String id; // Unique user ID
  final String firstName;
  final String lastName;
  final String dob;
  final String phone;
  final String country;
  final String job;
  final String email;
  final String password;
  final String token;


  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.dob,
    required this.phone,
    required this.country,
    required this.job,
    required this.email,
    required this.password,
    required this.token,

  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'dob': dob,
      'phone': phone,
      'country': country,
      'job': job,
      'email': email,
      'password': password,
      'token': token,

    };
  }
}
