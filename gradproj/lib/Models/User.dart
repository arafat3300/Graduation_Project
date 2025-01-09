class User {
  final String? idd;
  final String firstName;
  final String lastName;
  final String dob;
  final String? phone;
  final String? country;
  final String? job;
  final String email;
  final String password;
  final String token;
  final DateTime? createdAt;

  User({
    this.idd,
    required this.firstName,
    required this.lastName,
    required this.dob,
    this.phone,
    this.country,
    this.job,
    required this.email,
    required this.password,
    required this.token,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'idd': idd,
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
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      idd: json['idd'],
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
   
    );
  }
}