import 'dart:convert';
// import 'dart:nativewrappers/_internal/vm/lib/internal_patch.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradproj/Controllers/chat_controller.dart';
import 'package:gradproj/Models/singletonSession.dart';
import 'package:gradproj/config/database_config.dart';
import 'package:http/http.dart' as http;
import '../Providers/EmailProvider.dart';
import '../Providers/FavouritesProvider.dart';
import '../Models/propertyClass.dart';
import '../Models/Feedback.dart';
import '../Models/Message.dart';
import '../Controllers/feedback_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:developer';
import '../Controllers/oodo_rpc_controller.dart';
import 'package:profanity_filter/profanity_filter.dart';

class CustomProfanityFilter extends ProfanityFilter {
  final List<String> arabicProfanityWords = [
    // Basic forms
    'عاهر', 'عاهرة', 'كلب', 'كلبة', 'زاني', 'زانية',
    'شرموط', 'شرموطة', 'قحبة', 'قحاب', 'عاهرات',
    'زناة', 'كلاب', 'كلبات', 'شراميط', 'شراميط',
    'قحاب', 'عاهرات', 'زناة', 'كلاب', 'كلبات',
    'شراميط', 'شراميط', 'قحاب', 'عاهرات', 'زناة',
    'كلاب', 'كلبات', 'شراميط', 'شراميط', 'قحاب',
    'وسخ', 'زبالة', 'وساخ', 'زبال', 'وسخة', 'زبالة',

    // Variations with different spellings
    'عاهره', 'عاهرات', 'عاهره', 'عاهرات', 'عاهره', 'عاهرات',
    'كلبه', 'كلبات', 'كلبه', 'كلبات', 'كلبه', 'كلبات',
    'زانيه', 'زناة', 'زانيه', 'زناة', 'زانيه', 'زناة',
    'شرموطه', 'شراميط', 'شرموطه', 'شراميط', 'شرموطه', 'شراميط',
    'قحبه', 'قحاب', 'قحبه', 'قحاب', 'قحبه', 'قحاب',
    'وسخه', 'زباله', 'وساخه', 'زباله', 'وسخة', 'زبالة',

    // Common variations
    'عاهرين', 'عاهرات', 'عاهرين', 'عاهرات', 'عاهرين', 'عاهرات',
    'كلابين', 'كلبات', 'كلابين', 'كلبات', 'كلابين', 'كلبات',
    'زانين', 'زناة', 'زانين', 'زناة', 'زانين', 'زناة',
    'شراميطين', 'شراميط', 'شراميطين', 'شراميط', 'شراميطين', 'شراميط',
    'قحابين', 'قحاب', 'قحابين', 'قحاب', 'قحابين', 'قحاب',
    'وساخين', 'زبالين', 'وساخين', 'زبالين', 'وساخين', 'زبالين',

    // Additional forms
    'عاهرون', 'عاهرات', 'عاهرون', 'عاهرات', 'عاهرون', 'عاهرات',
    'كلابون', 'كلبات', 'كلابون', 'كلبات', 'كلابون', 'كلبات',
    'زانون', 'زناة', 'زانون', 'زناة', 'زانون', 'زناة',
    'شراميطون', 'شراميط', 'شراميطون', 'شراميط', 'شراميطون', 'شراميط',
    'قحابون', 'قحاب', 'قحابون', 'قحاب', 'قحابون', 'قحاب',
    'وساخون', 'زبالون', 'وساخون', 'زبالون', 'وساخون', 'زبالون',

    // Common combinations
    'ابن العاهرة', 'بنت العاهرة', 'ابن الكلب', 'بنت الكلب',
    'ابن الزاني', 'بنت الزانية', 'ابن الشرموط', 'بنت الشرموطة',
    'ابن القحبة', 'بنت القحبة', 'ابن العاهر', 'بنت العاهرة',
    'ابن الوسخ', 'بنت الوسخ', 'ابن الزبالة', 'بنت الزبالة',

    // Additional variations
    'عاهرين', 'عاهرات', 'عاهرين', 'عاهرات', 'عاهرين', 'عاهرات',
    'كلابين', 'كلبات', 'كلابين', 'كلبات', 'كلابين', 'كلبات',
    'زانين', 'زناة', 'زانين', 'زناة', 'زانين', 'زناة',
    'شراميطين', 'شراميط', 'شراميطين', 'شراميط', 'شراميطين', 'شراميط',
    'قحابين', 'قحاب', 'قحابين', 'قحاب', 'قحابين', 'قحاب',
    'وساخين', 'زبالين', 'وساخين', 'زبالين', 'وساخين', 'زبالين'
  ];

