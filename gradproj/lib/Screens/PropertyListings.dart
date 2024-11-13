import 'package:flutter/material.dart';
import 'package:gradproj/screens/PropertyDetails.dart';
import '../models/Property.dart';
import '../models/PropertyCard.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PropertyListScreen extends StatefulWidget {
  @override
  _PropertyListScreenState createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  List<Property> properties = [];



  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchProperties(); // Fetch the initial properties
   
  }

  Future<void> fetchProperties() async {
  

    try {
      // Construct the URL directly using Uri.parse (no pagination for testing)
      final url = Uri.parse("https://property-finder-3a4b1-default-rtdb.firebaseio.com/Property%20Finder.json");

      // Make the request to Firebase
      final http.Response response = await http.get(url);
      debugPrint("Response status: ${response.statusCode}");
      debugPrint("Response body: ${response.body}");

      if (response.statusCode == 200 && response.body != "null") {
        // Decode the response body as a List
        final List<dynamic> data = json.decode(response.body);

        // Convert each non-null entry in the list to a Property object
final newProperties = data
    .where((entry) => entry != null)
    .map((entry) => Property(
          id: entry['ID']?.toString() ?? 'unknown_id',
          name: entry['Property Name']?.trim() ?? 'Unknown',
          description: entry['Description']?.trim() ?? '',
          feedback: (entry['Review'] is List)
              ? entry['Review']?.cast<String>() ?? []
              : [entry['Review']?.toString() ?? 'No review available'],
          city: entry['City']?.trim() ?? '',
          rooms: entry['Number of Bedrooms'] ?? 0,
          toilets: entry['Number of Bathrooms'] ?? 0,
          floor: entry['Floor'] ?? 0,
          sqft: entry[' Size']?.toDouble() ?? 0.0, // Note the space
          price: entry[' Price']?.toDouble() ?? 0.0, // Note the space
          amenities: entry['Amenities']?.cast<String>() ?? [],
          imgUrl: entry['ImageUrl'] ?? 'https://agentrealestateschools.com/wp-content/uploads/2021/11/real-estate-property.jpg',
          type: entry['Property Type']?.trim() ?? 'Unknown',
          street: entry['Street Mention']?.trim() ?? '',
          location: entry['Location Mention']?.trim() ?? '',
          rentOrSale: entry['Rent or Sale']?.trim() ?? 'Unknown',
        ))
    .toList();


        // Append new properties and increment page
        setState(() {
          properties.addAll(newProperties);
         
        });
      } else {
        print("No data available or failed to load properties.");
      }
    } catch (exception) {
      print("Exception fetching properties: $exception");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Failed to load properties. Please try again later."),
      ));
    } finally {
  
    }
  }

  @override
  Widget build(BuildContext context) {
     
    return Scaffold(
     
      appBar: AppBar(
        title: const Text("Property Listings"),
      ),
      body: GridView.builder(
        
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          mainAxisSpacing: 10.0,
          crossAxisSpacing: 10.0,
          childAspectRatio: 0.75,
        ),
        itemCount: properties.length , // Add 1 item for loading indicator
        itemBuilder: (context, index) {
  
          final property = properties[index];
          return GestureDetector(
            onTap: () {
              // Navigate to PropertyDetails screen and pass the property
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PropertyDetails(property: property),
                ),
              );
            },
            child: PropertyCard(property: property), // Display property card
          );
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
