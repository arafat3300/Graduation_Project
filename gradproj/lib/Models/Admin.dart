class AdminRecord {
  final int id;
  final String email;
  final String first_name;
  final String last_name;
  final String password;

  AdminRecord({
    required this.id,
    required this.email,
    required this.first_name,
    required this.last_name,
    required this.password

  });

  factory AdminRecord.fromMap(Map<String, dynamic> map) {
    return AdminRecord(
      id: map['id'] as int,
      email: map['email'] as String,
      first_name: map['first_name'] as String,
      last_name: map['last_name'] as String,
      password: map['password'] as String
    );
  }
}