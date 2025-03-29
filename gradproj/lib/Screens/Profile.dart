import 'package:flutter/material.dart';
import 'package:gradproj/Controllers/user_controller.dart';
import 'package:gradproj/Models/singletonSession.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './ChatsScreen.dart';
import '../Screens/PropertyDetails.dart';
import '../Models/propertyClass.dart';

class ViewProfilePage extends StatefulWidget {
  const ViewProfilePage({super.key});

  @override
  _ViewProfilePageState createState() => _ViewProfilePageState();
}

class _ViewProfilePageState extends State<ViewProfilePage> {
  final UserController _userController = UserController();
  List<Property> userProperties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserProperties();
  }

  Future<Map<String, String>> _getUserData() async {
    try {
      final email = await _userController.getLoggedInUserEmail();
      final name = await _userController.getLoggedInUserName();
      final phone = await _userController.getLoggedInUserNumber();
      return {
        "email": email ?? "Email not found",
        "name": name ?? "Name not found",
        "phone": phone ?? "Phone not found",
      };
    } catch (error) {
      return {"error": error.toString()};
    }
  }

  Future<void> fetchUserProperties() async {
  setState(() => _isLoading = true);
  try {
    final properties = await _userController.fetchUserPropertiesBySession();
    setState(() {
      userProperties = properties;
    });
  } catch (e) {
    debugPrint("Error fetching properties: $e");
  } finally {
    setState(() => _isLoading = false);
  }
}


  // /// Fetch user-specific properties
  // Future<void> fetchUserProperties() async {
  //   setState(() => _isLoading = true);
  //   try {
  //     final supabase = Supabase.instance.client;
  //     final userId = singletonSession().userId;

  //     if (userId == null) {
  //       debugPrint("User ID is null");
  //       return;
  //     }

  //     final response = await supabase
  //         .from('properties')
  //         .select('*')
  //         .eq('user_id', userId);

  //     if (response is List) {
  //       setState(() {
  //         userProperties =
  //             response.map((item) => Property.fromJson(item)).toList();
  //       });
  //     } else {
  //       debugPrint("Unexpected response format: $response");
  //     }
  //   } catch (error) {
  //     debugPrint("Exception fetching user listings: $error");
  //   } finally {
  //     setState(() => _isLoading = false);
  //   }
  // }

  Future<void> _logout(BuildContext context) async {
    await _userController.saveSessionToken("");
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _logout(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChatsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, String>>(
        future: _getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || snapshot.data?['error'] != null) {
            return Center(
              child: Text('Error: ${snapshot.error ?? snapshot.data?['error']}'),
            );
          } else {
            final userData = snapshot.data!;
            final email = userData['email']!;
            final name = userData['name']!;
            final phone = userData['phone']!;

            return _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          color: Colors.teal,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30.0),
                            child: Column(
                              children: [
                                const CircleAvatar(
                                  radius: 60,
                                  backgroundImage:
                                      AssetImage('assets/profile_picture.jpg'),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.email, color: Colors.white70),
                                    const SizedBox(width: 5),
                                    Text(
                                      email,
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.phone, color: Colors.white70),
                                    const SizedBox(width: 5),
                                    Text(
                                      phone,
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Active Listings',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (userProperties.isEmpty)
                                const Center(
                                  child: Text('No active listings found.'),
                                )
                              else
                                ListView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  itemCount: userProperties.length,
                                  itemBuilder: (context, index) {
                                    final property = userProperties[index];
                                    return Card(
                                      margin: const EdgeInsets.all(10),
                                      elevation: 4,
                                      child: ListTile(
                                        title: Text(
                                          property.type,
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        trailing: ElevatedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    PropertyDetails(
                                                        property: property),
                                              ),
                                            );
                                          },
                                          child: const Text("View Details"),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
          }
        },
      ),
    );
  }
}
