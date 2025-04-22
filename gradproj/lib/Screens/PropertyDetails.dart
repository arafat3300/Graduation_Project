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
  List<propertyFeedbacks> _feedbacks = [];
  List<dynamic> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  bool _isBulkLoading = false;
  final FeedbackController _feedbackService = FeedbackController();
  late ChatController _chatController;

  final String fastApiUrl = 'http://192.168.1.36:8009/feedback';
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

  // Future<void> _sendFeedbackToFastAPI({
  //   required String feedbackText,
  //   required int propertyId,
  //   required String? userId,
  // }) async {
  //   try {
  //     final response = await http.post(
  //       Uri.parse(fastApiUrl),
  //       headers: {
  //         'Content-Type': 'application/json',
  //       },
  //       body: jsonEncode({
  //         'feedback_text': feedbackText,
  //         'property_id': propertyId,
  //         'user_id': userId ?? 'anonymous',
  //       }),
  //     );

  //     if (response.statusCode != 200) {
  //       throw Exception(
  //           'Failed to send feedback to AI pipeline: ${response.body}');
  //     }
  //   } catch (e) {
  //     // throw Exception('Error sending feedback to AI pipeline: $e');
  //     debugPrint('Error sending feedback to AI pipeline: $e');
  //   }
  // }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // final supabase = Supabase.instance.client;
      final userId = singletonSession().userId;

      // Save to Supabase
      await _feedbackService.addFeedback(
        widget.property.id!,
        _feedbackController.text,
        userId,
      );
      debugPrint("Feedback added to DB: ${_feedbackController.text}");

      // Send to FastAPI
      // await _sendFeedbackToFastAPI(
      //   feedbackText: _feedbackController.text,
      //   propertyId: widget.property.id!,
      //   userId: userId.toString(),
      // );

      // Send email
      final emailSender = ref.read(emailSenderProvider);
      await emailSender.sendEmail(
        propertyId: widget.property.id!,
        userId: userId!,
        feedbackText: _feedbackController.text, // Pass the feedback text here
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
      _feedbackController
          .clear(); // Clear the feedback text AFTER sending the email
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Property Details"),
        backgroundColor: theme.colorScheme.primary,
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
             Padding(
  padding: const EdgeInsets.all(16.0),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(Icons.category, color: Colors.black), // Icon for property type
          const SizedBox(width: 8),
          Text(
            property.type,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Icon(Icons.attach_money, color: Colors.blue[700]), // Icon for price
          const SizedBox(width: 8),
          Text(
            "Price: \$${property.price}",
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.blue[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.black), // Icon for ID
                    const SizedBox(width: 8),
                    Text("ID: ${property.id}", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black)),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.bed, color: Colors.black), // Icon for bedrooms
                    const SizedBox(width: 8),
                    Text("Bedrooms: ${property.bedrooms}", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.bathtub, color: Colors.black), // Icon for bathrooms
                    const SizedBox(width: 8),
                    Text("Bathrooms: ${property.bathrooms}", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black)),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.square_foot, color: Colors.black), // Icon for area
                    const SizedBox(width: 8),
                    Text("Area: ${property.area} m²", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.home, color: Colors.black), // Icon for furnished
                    const SizedBox(width: 8),
                    Text("Furnished: ${property.furnished}", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black)),
                  ],
                ),
                if (property.level != null) 
                  Row(
                    children: [
                      Icon(Icons.arrow_upward, color: Colors.black), // Icon for level
                      const SizedBox(width: 8),
                      Text("Level: ${property.level}", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_city, color: Colors.black), // Icon for city
                    const SizedBox(width: 8),
                    Text("City: ${property.city}", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black)),
                  ],
                ),
                if (property.compound != null && property.compound!.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.apartment, color: Colors.black), // Icon for compound
                      const SizedBox(width: 8),
                      Text("Compound: ${property.compound}", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.payment, color: Colors.black), // Icon for payment option
                    const SizedBox(width: 8),
                    Text("Payment Option: ${property.paymentOption}", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black)),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.sell, color: Colors.black), // Icon for sale/rent
                    const SizedBox(width: 8),
                    Text("For: ${property.sale_rent}", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black)),
                  ],
                ),
              ],
            ),
            if (property.sale_rent == "sale") ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.payments, color: Colors.black), // Icon for down payment
                      const SizedBox(width: 8),
                      Text("Down Payment: ${property.downPayment?.toStringAsFixed(1)}%", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black)),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.black), // Icon for installment years
                      const SizedBox(width: 8),
                      Text("Installment Years: ${property.installmentYears ?? 'N/A'}", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event, color: Colors.black), // Icon for delivery year
                      const SizedBox(width: 8),
                      Text("Delivery Year: ${property.deliveryIn ?? 'N/A'}", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black)),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.home_work, color: Colors.black), // Icon for finishing
                      const SizedBox(width: 8),
                      Text("Finishing: ${property.finishing ?? 'N/A'}", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black)),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      const SizedBox(height: 12), // Moved outside the .map() operation
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
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
                color: Colors.white),
            label: Text(
                isFavorite ? "Remove from Favorites" : "Add to Favorites"),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.blueAccent,
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {
              _createLead();
            },
            icon: const Icon(Icons.phone, color: Colors.white),
            label: const Text("Contact Seller"),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.blueAccent,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
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
            border: OutlineInputBorder(
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
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
          child: Text(_isLoading ? "Submitting..." : "Submit Feedback"),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: theme.colorScheme.primary,
          ),
        ),
      ],
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
                  child: Text("No feedback available for this property."),
                ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chat:',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_messages.isNotEmpty)
                      Container(
                        height: 300,
                        child: ListView.builder(
                          reverse: true,
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isMe =
                                message.senderId == singletonSession().userId;
                            debugPrint(
                                "Message senderId: ${message.senderId}, Current userId: ${singletonSession().userId}");

                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    vertical: 5, horizontal: 10),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? theme.colorScheme.primary
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  message.content,
                                  style: TextStyle(
                                      color:
                                          isMe ? Colors.white : Colors.black),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    else
                      const Center(
                          child:
                              Text('No messages yet. Start a conversation!')),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              hintText: 'Type your message...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _isSending
                            ? const CircularProgressIndicator()
                            : IconButton(
                                icon:
                                    const Icon(Icons.send, color: Colors.blue),
                                onPressed: _sendMessage,
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
