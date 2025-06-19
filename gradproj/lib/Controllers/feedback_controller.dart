import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';
import 'package:http/http.dart' as http;
import '../Models/Feedback.dart';
import '../config/database_config.dart';

class FeedbackController {
  PostgreSQLConnection? _connection;
  bool _isConnected = false;
  static const String fastApiUrl = 'http://10.0.2.2:8000/predict';

  FeedbackController() {
    _initializeConnection();
  }

  Future<void> _initializeConnection() async {
    try {
      debugPrint('\nGetting shared database connection...');
      _connection = await DatabaseConfig.getConnection();
      _isConnected = true;
      debugPrint('Successfully connected to PostgreSQL database');
    } catch (e) {
      debugPrint('Error connecting to PostgreSQL: $e');
      _isConnected = false;
    }
  }

 Future<List<propertyFeedbacks>> getFeedbacksByProperty(int propertyId) async {
  try {
    if (!_isConnected) await _initializeConnection();
    
    final results = await _connection!.query(
      'SELECT * FROM real_estate_feedback WHERE property_id = @propertyId ORDER BY created_at DESC',
      substitutionValues: {'propertyId': propertyId},
    );

    return results.map((row) {
      final data = row.toColumnMap();

      return propertyFeedbacks(
        id: data['id'] is int ? data['id'] : int.tryParse(data['id']?.toString() ?? ''),
        property_id: data['property_id'] is int
            ? data['property_id']
            : int.tryParse(data['property_id']?.toString() ?? '') ?? 0,
        feedback: data['feedback']?.toString() ?? '',
        user_id: data['user_id'] is int
            ? data['user_id']
            : int.tryParse(data['user_id']?.toString() ?? ''),
      );
    }).toList();
  } catch (e) {
    debugPrint("Error fetching feedbacks: $e");
    return [];
  }
}


  Future<void> addFeedback(int propertyId, String feedbackText, int? userId) async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      // First, add to database
      await _connection!.execute(
        '''
        INSERT INTO real_estate_feedback (property_id, user_id, feedback, created_at)
        VALUES (@propertyId, @userId, @feedbackText, NOW())
        ''',
        substitutionValues: {
          'propertyId': propertyId,
          'userId': userId,
          'feedbackText': feedbackText,
        },
      );
      debugPrint("Feedback added to database: propertyId=$propertyId, userId=$userId, feedbackText=$feedbackText");

      // Then, send to FastAPI
      final response = await http.post(
        Uri.parse(fastApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'review': feedbackText,
          'property_id': propertyId,
          'user_id': userId?.toString() ?? 'anonymous',
          'review_number': 1, // Default to 1 for new reviews
        }),
      );

      if (response.statusCode != 200) {
        debugPrint("Warning: Failed to send feedback to AI pipeline: ${response.body}");
      } else {
        debugPrint("Feedback sent to AI pipeline successfully");
      }
    } catch (e) {
      debugPrint("Error in addFeedback: $e");
      rethrow;
    }
  }
Future<List<propertyFeedbacks>> getAllFeedbacks() async {
  try {
    if (!_isConnected) await _initializeConnection();
    
    final results = await _connection!.query(
      'SELECT * FROM real_estate_feedback ORDER BY created_at ASC',
    );

    return results.map((row) {
      final data = row.toColumnMap();

      return propertyFeedbacks(
        id: data['id'] is int ? data['id'] : int.tryParse(data['id']?.toString() ?? ''),
        property_id: data['property_id'] is int
            ? data['property_id']
            : int.tryParse(data['property_id']?.toString() ?? '') ?? 0,
        feedback: data['feedback']?.toString() ?? '',
        user_id: data['user_id'] is int
            ? data['user_id']
            : int.tryParse(data['user_id']?.toString() ?? ''),
      );
    }).toList();
  } catch (e) {
    debugPrint("Error fetching all feedbacks: $e");
    return [];
  }
}




Future<Map<String, dynamic>?> fetchUserInfo(int userId) async {
  try {
    if (!_isConnected) await _initializeConnection();

    final results = await _connection!.query(
      '''
      SELECT firstname, lastname, email 
      FROM users_users 
      WHERE id = @userId
      ''',
      substitutionValues: {'userId': userId},
    );

    if (results.isNotEmpty) {
      final data = results.first.toColumnMap();
      return {
        'fullName': '${data['firstname']} ${data['lastname']}',
        'email': data['email'],
      };
    }
  } catch (e) {
    debugPrint('Error fetching user info for ID $userId: $e');
  }
  return null;
}

}