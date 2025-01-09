abstract class BaseUser {
  final String email;
  final String firstName;
  final String lastName;
  final int role;
  final DateTime? createdAt;

  const BaseUser({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.createdAt,
  });

  Map<String, dynamic> toJson();

  bool validatePassword(String inputPassword);
  String getToken();
  int getRole();
}