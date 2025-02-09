import 'dart:convert';
// import 'dart:nativewrappers/_internal/vm/lib/internal_patch.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradproj/Models/singletonSession.dart';
import 'package:http/http.dart' as http;
import '../Providers/EmailProvider.dart';
import '../Providers/FavouritesProvider.dart';
import '../models/Property.dart';
import '../Models/Feedback.dart';
import '../Models/Message.dart';
import '../Controllers/feedback_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:developer';

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
  final FeedbackController _feedbackService =
      FeedbackController(supabase: Supabase.instance.client);

  final String fastApiUrl = 'http://192.168.1.36:8009/feedback';
  String test = 't';

  @override
  void initState() {
    super.initState();
    _loadFeedbacks();
    _sendAllFeedbacksToFastAPI();
    _loadMessages();
  }

  Future<void> _loadFeedbacks() async {
    try {
      final feedbacks =
          await _feedbackService.getFeedbacksByProperty(widget.property.id);
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
    _feedbackController.clear(); // Clear the feedback text AFTER sending the email
  }
}
Future<void> _createLead() async {
  final supabase = Supabase.instance.client;
  final userId = singletonSession().userId;

  if (userId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Please log in to contact the sales person.")),
    );
    return;
  }

  try {
    // Fetch user details from Supabase
    final response = await supabase
        .from('users')
        .select('firstname, lastname, email, phone, job')
        .eq('id', userId)
        .single();

    final userName = "${response['firstname'] ?? "Unknown"} ${response['lastname'] ?? "User"}";
    final userEmail = response['email'] ?? "No Email";
    final userPhone = response['phone'] ?? "No Phone";
    final job = response['job'] ?? "No Job";
  final propertyPrice = widget.property.price ?? 0;
    log(userName);
    log(userEmail);
    log(userPhone);

    // Odoo API Details
    const String odooUrl = "http://10.0.2.2:8069/jsonrpc";
    const String odooDb = "PropertyFinder";
    const String odooUsername = "aliarafat534@gmail.com";
    const String odooPassword = "lilO_khaled20";

    // Authenticate with Odoo
    final authResponse = await http.post(
      Uri.parse(odooUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
          "service": "common",
          "method": "authenticate",
          "args": [odooDb, odooUsername, odooPassword, {}]
        }
      }),
    );

    final authData = jsonDecode(authResponse.body);
    final userIdOdoo = authData['result'];

    if (userIdOdoo == null) {
      throw Exception("Failed to authenticate with Odoo");
    }

    // Create a lead in Odoo with property price in the name
    final leadResponse = await http.post(
      Uri.parse(odooUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
          "service": "object",
          "method": "execute_kw",
          "args": [
            odooDb,
            userIdOdoo,
            odooPassword,
            "crm.lead",
            "create",
            [
              {
                "name": "Property Inquiry: ${widget.property.id} ",
                "contact_name": userName,
                "email_from": userEmail,
                "phone": userPhone,
                "expected_revenue": propertyPrice,
                "function": job,  //  field for Job Position
                "description": "User $userName is interested in property with the ID of : ${widget.property.id}, priced at \$${widget.property.price} and his job is $job ",
              }
            ]
          ],
        },
      }),
    );

    final leadData = jsonDecode(leadResponse.body);
    log("Lead Creation Response: $leadData");  // Log the full response for debugging

    if (leadData['result'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lead created successfully in Odoo!")),
      );
    } else {
      throw Exception("Failed to create lead in Odoo: ${leadData['error'] ?? 'Unknown error'}");
    }
  } catch (e) {
    log("Error during lead creation: $e");  // Log error for debugging
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: $e")),
    );
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

  Future<void> _loadMessages() async {
    try {
      final propertyId = widget.property.id;
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('messages')
          .select('*')
          .eq('property_id', propertyId)
          .order('created_at', ascending: false);

      if (response != null && response is List<dynamic>) {
        final messages = response
            .map((message) {
              try {
                return Message.fromMap(message as Map<String, dynamic>);
              } catch (e) {
                return null;
              }
            })
            .whereType<Message>()
            .toList();

        if (mounted) {
          setState(() {
            _messages = messages;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading messages: $e')),
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final supabase = Supabase.instance.client;
      final messageContent = _messageController.text.trim();

      await supabase.from('messages').insert({
        'sender_id': singletonSession().userId,
        'rec_id': widget.property.userId,
        'property_id': widget.property.id,
        'content': messageContent,
        'created_at': DateTime.now().toIso8601String(),
      });

      _messageController.clear();
      await _loadMessages();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    } finally {
      setState(() => _isSending = false);
    }
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
    final isFavorite = ref.watch(favouritesProvider).any((p) => p.id == property.id);
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
                    Text(
                      property.type,
                    style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Price: \$${property.price}",
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.blueGrey[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                                      Navigator.pushNamed(context, '/favourites'); // Navigate to favorites page
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
                                      Navigator.pushNamed(context, '/favourites'); // Navigate to favorites page
                                    },
                                  ),
                                ),
                              );
                            }
                          },
                          icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: Colors.white),
                          label: Text(isFavorite ? "Remove from Favorites" : "Add to Favorites"),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white, backgroundColor: Colors.blueAccent,
                            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            _createLead(); // Ensure this method is defined in your class
                          },
                          icon: const Icon(Icons.phone, color: Colors.white),
                          label: const Text("Contact Seller"),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white, backgroundColor: Colors.blueAccent,
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
                          foregroundColor: Colors.white, backgroundColor: theme.colorScheme.primary,
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
                              feedback.user_id.toString() ?? "Anonymous",
                              style: TextStyle(fontWeight: FontWeight.bold),
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
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: Supabase.instance.client
                          .from('messages')
                          .stream(primaryKey: ['id'])
                          .eq('property_id', widget.property.id)
                          .order('created_at'),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(
                            child: Text(
                              'No messages yet. Start a conversation!',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        final messages = snapshot.data!;
                        return Container(
                          height: 300,
                          child: ListView.builder(
                            reverse: true,
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final isMe =
                                  message['sender_id'] == singletonSession().userId;

                              return Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 5, horizontal: 10),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isMe ? theme.colorScheme.primary : Colors.grey[300],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    message['content'],
                                    style: TextStyle(
                                        color:
                                            isMe ? Colors.white : Colors.black),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
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
                                icon: const Icon(Icons.send, color: Colors.blue),
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