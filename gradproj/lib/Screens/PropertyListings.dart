import 'dart:async'; // Import for Timer
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
  List<Property> filteredProperties = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int _currentIndex = 0; // State for BottomNavBar

  @override
  void initState() {
    super.initState();
    fetchProperties(); // Fetch the initial properties
    _searchController.addListener(_onSearchChanged); // Listen to search input changes
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel(); // Cancel the timer if it's active
    super.dispose();
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
          filteredProperties = newProperties; // Initialize filtered list
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

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      String query = _searchController.text.toLowerCase();

      setState(() {
        if (query.isEmpty) {
          filteredProperties = properties;
        } else {
          filteredProperties = properties.where((property) {
            String type = property.type.toLowerCase();
            String city = property.city.toLowerCase();
            String furnished = property.furnished.toLowerCase();
            String paymentOption = property.paymentOption.toLowerCase();

            // Add more fields if needed

            return type.contains(query) ||
                   city.contains(query) ||
                   furnished.contains(query) ||
                   paymentOption.contains(query);
          }).toList();
        }
      });
    });
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search properties by type, city, etc...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: filteredProperties.isNotEmpty
                  ? GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 1,
                        mainAxisSpacing: 10.0,
                        crossAxisSpacing: 10.0,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: filteredProperties.length,
                      itemBuilder: (context, index) {
                        final property = filteredProperties[index];
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
                    )
                  : const Center(
                      child: Text(
                        'No properties found.',
                        style: TextStyle(
                          fontSize: 18.0,
                          color: Colors.white,
                        ),
                      ),
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
}
