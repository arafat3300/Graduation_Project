import 'package:flutter/material.dart';
import '../models/Property.dart';

class PropertyDetails extends StatelessWidget {
  final Property property;

  const PropertyDetails({required this.property});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Property Details")),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property Image
            Image.network(property.imgUrl),

            // Property Title and Location
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Location: ${property.city}",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Property Description
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                property.description,
                style: TextStyle(fontSize: 16),
              ),
            ),

            // Property Amenities
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Amenities:",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...property.amenities.map((amenity) => Text(amenity)),
                ],
              ),
            ),

            // Property Price
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Price: \$${property.price}",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Additional Property Details (Rooms, Floor, etc.)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Rooms: ${property.rooms}", style: TextStyle(fontSize: 16)),
                  Text("Toilets: ${property.toilets}", style: TextStyle(fontSize: 16)),
                  Text("Floor: ${property.floor ?? 'N/A'}", style: TextStyle(fontSize: 16)),
                  Text("Area: ${property.sqft} sqft", style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
