import 'package:flutter/material.dart';
import 'package:gradproj/Controllers/user_controller.dart';
import 'package:gradproj/Models/singletonSession.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './ChatsScreen.dart';
import '../Screens/PropertyDetails.dart';
import '../Models/propertyClass.dart';
import 'package:gradproj/Screens/CustomBottomNavBar.dart';
import 'package:gradproj/Screens/PropertyListings.dart';
import 'package:gradproj/Screens/FavouritesScreen.dart';
import '../Screens/ClusterRecommendations.dart';

class ViewProfilePage extends StatefulWidget {
  final VoidCallback? toggleTheme;
  
  const ViewProfilePage({super.key, this.toggleTheme});

  @override
  _ViewProfilePageState createState() => _ViewProfilePageState();
}

class _ViewProfilePageState extends State<ViewProfilePage> {
  final UserController _userController = UserController();
  List<Property> userProperties = [];
  bool _isLoading = true;
  bool _isClusterLoading = true;
  bool _isExpanded = false;
  int _currentIndex = 2;
  final int userId = singletonSession().userId !=null ? singletonSession().userId! : 0;
  Map<String, dynamic>? _clusterInfo;

  @override
  void initState() {
    super.initState();
    fetchUserProperties();
    _fetchClusterInfo();
  }

  Future<void> _fetchClusterInfo() async {
    try {
      setState(() {
        _isClusterLoading = true;
      });
      debugPrint('Fetching cluster info for user ID: $userId');
      final clusterInfo = await _userController.getUserClusterInfo(userId);
      debugPrint('Received cluster info: $clusterInfo');
      if (clusterInfo != null && clusterInfo['message'] != null) {
        String message = clusterInfo['message'];
        if (message.startsWith('Subject:')) {
          message = message.substring(8).trim();
        }
        clusterInfo['message'] = message;
      }
      setState(() {
        _clusterInfo = clusterInfo;
        _isClusterLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching cluster info: $e');
      setState(() {
        _isClusterLoading = false;
      });
    }
  }

 Future<Map<String, String>> _getUserData() async {
  try {
    final user = await _userController.getUserBySessionId(userId);

    if (user == null) {
      return {
        "error": "User not found",
      };
    }

    return {
      "email": user.email.isNotEmpty ? user.email : "Email not found",
      "name": user.firstName.isNotEmpty ? user.firstName : "Name not found",
      "phone": user.phone.isNotEmpty ? user.phone : "Phone not found",
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
    debugPrint('Building profile with cluster info: $_clusterInfo');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          if (widget.toggleTheme != null)
            IconButton(
              icon: Icon(Icons.dark_mode, color: Colors.white),
              onPressed: widget.toggleTheme,
            ),
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
                        if (_isClusterLoading)
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Analyzing your Smart-Match Profile',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else if (_clusterInfo != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Property Preferences',
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            color: Colors.teal,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 24,
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ClusterRecommendations(
                                                  clusterId: _clusterInfo!['cluster_id'],
                                                  clusterMessage: _clusterInfo!['message'],
                                                ),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.teal,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          icon: const Icon(Icons.recommend),
                                          label: const Text(
                                            'View Recommendations',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Container(
                                      padding: const EdgeInsets.all(15),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Your Property Profile',
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              color: Colors.teal,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            _clusterInfo!['message'] ?? 'No preference information available',
                                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              fontSize: 16,
                                              height: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _isExpanded = !_isExpanded;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.list_alt,
                                              color: Colors.teal,
                                              size: 28,
                                            ),
                                            const SizedBox(width: 12),
                                            const Text(
                                              'Active Listings',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.teal,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            _isExpanded ? Icons.expand_less : Icons.expand_more,
                                            color: Colors.teal,
                                            size: 24,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_isExpanded)
                                if (userProperties.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'No active listings found.',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  ListView.builder(
                                    physics: const NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    itemCount: userProperties.length,
                                    itemBuilder: (context, index) {
                                      final property = userProperties[index];
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        elevation: 4,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      property.type,
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  ElevatedButton(
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
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.teal,
                                                      foregroundColor: Colors.white,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                    ),
                                                    child: const Text("View Details"),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              if (property.city.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 4),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.location_on,
                                                          size: 16,
                                                          color: Colors.grey[600]),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        property.city,
                                                        style: TextStyle(
                                                          color: Colors.grey[600],
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              if (property.price > 0)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Text(
                                                    '\$${property.price.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.teal,
                                                    ),
                                                  ),
                                                ),
                                            ],
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
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (_currentIndex == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PropertyListScreen(toggleTheme: widget.toggleTheme ?? () {}),
              ),
            );
          } else if (_currentIndex == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FavoritesScreen(toggleTheme: widget.toggleTheme ?? () {}),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
