import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gradproj/Controllers/property_controller.dart';
import 'package:gradproj/Models/singletonSession.dart';
import 'package:gradproj/Screens/MessagesScreen.dart';
import 'package:gradproj/Screens/MyListings.dart';
import '../Controllers/user_controller.dart';
import 'package:gradproj/Screens/CustomBottomNavBar.dart';
import 'package:gradproj/Screens/FavouritesScreen.dart';
import 'package:gradproj/Screens/Profile.dart';
import 'package:gradproj/Screens/emailtest.dart';
import 'package:gradproj/Screens/search.dart';
import 'package:gradproj/screens/PropertyDetails.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Models/propertyClass.dart';
import '../widgets/PropertyCard.dart';

class PropertyListScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const PropertyListScreen({super.key, required this.toggleTheme});

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

  bool _showFilters = false;

  String? _selectedPaymentOption;
  int? _selectedBedrooms;
  int? _selectedBathrooms;
  String? _selectedSortOption;
  int? _userId;
  UserController userCtrl = UserController();
  final PropertyController _propertyController = PropertyController(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    fetchProperties();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

Future<void> fetchProperties() async {
  try {
    _userId = singletonSession().userId;

    if (_userId == null) {
      debugPrint("No logged-in user found.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session expired. Please log in.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final newProperties = await _propertyController.fetchApprovedProperties();

    if (newProperties.isNotEmpty) {
      setState(() {
        properties = newProperties;
        filteredProperties = newProperties;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No properties found.")),
      );
    }
  } catch (e) {
    debugPrint("Exception fetching properties: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Failed to load properties.")),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      final query = _searchController.text.toLowerCase();

      setState(() {
        List<Property> tempList = properties.where((property) {
          final bool matchesQuery = query.isEmpty ||
              property.type.toLowerCase().contains(query) ||
              property.city.toLowerCase().contains(query) ||
              property.furnished.toLowerCase().contains(query) ||
              property.paymentOption.toLowerCase().contains(query);

          final bool matchesPaymentOption = _selectedPaymentOption == null ||
              property.paymentOption.toLowerCase() ==
                  _selectedPaymentOption!.toLowerCase();

          final bool matchesBedrooms = _selectedBedrooms == null ||
              property.bedrooms == _selectedBedrooms;

          final bool matchesBathrooms = _selectedBathrooms == null ||
              property.bathrooms == _selectedBathrooms;

          return matchesQuery &&
              matchesPaymentOption &&
              matchesBedrooms &&
              matchesBathrooms;
        }).toList();

        tempList = _applySorting(tempList);
        filteredProperties = tempList;
      });
    });
  }

 List<Property> _applySorting(List<Property> list) {
  return _propertyController.applySorting(list, _selectedSortOption);
}


  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primaryColor.withOpacity(0.9),
                secondaryColor.withOpacity(0.9),
              ],
              stops: const [0.0, 1.0],
            ),
          ),
          child: Column(
            children: [
              // AppBar
              AppBar(
                backgroundColor: primaryColor,
                title: const Text(
                  "Property Listings",
                  style: TextStyle(
                    color: Colors.black,
                    fontFamily: 'OpenSans',
                    fontWeight: FontWeight.bold,
                    fontSize: 22.0,
                  ),
                ),
                centerTitle: true,
                elevation: 1.0,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.dark_mode, color: Colors.black),
                    onPressed: widget.toggleTheme,
                  ),
                  IconButton(
                    icon: const Icon(Icons.filter_list, color: Colors.black),
                    onPressed: () {
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                  ),
                  // IconButton(
                  //   icon: const Icon(Icons.account_circle, color: Colors.black),
                  //   onPressed: () {
                  //     Navigator.pushNamed(context, '/signup');
                  //   },
                  // ),
                  ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MessagesScreen(leadId: 69),
      ),
    );
  },
  child: Text('View Messages'),
),
                  IconButton(
                    icon: const Icon(Icons.add_home_work_outlined,
                        color: Colors.black),
                    onPressed: () {
                      Navigator.pushNamed(context, '/addProperty');
                    },
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.mobile_friendly, color: Colors.black),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MyListings(userId: singletonSession().userId!),
                        ),
                      );
                    },
                  ),
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

              // Filters
              if (_showFilters)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10.0, vertical: 5.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
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
                                    value: null, child: Text('All')),
                                DropdownMenuItem(
                                    value: 'Cash', child: Text('Cash')),
                                DropdownMenuItem(
                                    value: 'Installments',
                                    child: Text('Installments')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedPaymentOption = value;
                                });
                                _onSearchChanged();
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
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
                                    value: null, child: Text('All')),
                                DropdownMenuItem(value: 1, child: Text('1')),
                                DropdownMenuItem(value: 2, child: Text('2')),
                                DropdownMenuItem(value: 3, child: Text('3')),
                                DropdownMenuItem(value: 4, child: Text('4')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedBedrooms = value;
                                });
                                _onSearchChanged();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
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
                                    value: null, child: Text('All')),
                                DropdownMenuItem(value: 1, child: Text('1')),
                                DropdownMenuItem(value: 2, child: Text('2')),
                                DropdownMenuItem(value: 3, child: Text('3')),
                                DropdownMenuItem(value: 4, child: Text('4')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedBathrooms = value;
                                });
                                _onSearchChanged();
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Sort By',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25.0),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              value: _selectedSortOption,
                              items: const [
                                DropdownMenuItem(
                                    value: null, child: Text('No Sorting')),
                                DropdownMenuItem(
                                    value: 'PriceLowHigh',
                                    child: Text('Price: Low to High')),
                                DropdownMenuItem(
                                    value: 'PriceHighLow',
                                    child: Text('Price: High to Low')),
                                DropdownMenuItem(
                                    value: 'BestSellers',
                                    child: Text('Best Sellers')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedSortOption = value;
                                });
                                _onSearchChanged();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // Property Listings
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : filteredProperties.isEmpty
                        ? const Center(
                            child: Text(
                              'No properties found.',
                              style: TextStyle(
                                fontSize: 18.0,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : OrientationBuilder(
                            builder: (context, orientation) {
                              return GridView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(10.0),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      orientation == Orientation.portrait
                                          ? 1
                                          : 4,
                                  mainAxisSpacing: 10.0,
                                  crossAxisSpacing: 10.0,
                                  childAspectRatio:
                                      orientation == Orientation.portrait
                                          ? 0.75
                                          : 0.8,
                                ),
                                itemCount: filteredProperties.length,
                                itemBuilder: (context, index) {
                                  final property = filteredProperties[index];
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PropertyDetails(
                                              property: property),
                                        ),
                                      );
                                    },
                                    child: PropertyCard(property: property),
                                  );
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ViewProfilePage(),
              ),
            );
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    FavoritesScreen(toggleTheme: widget.toggleTheme),
              ),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ViewProfilePage(),
              ),
            );
          }
        },
      ),
    );
  }
}
