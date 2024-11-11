import 'package:flutter/material.dart';
import 'package:gradproj/screens/PropertyDetails.dart';
import '../models/Property.dart';
import '../models/PropertyCard.dart';

class PropertyListScreen extends StatefulWidget {
  @override
  _PropertyListScreenState createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  List <Property> properties = [];
  bool isLoading = false;
  int page = 1;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchProperties(); 
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && !isLoading) {
        fetchProperties(); // Load more properties when reaching end of list
      }
    });
  }

  Future<void> fetchProperties() async {
    
    setState(() {
      isLoading = true;
    });

    // Generate 20 new properties as dummy data
    final newProperties = generateDummyProperties(20);

    // Simulate a delay to mimic network request time
    await Future.delayed(Duration(seconds: 2));

    setState(() {
      properties.addAll(newProperties); // Append new properties to list
      page++; // Increment page number for next load
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Property Listings"),
      ),
      body: GridView.builder(
        controller: _scrollController, // Attach controller for pagination
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10.0,
          crossAxisSpacing: 10.0,
          childAspectRatio: 0.75,
        ),
        itemCount: properties.length + (isLoading ? 1 : 0), // Add 1 item for loading indicator
        itemBuilder: (context, index) {
          if (index == properties.length) {
            return Center(child: CircularProgressIndicator()); // Loading indicator
          }
          final property = properties[index];
          return GestureDetector(
            onTap: () {
              // Navigate to Propertydetails screen and pass the property
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PropertyDetails(property: property),
                ),
              );
            },
            child: PropertyCard(property: property), // Display property card
          ); // Display property card
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Clean up controller
    super.dispose();
  }
}

// Helper function to generate dummy data
List<Property> generateDummyProperties(int count) {
  return List.generate(count, (index) {
    return Property(
      id: 'prop_$index',
      name: 'Property $index',
      description: 'A beautiful property located in a prime area of the city, offering all modern amenities and conveniences.',
      feedback: 'Excellent property with great amenities.',
      city: 'City ${index % 5}', // Cycles through City 0, City 1, etc.
      rooms: 2 + (index % 4), // Varies from 2 to 5 rooms
      toilets: 1 + (index % 3), // Varies from 1 to 3 toilets
      floor: index % 10 == 0 ? null : (1 + (index % 5)), // Some floors are null, others vary from 1 to 5
      sqft: 500 + (index * 10).toDouble(), // Each property has a slightly larger area
      price: 100000 + (index * 5000).toDouble(), // Price increases with each property
      amenities: ['Pool', 'Gym', 'Garden'], // Sample amenities
      imgUrl: 'https://via.placeholder.com/150?text=Property+Image+$index', // Placeholder image URL
    );
  });
}
