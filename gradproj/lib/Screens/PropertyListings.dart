import 'dart:async'; // Import for Timer
import 'package:flutter/material.dart';
import 'package:gradproj/Screens/CustomBottomNavBar.dart';
import 'package:gradproj/Screens/FavouritesScreen.dart';
import 'package:gradproj/Screens/Profile.dart';
import 'package:gradproj/Screens/search.dart';
import 'package:gradproj/screens/PropertyDetails.dart';
import '../models/Property.dart';

import '../widgets/PropertyCard.dart';
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
  int _currentIndex = 0;
  bool _isLoading = true;

  // Filter state variables
  String? _selectedPaymentOption; // 'Cash', 'Installments', or null (All)
  int? _selectedBedrooms; // e.g., 1, 2, 3, etc.
  int? _selectedBathrooms; // e.g., 1, 2, 3, etc.

  @override
  void initState() {
    super.initState();

    fetchProperties(); // Fetch the initial properties
    _searchController
        .addListener(_onSearchChanged); // Listen to search input changes
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
      setState(() {
        _isLoading = true;
      });
      final supabase = Supabase.instance.client;

      // Fetch data from the 'properties' table
      final response = await supabase.from('properties').select();

      if (response.isNotEmpty) {
        final List<dynamic> data = response;
        debugPrint("############################################ data : $data");

        // Map data to the Property model
        final newProperties =
            data.map((entry) => Property.fromJson(entry)).toList();
        debugPrint(
            "############################################ newproperties : $newProperties");

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
    } finally {
      _isLoading = false;
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      String query = _searchController.text.toLowerCase();

      setState(() {
        filteredProperties = properties.where((property) {
          // Search Query Conditions
          bool matchesQuery = property.type.toLowerCase().contains(query) ||
              property.city.toLowerCase().contains(query) ||
              property.furnished.toLowerCase().contains(query) ||
              property.paymentOption.toLowerCase().contains(query);

          // Payment Option Filter
          bool matchesPaymentOption = _selectedPaymentOption == null ||
              property.paymentOption.toLowerCase() ==
                  _selectedPaymentOption!.toLowerCase();

          // Bedrooms Filter
          bool matchesBedrooms = _selectedBedrooms == null ||
              property.bedrooms == _selectedBedrooms;

          // Bathrooms Filter
          bool matchesBathrooms = _selectedBathrooms == null ||
              property.bathrooms == _selectedBathrooms;

          return matchesQuery &&
              matchesPaymentOption &&
              matchesBedrooms &&
              matchesBathrooms;
        }).toList();
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
                IconButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/addProperty');
                    },
                    icon: const Icon(
                      Icons.add_home_work_outlined,
                      color: Colors.white,
                    ))
              ],
            ),
            // Search Bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
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
            // Filter Options
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Payment Options Dropdown
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Payment Option',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      value: _selectedPaymentOption,
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('All'),
                        ),
                        DropdownMenuItem(
                          value: 'Cash',
                          child: Text('Cash'),
                        ),
                        DropdownMenuItem(
                          value: 'Installments',
                          child: Text('Installments'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentOption = value;
                          _onSearchChanged(); // Trigger search on filter change
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  // Bedrooms Dropdown
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'Bedrooms',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      value: _selectedBedrooms,
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('All'),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text('1'),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text('2'),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text('3'),
                        ),
                        DropdownMenuItem(
                          value: 4,
                          child: Text('4'),
                        ),
                        // Add more items as needed
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedBedrooms = value;
                          _onSearchChanged(); // Trigger search on filter change
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  // Bathrooms Dropdown
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'Bathrooms',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      value: _selectedBathrooms,
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('All'),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text('1'),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text('2'),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text('3'),
                        ),
                        DropdownMenuItem(
                          value: 4,
                          child: Text('4'),
                        ),
                        // Add more items as needed
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedBathrooms = value;
                          _onSearchChanged(); // Trigger search on filter change
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Property Listings
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Color.fromRGBO(66, 165, 245, 1),
                            backgroundColor: Colors.white,
                          ),
                           SizedBox(height: 8),
                          Text(
                            "Loading Properties...",
                            
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold,color: Colors.black) 
                                  ),
                        ],
                      ),
                    )
                  : filteredProperties.isNotEmpty
                      ? GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
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
