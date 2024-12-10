import 'package:flutter/material.dart';
import 'package:gradproj/screens/PropertyDetails.dart';
import '../models/Property.dart';
import '../Models/PropertyCard.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PropertyListScreen extends StatefulWidget {
  const PropertyListScreen({super.key});

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
      final url = Uri.parse(
          "https://property-finder-3a4b1-default-rtdb.firebaseio.com/Property%20Finder.json");
      final http.Response response = await http.get(url);

      if (response.statusCode == 200 && response.body != "null") {
        final List<dynamic> data = json.decode(response.body);
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
                  sqft: entry[' Size']?.toDouble() ?? 0.0,
                  price: entry[' Price']?.toDouble() ?? 0.0,
                  amenities: entry['Amenities']?.cast<String>() ?? [],
                  imgUrl: (entry['ImageUrl']?.isNotEmpty ?? false)
                      ? entry['ImageUrl']
                      : 'https://agentrealestateschools.com/wp-content/uploads/2021/11/real-estate-property.jpg',
                  type: entry['Property Type']?.trim() ?? 'Unknown',
                  street: entry['Street Mention']?.trim() ?? '',
                  location: entry['Location Mention']?.trim() ?? '',
                  rentOrSale: entry['Rent or Sale']?.trim() ?? 'Unknown',
                ))
            .toList();

        setState(() {
          properties.addAll(newProperties);
        });
      } else {
        print("No data available or failed to load properties.");
      }
    } catch (exception) {
      print("Exception fetching properties: $exception");
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
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
