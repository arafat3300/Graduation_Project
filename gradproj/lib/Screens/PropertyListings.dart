import 'dart:async'; // Import for Timer
import 'package:flutter/material.dart';
import 'package:gradproj/Screens/CustomBottomNavBar.dart';
import 'package:gradproj/Screens/FavouritesScreen.dart';
import 'package:gradproj/Screens/Profile.dart';
import 'package:gradproj/Screens/search.dart';
import 'package:gradproj/screens/PropertyDetails.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/Property.dart';
import '../widgets/PropertyCard.dart';

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

  // Toggle filter visibility
  bool _showFilters = false;

  // Filter state variables
  String? _selectedPaymentOption; // 'Cash', 'Installments', or null => All
  int? _selectedBedrooms;         // e.g. 1, 2, 3, or null => All
  int? _selectedBathrooms;        // e.g. 1, 2, 3, or null => All

  // Price range slider (commented out in your code – uncomment if needed)
  // RangeValues _priceRange = const RangeValues(0, 100000);

  // NEW: Sort dropdown state
  String? _selectedSortOption; // 'PriceLowHigh', 'PriceHighLow', 'BestSellers', null => No sorting

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
      setState(() => _isLoading = true);

      final supabase = Supabase.instance.client;
      final response = await supabase.from('properties').select();

      if (response.isNotEmpty) {
        final List<dynamic> data = response;
        debugPrint("### data from Supabase: $data");

        final newProperties = data.map((entry) => Property.fromJson(entry)).toList();
        debugPrint("### newproperties: $newProperties");

        setState(() {
          properties = newProperties;
          filteredProperties = newProperties;
        });
      } else {
        debugPrint("Error: No data from Supabase");
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
      setState(() => _isLoading = false);
    }
  }

  // This method filters based on your current filter variables + search text.
  // Then it applies the chosen sort option.
  void _onSearchChanged() {
    // Debounce to avoid repeated setState calls while typing
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      final query = _searchController.text.toLowerCase();

      setState(() {
        // 1) Filter
        List<Property> tempList = properties.where((property) {
          // Search: if query is empty, everything matches
          final bool matchesQuery = query.isEmpty ||
              property.type.toLowerCase().contains(query) ||
              property.city.toLowerCase().contains(query) ||
              property.furnished.toLowerCase().contains(query) ||
              property.paymentOption.toLowerCase().contains(query);

          final bool matchesPaymentOption = _selectedPaymentOption == null ||
              property.paymentOption.toLowerCase() == _selectedPaymentOption!.toLowerCase();

          final bool matchesBedrooms = _selectedBedrooms == null ||
              property.bedrooms == _selectedBedrooms;

          final bool matchesBathrooms = _selectedBathrooms == null ||
              property.bathrooms == _selectedBathrooms;

          // (Optional) Price Filter if uncommented:
          // final bool matchesPrice = (property.price >= _priceRange.start) &&
          //     (property.price <= _priceRange.end);

          // return matchesQuery && matchesPaymentOption && matchesBedrooms && matchesBathrooms && matchesPrice;
          return matchesQuery && matchesPaymentOption && matchesBedrooms && matchesBathrooms;
        }).toList();

        // 2) Sort
        tempList = _applySorting(tempList);

        filteredProperties = tempList;
      });
    });
  }

  // Applies whichever sort option is selected.
  // If your property has a `price` (int or double), we can compare it easily.
  // For "Best Sellers", we assume there's a `property.feedback` list or something similar. 
  // Adjust as needed for your "best sellers" logic.
  List<Property> _applySorting(List<Property> list) {
    if (_selectedSortOption == null) {
      // No sorting
      return list;
    }

    // Create a copy to avoid mutating the original
    final sorted = List<Property>.from(list);

    switch (_selectedSortOption) {
      case 'PriceLowHigh':
        sorted.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'PriceHighLow':
        sorted.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'BestSellers':
        // Example: sort by feedback length descending
        // Adjust if you have a different "bestseller" metric
        sorted.sort((a, b) => b.feedback.length.compareTo(a.feedback.length));
        break;
      default:
        // No sorting
        break;
    }

    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Background gradient
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
            // AppBar
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
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0.0,
              actions: [
                // Filter icon
                IconButton(
                  icon: const Icon(Icons.filter_list, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _showFilters = !_showFilters;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.account_circle, color: Colors.white),
                  onPressed: () {
                    Navigator.pushNamed(context, '/signup');
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.add_home_work_outlined, color: Colors.white),
                  onPressed: () {
                    Navigator.pushNamed(context, '/addProperty');
                  },
                ),
              ],
            ),

            // Search Bar
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

            // Filter + Sort Panel (toggle visibility)
            Visibility(
              visible: _showFilters,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                child: Column(
                  children: [
                    // Row of Payment, Bedrooms, Bathrooms
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Payment Option
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
                              });
                              _onSearchChanged();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Bedrooms
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
                              DropdownMenuItem(value: null, child: Text('All')),
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
                        const SizedBox(width: 10),

                        // Bathrooms
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
                              DropdownMenuItem(value: null, child: Text('All')),
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
                      ],
                    ),
                    const SizedBox(height: 15),

                    // (Optional) Price Range
                    // Text(
                    //   'Price Range: ${_priceRange.start.round()} - ${_priceRange.end.round()}',
                    //   style: const TextStyle(fontSize: 16, color: Colors.white),
                    // ),
                    // RangeSlider(
                    //   values: _priceRange,
                    //   min: 0,
                    //   max: 100000,
                    //   divisions: 100,
                    //   labels: RangeLabels(
                    //     _priceRange.start.round().toString(),
                    //     _priceRange.end.round().toString(),
                    //   ),
                    //   onChanged: (RangeValues values) {
                    //     setState(() {
                    //       _priceRange = values;
                    //     });
                    //     _onSearchChanged();
                    //   },
                    // ),

                    // SORT Dropdown
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
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
                          value: null,
                          child: Text('No Sorting'),
                        ),
                        DropdownMenuItem(
                          value: 'PriceLowHigh',
                          child: Text('Price: Low to High'),
                        ),
                        DropdownMenuItem(
                          value: 'PriceHighLow',
                          child: Text('Price: High to Low'),
                        ),
                        DropdownMenuItem(
                          value: 'BestSellers',
                          child: Text('Best Sellers'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedSortOption = value; 
                        });
                        // re-filter and sort
                        _onSearchChanged();
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Property Listings
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Color.fromRGBO(66, 165, 245, 1),
                            backgroundColor: Colors.white,
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Loading Properties...",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    )
                  : filteredProperties.isNotEmpty
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
                              child: PropertyCard(property: property),
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
          setState(() => _currentIndex = index);
          // Navigation logic
          if (_currentIndex == 0) {
            // Home or reload
          } else if (_currentIndex == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SearchScreen()),
            );
          } else if (_currentIndex == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FavoritesScreen()),
            );
          } else if (_currentIndex == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ViewProfilePage()),
            );
          }
        },
      ),
    );
  }
}
