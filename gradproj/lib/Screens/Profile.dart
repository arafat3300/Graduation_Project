import 'package:flutter/material.dart';
import 'package:gradproj/Controllers/user_controller.dart';

class ViewProfilePage extends StatelessWidget {
  final UserController _userController = UserController();

  ViewProfilePage({super.key});

  Future<Map<String, String>> _getUserData() async {
    try {
      final email = await _userController.getLoggedInUserEmail();
      final name = await _userController.getLoggedInUserName();
      final phone =await _userController.getLoggedInUserNumber();
      return {
        "email": email ?? "Email not found",
        "name": name ?? "Name not found",
        "phone": phone ?? "phone not found",

      };
    } catch (error) {
      return {"error": error.toString()};
    }
  }

  /// Log out method
  Future<void> _logout(BuildContext context) async {
    await _userController.saveSessionToken(""); // Clear the token
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

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header Section
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
                            children:  [
                              const Icon(Icons.phone, color: Colors.white70),
                              const SizedBox(width: 5),
                              Text(
                                phone, 
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // About Me Section
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'About Me',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'John is a passionate real estate agent with over 10 years of experience. He specializes in helping clients find their dream homes and investment properties.', // Dummy bio
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),

                  // Active Listings Section
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
                        // Property 1
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 3,
                          child: Row(
                            children: [
                              // Property Image
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                                child: Image.asset(
                                  'images/listingPlaceholder.jpg', // Dummy image
                                  width: 100,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Property Details
                              const Expanded(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Modern Apartment in NYC', // Dummy title
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 5),
                                      Text(
                                        '\$2,500,000', // Dummy price
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.teal,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Property 2
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 3,
                          child: Row(
                            children: [
                              // Property Image
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                                child: Image.asset(
                                  'images/listingPlaceholder.jpg', // Dummy image
                                  width: 100,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Property Details
                              const Expanded(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Cozy Family Home', // Dummy title
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 5),
                                      Text(
                                        '\$850,000', // Dummy price
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.teal,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contact Information Section
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Contact Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.teal),
                            const SizedBox(width: 10),
                            Text(
                              '123 Real Estate Lane, Miami, FL', // Dummy address
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.language, color: Colors.teal),
                            const SizedBox(width: 10),
                            Text(
                              'www.johndoe-realestate.com', // Dummy website
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[700]),
                            ),
                          ],
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
