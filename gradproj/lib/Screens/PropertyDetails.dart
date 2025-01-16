import 'dart:convert';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradproj/Models/singletonSession.dart';
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
        throw Exception(
            'Failed to send feedback to AI pipeline: ${response.body}');
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
      final userId = singletonSession().userId;

      // Save to Supabase
      await _feedbackService.addFeedback(
        widget.property.id!,
        _feedbackController.text,
        userId,
      );

      // Send to FastAPI
      await _sendFeedbackToFastAPI(
        feedbackText: _feedbackController.text,
        propertyId: widget.property.id!,
        userId: userId.toString(),
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
          const SnackBar(
              content: Text('All feedbacks sent to FastAPI successfully!')),
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
    final theme = Theme.of(context); // Get the current theme

    return Scaffold(
      appBar: AppBar(
        title: const Text("Property Details"),
        backgroundColor: theme.colorScheme.primary, // Use theme primary color
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
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.broken_image,
                          size: 70,
                          color:
                              theme.colorScheme.error, // Use theme error color
                        ),
                      );
                    },
                  );
                }).toList(),
              )
            else
              Container(
                height: 600,
                width: double.infinity,
                color: theme.colorScheme.surface, // Use theme surface color
                child: Center(
                  child: Image.network(
                    'https://agentrealestateschools.com/wp-content/uploads/2021/11/real-estate-property.jpg',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.broken_image,
                      size: 70,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.type,
                    style:
                        theme.textTheme.headlineMedium, // Use theme text style
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Price: \$${property.price}",
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPropertyDetail("City", property.city, theme),
                  _buildPropertyDetail(
                      "Bedrooms", property.bedrooms.toString(), theme),
                  _buildPropertyDetail(
                      "Bathrooms", property.bathrooms.toString(), theme),
                  _buildPropertyDetail("Area", "${property.area} sqft", theme),
                  _buildPropertyDetail(
                      "Furnished", property.furnished.toString(), theme),
                  _buildPropertyDetail(
                      "Level", property.level?.toString() ?? 'N/A', theme),
                  _buildPropertyDetail(
                      "Compound", property.compound ?? 'N/A', theme),
                  _buildPropertyDetail(
                      "Payment Option", property.paymentOption, theme),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (isFavorite) {
                        favouritesNotifier.removeProperty(property);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  "${property.type} removed from favorites")),
                        );
                      } else {
                        favouritesNotifier.addProperty(property);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:Text("${property.type} added to favorites"),
                            duration: const Duration(seconds: 5),
                            action: SnackBarAction(
                              label: "Manage your Favorites",
                              textColor: Colors.blue,
                              onPressed: () {
                                Navigator.pushNamed(context, '/favourites');
                                },
                              ),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border),
                    label: Text(isFavorite
                        ? "Remove from Favorites"
                        : "Add to Favorites"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor:  const Color.fromARGB(255, 255, 255, 255),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Add Feedback",
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _feedbackController,
                      decoration: InputDecoration(
                        hintText: "Enter your feedback",
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onBackground
                              .withOpacity(0.6), // Adjust hint text color
                        ),
                        border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: theme.colorScheme.primary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        filled: true, // To ensure a proper background
                        fillColor: theme.colorScheme.background,
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your feedback';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitFeedback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      child: Text(
                          _isLoading ? "Submitting..." : "Submit Feedback"),
                    ),
                  ],
                ),
              ),
            ),
            if (_feedbacks.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _feedbacks.map((feedback) {
                    return FutureBuilder<String>(
                      future: feedback.user_id == null
                          ? Future.value("Anonymous")
                          : _feedbackService
                              .getMailOfFeedbacker(feedback.user_id!),
                      builder: (context, snapshot) {
                        final userName = feedback.user_id == null
                            ? "Anonymous"
                            : (snapshot.hasData
                                ? snapshot.data!
                                    .replaceAll(RegExp(r'[\{\}\[\]"]'), '')
                                    .replaceFirst("email:", "")
                                : "Loading...");

                        return Card(
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                                color: theme.colorScheme.primary, width: 1.5),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          margin: const EdgeInsets.only(bottom: 8.0),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  feedback.feedback,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                     color: theme.colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "No feedback available for this property.",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyDetail(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onBackground, // Adjust color for theme
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onBackground, // Adjust color for theme
            ),
          ),
        ],
      ),
    );
  }
}
