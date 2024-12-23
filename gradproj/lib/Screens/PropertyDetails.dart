import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../Providers/FavouritesProvider.dart';
import '../models/Property.dart';

class PropertyDetails extends ConsumerStatefulWidget {
  final Property property;

  const PropertyDetails({super.key, required this.property});

  @override
  _PropertyDetailsState createState() => _PropertyDetailsState();
}

class _PropertyDetailsState extends ConsumerState<PropertyDetails> {


  @override
  Widget build(BuildContext context) {
    final property = widget.property;
    final favouritesNotifier = ref.watch(favouritesProvider.notifier);
    final isFavorite = ref.watch(favouritesProvider).any((p) => p.id == property.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Property Details"),
        backgroundColor: const Color(0xFF398AE5),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property Image
            Stack(
              children: [
                Image.network(
                  property.imgUrl != null && property.imgUrl!.isNotEmpty
                      ? property.imgUrl!
                      : 'https://agentrealestateschools.com/wp-content/uploads/2021/11/real-estate-property.jpg',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 250,
             
                ),
              ],
            ),

            // Property Details Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.type,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Price: \$${property.price.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "City: ${property.city}",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Bedrooms: ${property.bedrooms}",
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                  Text(
                    "Bathrooms: ${property.bathrooms}",
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                  Text(
                    "Area: ${property.area} sqft",
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                  Text(
                    "Furnished: ${property.furnished}",
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                  Text(
                    "Level: ${property.level ?? 'N/A'}",
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                  Text(
                    "Compound: ${property.compound ?? 'N/A'}",
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                  Text(
                    "Payment Option: ${property.paymentOption}",
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (isFavorite) {
                        favouritesNotifier.removeProperty(property);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("${property.type} removed from favorites")),
                        );
                      } else {
                        favouritesNotifier.addProperty(property);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("${property.type} added to favorites")),
                        );
                      }
                    },
                    icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                    label: Text(isFavorite ? "Remove from Favorites" : "Add to Favorites"),
                  ),
                ],
              ),
            ),

            // Feedback Section
            if (property.feedback.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Feedback:",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: property.feedback.map((feedback) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        "- $feedback",
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "No feedback available for this property.",
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