  @override
  bool hasProfanity(String text) {
    // Check both English and Arabic profanity
    final hasEnglishProfanity = super.hasProfanity(text);
    final hasArabicProfanity = arabicProfanityWords.any((word) =>
        text.toLowerCase().contains(word.toLowerCase()) || text.contains(word));

    return hasEnglishProfanity || hasArabicProfanity;
  }

  @override
  String censor(String text, {String? replaceWith}) {
    String censoredText = super.censor(text, replaceWith: replaceWith);
    // Censor Arabic profanity
    for (var word in arabicProfanityWords) {
      final pattern = RegExp(word, caseSensitive: false);
      censoredText =
          censoredText.replaceAll(pattern, (replaceWith ?? '*') * word.length);
    }
    return censoredText;
  }
}

class PropertyDetails extends ConsumerStatefulWidget {
  final Property property;

  const PropertyDetails({super.key, required this.property});

  @override
  _PropertyDetailsState createState() => _PropertyDetailsState();
}

class _PropertyDetailsState extends ConsumerState<PropertyDetails> {
  final TextEditingController _feedbackController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final CustomProfanityFilter _profanityFilter = CustomProfanityFilter();
  List<propertyFeedbacks> _feedbacks = [];
  List<dynamic> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  bool _isBulkLoading = false;
  final FeedbackController _feedbackService = FeedbackController();
  late ChatController _chatController;

  // final String fastApiUrl = 'http://192.168.1.36:8000/feedback';
  final String fastApiUrl = 'http://10.0.2.2:8000/predict';
  String test = 't';

  @override
  void initState() {
    super.initState();
    _chatController = ChatController();
    _loadFeedbacks();
    // _sendAllFeedbacksToFastAPI();
    _loadMessages();
  }

  Future<void> _loadFeedbacks() async {
    try {
      final feedbacks =
          await _feedbackService.getFeedbacksByProperty(widget.property.id);

      // Fetch emails for each feedback user
      for (var fb in feedbacks) {
        if (fb.user_id != null) {
          final info = await _feedbackService.fetchUserInfo(fb.user_id!);
          fb.email = info?['email'] ?? 'Anonymous';
        } else {
          fb.email = 'Anonymous';
        }
      }

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

  // Future<void> _sendAllFeedbacksToFastAPI() async {
  //   setState(() => _isBulkLoading = true);

  //   try {
  //     final feedbacks = await _feedbackService.getAllFeedbacks();
  //     for (final feedback in feedbacks) {
  //       await _sendFeedbackToFastAPI(
  //         feedbackText: feedback.feedback,
  //         propertyId: feedback.property_id,
  //         userId: feedback.user_id.toString() ?? 'anonymous',
  //       );
  //     }

  //     debugPrint('All feedbacks sent to FastAPI successfully!');
  //   } catch (e) {
  //     debugPrint('Error sending feedbacks to FastAPI: $e');
  //   } finally {
  //     if (mounted) {
  //       setState(() => _isBulkLoading = false);
  //     }
  //   }
  // }

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
      // throw Exception('Error sending feedback to AI pipeline: $e');
      debugPrint('Error sending feedback to AI pipeline: $e');
    }
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    final feedbackText = _feedbackController.text.trim();

    // Check for profanity
    if (_profanityFilter.hasProfanity(feedbackText)) {
      // Show warning dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Inappropriate Language Detected'),
              content: const Text(
                  'Your feedback contains inappropriate language. Would you like to:\n\n1. Edit your feedback\n2. Cancel submission'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      }
      return;
    }

    // If no profanity, submit normally
    await _submitFeedbackWithText(feedbackText);
  }

  Future<void> _submitFeedbackWithText(String feedbackText) async {
    setState(() => _isLoading = true);

    try {
      final userId = singletonSession().userId;

      // Save to Supabase
      await _feedbackService.addFeedback(
        widget.property.id!,
        feedbackText,
        userId,
      );
      debugPrint("Feedback added to DB: $feedbackText");

      // Send email
      final emailSender = ref.read(emailSenderProvider);
      await emailSender.sendEmail(
        propertyId: widget.property.id!,
        userId: userId!,
        feedbackText: feedbackText,
      );

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
      _feedbackController.clear();
    }
  }

