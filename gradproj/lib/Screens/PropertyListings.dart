import 'package:flutter/material.dart';
import 'package:gradproj/Screens/CustomBottomNavBar.dart';
import 'package:gradproj/Screens/FavouritesScreen.dart';
import 'package:gradproj/Screens/Profile.dart';
import 'package:gradproj/Screens/search.dart';
import 'package:gradproj/screens/PropertyDetails.dart';
import '../models/Property.dart';
import '../Models/PropertyCard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PropertyListScreen extends StatefulWidget {
  const PropertyListScreen({super.key});

  @override
  _PropertyListScreenState createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  List<Property> properties = [];
  final ScrollController _scrollController = ScrollController();
  int _currentIndex = 0; // State for BottomNavBar

  @override
  void initState() {
    super.initState();
    fetchProperties(); // Fetch the initial properties
  }

Future<void> fetchProperties() async {
  try {
    final supabase = Supabase.instance.client;

    // Fetch data from the 'properties' table
    final response = await supabase.from('properties').select();

    if (response.isNotEmpty) {
     
      final List<dynamic> data = response;
      debugPrint("############################################ data : $data");

      // Map data to the Property model
      final newProperties = data.map((entry) => Property.fromJson(entry)).toList();
      debugPrint("############################################ newproperties : $newProperties");

      setState(() {
        properties = newProperties;
      });
    } else {
      debugPrint("Error: No data received from Supabase");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Failed to load properties. Please try again later."),
      ));
    }
  } catch (exception) {
    debugPrint("Exception fetching properties: $exception");
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Failed to load properties. Please try again later."),
    ));
  }
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF73AEF5),
              Color(0xFF61A4F1),
              Color(0xFF478DE0),
              Color(0xFF398AE5),
            ],
            stops: [0.1, 0.4, 0.7, 0.9],
          ),
        ),
        child: Column(
          children: [
            AppBar(
              title: const Text(
                "Property Listings",
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'OpenSans',
                  fontWeight: FontWeight.bold,
                  fontSize: 22.0,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0.0,
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.account_circle,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/signup');
                  },
                ),
              ],
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  mainAxisSpacing: 10.0,
                  crossAxisSpacing: 10.0,
                  childAspectRatio: 0.75,
                ),
                itemCount: properties.length,
                itemBuilder: (context, index) {
                  final property = properties[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PropertyDetails(property: property),
                        ),
                      );
                    },
                    child: PropertyCard(
                      property: property,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Add logic here to navigate to other pages if needed
          if (_currentIndex == 0) {
            // Home action or reload screen
          } else if (_currentIndex == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SearchScreen(),
              ),
            );
          } else if (_currentIndex == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ViewProfilePage(),
              ),
            );
          } else if (_currentIndex == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FavoritesScreen(),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
