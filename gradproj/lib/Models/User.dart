import 'dart:ffi';


class User{
  const User({
    required this.id, 
    required this.First_Name,
    required this.Last_Name,
    required this.Address,
    required this.Age,
    required this.Email,
    required this.Password,
  });

  final String id;
  final String First_Name;
  final String Last_Name;
  final String Address;
  final Int Age;
 final String Email;
  final String Password;

}