  Future<void> _createLead() async {
    final userId = singletonSession().userId;
    final propertyId = widget.property.id!;
    final price = widget.property.price ?? 0;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please log in to contact the sales person.")),
      );
      return;
    }

    final odoo = OdooRPCController();

    final success = await odoo.createLeadFromPostgres(
      userId: userId,
      propertyId: propertyId,
      propertyPrice: price.toDouble(),
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lead created successfully in Odoo!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to create lead.")),
      );
    }
  }

  Future<void> _loadMessages() async {
    try {
      final propertyId = widget.property.id!;
      debugPrint(
          "Loading messages via controller for property ID: $propertyId");

      final messages = await _chatController.loadMessages(propertyId);

      if (mounted) {
        setState(() {
          _messages = messages;
        });
      }
    } catch (e) {
      debugPrint("Error loading messages: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading messages: $e')),
      );
    }
    debugPrint("Messages loaded successfully mvc");
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final content = _messageController.text.trim();
      await _chatController.sendMessage(
        senderId: singletonSession().userId!,
        receiverId: widget.property.userId!,
        propertyId: widget.property.id!,
        content: content,
      );

      _messageController.clear();
      await _loadMessages(); // Refresh messages
    } catch (e) {
      debugPrint("Error sending message: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
    debugPrint("Message sent successfully mvc");
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final property = widget.property;
    final favouritesNotifier = ref.watch(favouritesProvider.notifier);
    final isFavorite =
        ref.watch(favouritesProvider).any((p) => p.id == property.id);
    final theme = Theme.of(context);

    // Helper for amenities icons (copied from RecommendationCard.dart)
    IconData getAmenityIcon(String amenity) {
      switch (amenity.toLowerCase()) {
        case 'clubhouse':
          return Icons.golf_course;
        case 'schools':
          return Icons.school;
        case 'business hub':
          return Icons.business_center;
        case 'sports clubs':
          return Icons.sports_baseball;
        case 'mosque':
          return Icons.mosque;
        case 'disability support':
          return Icons.accessible;
        case 'bicycles lanes':
          return Icons.directions_bike;
        case 'pool':
          return Icons.pool;
        case 'gym':
          return Icons.fitness_center;
        case 'parking':
          return Icons.local_parking;
        case 'balcony':
          return Icons.balcony;
        case 'garden':
          return Icons.local_florist;
        case 'fireplace':
          return Icons.fireplace;
        case 'elevator':
          return Icons.elevator;
        case 'storage':
          return Icons.storage;
        case 'dishwasher':
          return Icons.kitchen;
        case 'hardwood':
          return Icons.texture;
        case 'security':
          return Icons.security;
        case 'concierge':
          return Icons.room_service;
        case 'doorman':
          return Icons.vpn_key;
        case 'sauna':
          return Icons.hot_tub;
        case 'spa':
          return Icons.spa;
        case 'playground':
          return Icons.child_friendly;
        case 'rooftop':
          return Icons.roofing;
        case 'garage':
          return Icons.garage;
        case 'wifi':
          return Icons.wifi;
        case 'laundry':
          return Icons.local_laundry_service;
        default:
          return Icons.category;
      }
    }

    Widget infoRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold,fontSize: 14),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    Widget sectionHeader(String title) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4.0, top: 12.0),
        child: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              colors: [
               Color.fromARGB(255, 8, 145, 236),
                                                 Color.fromARGB(255, 2, 48, 79),  // orange with opacity
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds);
          },
          child: const Text(
            "Property Details",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 2,
      ),
      body: Container(
        color: Colors.blueGrey[50], // Darker background for consistency
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (property.imgUrl != null && property.imgUrl!.isNotEmpty)
                CarouselSlider(
                  options: CarouselOptions(
                    height: 400,
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
                            color: theme.colorScheme.error,
                          ),
                        );
                      },
                    );
                  }).toList(),
                )
              else
                Container(
                  height: 400,
                  width: double.infinity,
                  color: theme.colorScheme.surface,
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
              // NEW LAYOUT STARTS HERE
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Property type and Add to Favorites button in a row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            property.type,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color.fromARGB(255, 8, 145, 236),
                                Color.fromARGB(255, 2, 48, 79),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (isFavorite) {
                                await favouritesNotifier.removeProperty(property);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("${property.type} removed from favorites"),
                                    action: SnackBarAction(
                                      label: 'Manage Favorites',
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/favourites');
                                      },
                                    ),
                                  ),
                                );
                              } else {
                                await favouritesNotifier.addProperty(property);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("${property.type} added to favorites"),
                                    action: SnackBarAction(
                                      label: 'Manage Favorites',
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/favourites');
                                      },
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: Colors.white,
                            ),
                            label: Text(isFavorite ? "Remove from Favorites" : "Add to Favorites"),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Row: Bedrooms, Bathrooms, Area with labels under icons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Icon(Icons.bed, color: Colors.blueGrey[700], size: 32),
                            const SizedBox(height: 2),
                            Text('${property.bedrooms}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text('Bedrooms', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        Column(
                          children: [
                            Icon(Icons.bathtub, color: Colors.blueGrey[700], size: 32),
                            const SizedBox(height: 2),
                            Text('${property.bathrooms}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text('Bathrooms', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        Column(
                          children: [
                            Icon(Icons.square_foot, color: Colors.blueGrey[700], size: 32),
                            const SizedBox(height: 2),
                            Text('${property.area} m²', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text('Area', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Main Info Section
                    Card(
                      color: Colors.white,
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Main Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.blueGrey[900])),
                            const SizedBox(height: 8),
                            infoRow('ID', property.id.toString()),
                            infoRow('Price', '${property.price} EGP'),
                            infoRow('Type', property.type),
                            infoRow('For', property.sale_rent),
                          ],
                        ),
                      ),
                    ),
                    // Property Details Section
                    Card(
                      color: Color.fromARGB(255, 255, 255, 255),
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Property Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.blueGrey[900])),
                            const SizedBox(height: 8),
                            infoRow('City', property.city),
                            infoRow('Compound', property.compound ?? 'N/A'),
                            infoRow('Finishing', property.finishing ?? 'N/A'),
                            infoRow('Furnished', property.furnished),
                          ],
                        ),
                      ),
                    ),
                    // Payment Plan Section (now same color as Main Info)
                    Card(
                      color: Colors.white,
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Payment Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.black)),
                            const SizedBox(height: 8),
                            infoRow('Payment Option', property.paymentOption),
                            infoRow('Down Payment', property.downPayment != null ? '${property.downPayment!.toStringAsFixed(1)}%' : 'N/A'),
                            infoRow('Installment Years', property.installmentYears?.toString() ?? 'N/A'),
                          ],
                        ),
                      ),
                    ),
                    // Amenities Section (now same color as Property Details)
                    if (property.amenities != null && property.amenities!.isNotEmpty) ...[
                      Card(
                        color: Color.fromARGB(255, 255, 255, 255),
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Amenities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.blue)),
                              const SizedBox(height: 6),
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                childAspectRatio: 9.0, // Decreased vertical space by 40%
                                mainAxisSpacing: 1,
                                crossAxisSpacing: 8,
                                children: property.amenities!.map((amenity) {
                                  return Row(
                                    children: [
                                      Icon(getAmenityIcon(amenity), size: 24, color: Color.fromARGB(255, 8, 145, 236)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          amenity,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Add Feedback",
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _feedbackController,
                          decoration: InputDecoration(
                            hintText: "Enter your feedback",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(
                                width: 2,
                                color: Color.fromARGB(255, 2, 48, 79),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(
                                width: 2,
                                color: Color.fromARGB(255, 2, 48, 79),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(
                                width: 2,
                                color: Color(0xFFFF6F1A),
                              ),
                            ),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 3,
                          keyboardType: TextInputType.text,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.start,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your feedback';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color.fromARGB(255, 8, 145, 236),
                                Color.fromARGB(255, 2, 48, 79),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Align(
                            alignment: Alignment.center,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submitFeedback,
                              child: Text(
                                  _isLoading ? "Submitting..." : "Submit Feedback",
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color.fromARGB(255, 8, 145, 236),
                                  Color.fromARGB(255, 2, 48, 79),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _createLead,
                              icon: const Icon(Icons.phone, color: Colors.white),
                              label: const Text("Contact Seller"),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_feedbacks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _feedbacks.map((feedback) {
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feedback.email ?? "Anonymous",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 5),
                            Text(feedback.feedback),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("No feedback available for this property.",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
