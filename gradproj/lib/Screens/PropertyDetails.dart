import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gradproj/Screens/CustomBottomNavBar.dart';
import '../models/Property.dart';
import 'package:http/http.dart' as http;

class PropertyDetails extends StatefulWidget {
  final Property property;

  const PropertyDetails({super.key, required this.property});

  @override
  _PropertyDetailsState createState() => _PropertyDetailsState();
}

class _PropertyDetailsState extends State<PropertyDetails> {
  final TextEditingController _feedbackController = TextEditingController();
  int _currentIndex = 0; // For the bottom nav bar state

  Future<bool> postFeedback(String feedbackText) async {
    String propertyId = widget.property.id;
    final url = Uri.parse(
        "https://property-finder-3a4b1-default-rtdb.firebaseio.com/Property%20Finder/$propertyId/Review.json");

    try {
      final getFeedbacks = await http.get(url);
      List<dynamic> existingReviews = [];

      if (getFeedbacks.statusCode == 200 && getFeedbacks.body != "null") {
        final decodedResponse = jsonDecode(getFeedbacks.body);

        if (decodedResponse is List) {
          existingReviews = decodedResponse;
        } else if (decodedResponse is String) {
          existingReviews = [{'review': decodedResponse}];
        } else if (decodedResponse is Map<String, dynamic>) {
          existingReviews = [decodedResponse];
        }
      }

      existingReviews.add({'review': feedbackText});

      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(existingReviews),
      );

      return (response.statusCode >= 200 && response.statusCode < 400);
    } catch (e) {
      print("Error posting feedback: $e");
      return false;
    }
  }

  void _submitFeedback() async {
    final feedback = _feedbackController.text;

    if (feedback.isNotEmpty) {
      if (await postFeedback(feedback)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Feedback submitted: $feedback")),
        );
        _feedbackController.clear();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not submit the feedback")),
      );
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final property = widget.property;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Property Details"),
        backgroundColor: const Color(0xFF398AE5),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Image with Gradient Overlay
            Stack(
              children: [
                Image.network(
                  'https://agentrealestateschools.com/wp-content/uploads/2021/11/real-estate-property.jpg',
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Property Information
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.name,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Location: ${property.city}",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            // Property Description
            Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(16.0),
              child: Text(
                property.description,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
            // Additional Details Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildCard(
                title: "Additional Details",
                content: [
                  Text("Rooms: ${property.rooms}", style: const TextStyle(fontSize: 16)),
                  Text("Toilets: ${property.toilets}", style: const TextStyle(fontSize: 16)),
                  Text("Floor: ${property.floor ?? 'N/A'}", style: const TextStyle(fontSize: 16)),
                  Text("Area: ${property.sqft} sqft", style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
            // Feedback Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildCard(
                title: "Your Feedback",
                content: [
                  TextField(
                    controller: _feedbackController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Write your feedback here...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _submitFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Submit",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
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
          // Add navigation logic here if needed
        },
      ),
    );
  }

  Widget _buildCard({required String title, required List<Widget> content}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 8),
            ...content,
          ],
        ),
      ),
    );
  }
}
