import 'package:flutter/material.dart';
import '../models/Property.dart';

class PropertyDetails extends StatefulWidget {
  final Property property;
  const PropertyDetails({required this.property});

  @override
  _PropertyDetailsState createState() => _PropertyDetailsState();
}

class _PropertyDetailsState extends State<PropertyDetails> {
  final TextEditingController _feedbackController = TextEditingController();

  void _submitFeedback() {
    final feedback = _feedbackController.text;

    if (feedback.isNotEmpty) {


      // el code el bywady el feedback lel ai model


      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Feedback submitted: $feedback")),
      );

      _feedbackController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your feedback.")),
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
                        ...?property.amenities?.map((amenity) => Text(
                         "- $amenity",
                      style: const TextStyle(fontSize: 16),
                      )).toList() ?? [Text("No amenities available")],
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
                      Text("Rooms: ${property.rooms}", style: const TextStyle(fontSize: 16)),
                      Text("Toilets: ${property.toilets}", style: const TextStyle(fontSize: 16)),
                      Text("Floor: ${property.floor ?? 'N/A'}", style: const TextStyle(fontSize: 16)),
                      Text("Area: ${property.sqft} sqft", style: const TextStyle(fontSize: 16)),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
