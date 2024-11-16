import 'dart:convert';

import 'package:flutter/material.dart';
import '../models/Property.dart';
import 'package:http/http.dart' as http;

class PropertyDetails extends StatefulWidget {
  final Property property;
  const PropertyDetails({required this.property});

  @override
  _PropertyDetailsState createState() => _PropertyDetailsState();
}

class _PropertyDetailsState extends State<PropertyDetails> {
  final TextEditingController _feedbackController = TextEditingController();


Future<bool> postToFastApi() async {
  String propertyId = widget.property.id;
  final url = Uri.parse("http://10.0.2.2:8000/feedback"); // Corrected URL
  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({ // Ensure JSON encoding
        "feedback_text": _feedbackController.text,
        "property_id": propertyId,
      }),
    );

    // Log the response for debugging
    debugPrint("API Response Status: ${response.statusCode}");
    debugPrint("API Response Body: ${response.body}");

    return (response.statusCode >= 200 && response.statusCode < 400);
  } catch (err) {
    debugPrint("Error posting feedback to FastAPI: $err");
    return false;
  }
}


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
      debugPrint("Existing reviews for $propertyId: $existingReviews");
    }

   
    existingReviews.add({'review ': feedbackText});
    debugPrint("Reviews after adding new feedback: $existingReviews");

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
      if (await postFeedback(feedback) && await postToFastApi()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Feedback submitted: $feedback")),
        );
        _feedbackController.clear();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("could not submit the feedback")),
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
      appBar: AppBar(title: const Text("Property Details")),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              'https://agentrealestateschools.com/wp-content/uploads/2021/11/real-estate-property.jpg',
              height: 250,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
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
                  const SizedBox(height: 4),
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
            Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(16.0),
              child: Text(
                property.description,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Specialities",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...property.amenities
                              ?.map((amenity) => Text(
                                    "- $amenity",
                                    style: const TextStyle(fontSize: 16),
                                  ))
                              .toList() ??
                          [Text("No amenities available")],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Price: \$${property.price}",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Additional Details",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text("Rooms: ${property.rooms}",
                          style: const TextStyle(fontSize: 16)),
                      Text("Toilets: ${property.toilets}",
                          style: const TextStyle(fontSize: 16)),
                      Text("Floor: ${property.floor ?? 'N/A'}",
                          style: const TextStyle(fontSize: 16)),
                      Text("Area: ${property.sqft} sqft",
                          style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Your Feedback",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 24),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
