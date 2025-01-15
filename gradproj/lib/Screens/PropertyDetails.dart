import 'dart:convert';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../Providers/FavouritesProvider.dart';
import '../models/Property.dart';
import '../Models/Feedback.dart';
import '../Controllers/feedback_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PropertyDetails extends ConsumerStatefulWidget {
  final Property property;
  const PropertyDetails({super.key, required this.property});

  @override
  _PropertyDetailsState createState() => _PropertyDetailsState();
}

class _PropertyDetailsState extends ConsumerState<PropertyDetails> {
  final TextEditingController _feedbackController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<propertyFeedbacks> _feedbacks = [];
  bool _isLoading = false;
  bool _isBulkLoading = false;
  final FeedbackController _feedbackService =
      FeedbackController(supabase: Supabase.instance.client);

  final String fastApiUrl = 'http://localhost:8009/feedback';

  @override
  void initState() {
    super.initState();
    _loadFeedbacks();
    _sendAllFeedbacksToFastAPI();
  }

  Future<void> _loadFeedbacks() async {
    try {
      final feedbacks =
          await _feedbackService.getFeedbacksByProperty(widget.property.id!);
      if (mounted) {
        setState(() {
          _feedbacks = feedbacks;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading feedbacks: $e')),
        );
      }
    }
  }

  Future<void> _sendFeedbackToFastAPI({
    required String feedbackText,
    required int propertyId,
    required String? userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(fastApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'feedback_text': feedbackText,
          'property_id': propertyId,
          'user_id': userId ?? 'anonymous',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send feedback to AI pipeline: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error sending feedback to AI pipeline: $e');
    }
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      // Save to Supabase
      await _feedbackService.addFeedback(
        widget.property.id!,
        _feedbackController.text,
        user?.id,
      );

      // Send to FastAPI
      await _sendFeedbackToFastAPI(
        feedbackText: _feedbackController.text,
        propertyId: widget.property.id!,
        userId: user?.id,
      );

      await _loadFeedbacks();
      _feedbackController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback submitted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting feedback: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendAllFeedbacksToFastAPI() async {
    setState(() => _isBulkLoading = true);

    try {
      final feedbacks = await _feedbackService.getAllFeedbacks();
      for (final feedback in feedbacks) {
        await _sendFeedbackToFastAPI(
          feedbackText: feedback.feedback,
          propertyId: feedback.property_id,
          userId: feedback.user_id.toString() ?? 'anonymous',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All feedbacks sent to FastAPI successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending feedbacks to FastAPI: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBulkLoading = false);
      }
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
    final favouritesNotifier = ref.watch(favouritesProvider.notifier);
    final isFavorite =
        ref.watch(favouritesProvider).any((p) => p.id == property.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Property Details"),
        backgroundColor: const Color(0xFF398AE5),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (property.imgUrl != null && property.imgUrl!.isNotEmpty)
              CarouselSlider(
                options: CarouselOptions(
                  height: 600,
                  autoPlay: true,
                  autoPlayInterval: const Duration(seconds: 3),
                  enlargeCenterPage: true,
                  viewportFraction: 1.0,
                  aspectRatio: 2.0,
                ),
                items: property.imgUrl!.map((imageUrl) {
                  return Builder(
                    builder: (BuildContext context) {
                      return Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, size: 70),
                      );
                    },
                  );
                }).toList(),
              )
            else
              Container(
                height: 600,
                width: double.infinity,
                color: Colors.grey[200],
                child: Center(
                  child: Image.network(
                    'https://agentrealestateschools.com/wp-content/uploads/2021/11/real-estate-property.jpg',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image, size: 70),
                  ),
                ),
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
                    "Price: \$${property.price}",
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "City: ${property.city}",
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
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
                          SnackBar(
                            content: Text("${property.type} removed from favorites"),
                          ),
                        );
                      } else {
                        favouritesNotifier.addProperty(property);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("${property.type} added to favorites"),
                          ),
                        );
                      }
                    },
                    icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                    label: Text(
                      isFavorite ? "Remove from Favorites" : "Add to Favorites"
                    ),
                  ),
                ],
              ),
            ),

            // Feedback Form Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _feedbackController,
                      decoration: const InputDecoration(
                        labelText: 'Enter your feedback',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Feedback cannot be empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _submitFeedback,
                            child: const Text('Submit Feedback'),
                          ),
                  ],
                ),
              ),
            ),

            // Feedback List Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _feedbacks.isEmpty
                  ? const Text('No feedbacks yet.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Feedbacks:',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._feedbacks.map(
                          (feedback) => ListTile(
                            title: Text(feedback.feedback),
                            subtitle: Text('By ${feedback.user_id ?? 'Anonymous'}'),
                          ),
                        ),
                      ],
                    ),
            ),

            
          ],
        ),
      ),
    );
  }
}
