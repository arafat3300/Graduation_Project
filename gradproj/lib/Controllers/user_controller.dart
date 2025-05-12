import 'dart:convert';
import 'dart:async';  // Add this import for TimeoutException

import 'package:flutter/material.dart';
import 'package:gradproj/Models/singletonSession.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradproj/Models/User.dart' as local;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../Models/propertyClass.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:postgres/postgres.dart';
import '../config/database_config.dart';
import 'package:crypto/crypto.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class UserController {
  final Uuid _uuid = const Uuid();
  PostgreSQLConnection? _connection;
  bool _isConnected = false;
  
  static const String tokenKey = 'token';
  static const String _jwtSecret = 'samirencryption';

  UserController() {
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
    }
  }
  

  bool _isUUID(String token) {
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false
    );
    return uuidPattern.hasMatch(token);
  }

  Future<void> saveSessionToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(tokenKey, token);
      debugPrint("Token saved successfully");
    } catch (e) {
      debugPrint("Error saving token: $e");
      rethrow;
    }
  }

  Future<String?> getSessionToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(tokenKey);
      if (token == null) {
        debugPrint("No token found in SharedPreferences");
      }
      return token;
    } catch (e) {
      debugPrint("Error retrieving token: $e");
      return null;
    }
  }

  Future<local.User?> getUserById(String userId) async {

    try {
      if (!_isConnected) await _initializeConnection();
      
      final results = await _connection!.query(
        '''
        SELECT * FROM users_users 
        WHERE idd = @userId
        ''',
        substitutionValues: {'userId': userId},
      );

      if (results.isEmpty) {
        debugPrint("No user found with ID: $userId");
        return null;
      }

      final userData = results.first.toColumnMap();
      return local.User(
        idd: userData['idd']?.toString(),
        firstName: userData['firstname'] ?? '',
        lastName: userData['lastname'] ?? '',
        dob: userData['dob'] ?? '',
        phone: userData['phone'] ?? '',
        country: userData['country'] ?? '',
        job: userData['job'] ?? '',
        email: userData['email'] ?? '',
        password: '', // Never retrieve password
        token: '', // No token needed for ID-based lookup
        role: userData['role'] ?? '2',
        createdAt: userData['created_at'] != null 
            ? DateTime.parse(userData['created_at'].toString())
            : DateTime.now()
      );
    } catch (e) {
      debugPrint("Error fetching user by ID: $e");
      return null;
    }
  }

  Future<local.User?> getUserByToken(String token) async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      final results = await _connection!.query(
        '''
        SELECT * FROM users_users 
        WHERE ${_isUUID(token) ? 'token' : 'idd'} = @value
        ''',
        substitutionValues: {
          'value': _isUUID(token) ? token : _getUserIdFromJwt(token)
        },
      );

      if (results.isEmpty) {
        debugPrint("No user found with provided token");
        return null;
      }

      final userData = results.first.toColumnMap();
      return local.User(
        idd: userData['idd']?.toString(),
        id: userData['id'] as int,
        firstName: userData['firstname'] ?? '',
        lastName: userData['lastname'] ?? '',
        dob: userData['dob'] ?? '',
        phone: userData['phone'] ?? '',
        country: userData['country'] ?? '',
        job: userData['job'] ?? '',
        email: userData['email'] ?? '',
        password: '', // Never retrieve password
        token: token,
        role: userData['role'] ?? '2',
        createdAt: userData['created_at'] != null 
            ? DateTime.parse(userData['created_at'].toString())
            : DateTime.now()
      );
    } catch (e) {
      debugPrint("Error fetching user: $e");
      return null;
    }
  }

  String? _getUserIdFromJwt(String token) {
    try {
      if (_isUUID(token)) return null;
      final jwt = JWT.verify(token, SecretKey(_jwtSecret));
      return jwt.payload['sub'] as String?;
    } catch (e) {
      debugPrint("Error extracting user ID from JWT: $e");
      return null;
    }
  }
  

  bool isTokenValid(String token) {
    if (_isUUID(token)) {
      return true; 
    }
    
    try {
      final jwt = JWT.verify(token, SecretKey(_jwtSecret));
      if (jwt.payload.containsKey('exp')) {
        final expiration = DateTime.fromMillisecondsSinceEpoch(jwt.payload['exp'] * 1000);
        return DateTime.now().isBefore(expiration);
      }
      return false;
    } catch (e) {
      debugPrint("Token verification failed: $e");
      return false;
    }
  }

  Future<local.User?> getLoggedInUser() async {
    try {
      final token = await getSessionToken();
      if (token == null) {
        debugPrint("No session token found");
        return null;
      }

      if (!isTokenValid(token)) {
        debugPrint("Token is invalid or expired");
        await clearSessionToken();
        return null;
      }

      final user = await getUserByToken(token);
      if (user == null) {
        debugPrint("Failed to retrieve user details. Redirecting to login.");
      }
      return user;
    } catch (e) {
      debugPrint("Error fetching logged-in user: $e");
      return null;
    }
  }

  Future<String?> getLoggedInUserEmail() async {
    final user = await getLoggedInUser();
    return user?.email;
  }

  Future<String?> getLoggedInUserName() async {
    final user = await getLoggedInUser();
    if (user == null) return null;
    return '${user.firstName} ${user.lastName}'.trim();
  }

  Future<String?> getLoggedInUserNumber() async {
    final user = await getLoggedInUser();
    return user?.phone;
  }

  Future<int?> getLoggedInUserIndexId() async {
    final user = await getLoggedInUser();
    return user?.id;
  }

  Future<void> clearSessionToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(tokenKey);
      debugPrint("Token cleared successfully");
    } catch (e) {
      debugPrint("Error clearing token: $e");
      rethrow;
    }
  }

  Future<bool> isUserLoggedIn() async {
    try {
      final token = await getSessionToken();
      if (token == null) return false;
      
      if (!isTokenValid(token)) {
        await clearSessionToken();
        return false;
      }

      final user = await getUserByToken(token);
      return user != null;
    } catch (e) {
      debugPrint("Error checking login status: $e");
      return false;
    }
  }

  Future<List<Property>> fetchUserPropertiesBySession() async {
    try {
      final userId = singletonSession().userId;
      if (userId == null) {
        debugPrint("User ID is null");
        return [];
      }

      if (!_isConnected) await _initializeConnection();
      
      final results = await _connection!.query(
        '''
        SELECT * FROM real_estate_property
        WHERE user_id = @userId
        ''',
        substitutionValues: {'userId': userId},
      );

      return results.map((row) => Property.fromJson(row.toColumnMap())).toList();
    } catch (e) {
      debugPrint("Exception fetching user listings: $e");
      return [];
    }
  }

  Future<void> dispose() async {
    if (_isConnected && _connection != null) {
      await _connection!.close();
      _isConnected = false;
      debugPrint('Disconnected from PostgreSQL database');
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecommendationsRaw(int userId) async {
    const String dbHost = DatabaseConfig.host;
    const String apiUrl = 'http://$dbHost:8080/recommendations/';
    final Uri url = Uri.parse(apiUrl);

    try {
      String host = DatabaseConfig.host;

      // Add timeout to the HTTP request
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'host': host}),
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint("Content-based server request timed out. Falling back to database...");
          throw TimeoutException('Request timed out');
        },
      );

      if (response.statusCode == 200) {
        debugPrint("Successfully got response from content-based server");
        return await fetchContentBasedRecommendationsFromDB(userId);
      } else {
        debugPrint("Content-based server returned status code: ${response.statusCode}. Falling back to database...");
        return await fetchContentBasedRecommendationsFromDB(userId);
      }
    } on TimeoutException {
      debugPrint("Content-based server is not responding. Falling back to database...");
      return await fetchContentBasedRecommendationsFromDB(userId);
    } catch (e) {
      debugPrint("Error in content-based server request: $e. Falling back to database...");
      return await fetchContentBasedRecommendationsFromDB(userId);
    }
  }

  Future<List<Map<String, dynamic>>> fetchContentBasedRecommendationsFromDB(int userId) async {
    try {
      if (!_isConnected) await _initializeConnection();

      debugPrint("Fetching content-based recommendations from database for user: $userId");

      // First get the latest content-based recommendation record for the user
      final recommendationResult = await _connection!.query(
        '''
        SELECT id FROM real_estate_recommendedproperties 
        WHERE user_id = @userId 
        AND recommendation_type = 'interactions'
        ORDER BY created_at DESC 
        LIMIT 1
        ''',
        substitutionValues: {'userId': userId},
      );

      if (recommendationResult.isEmpty) {
        debugPrint("No content-based recommendations found in database for user: $userId");
        return [];
      }

      final recommendationId = recommendationResult.first[0];
      debugPrint("Found recommendation ID: $recommendationId");

      // Then get the property details with scores
      final detailsResult = await _connection!.query(
        '''
        SELECT property_id, score 
        FROM real_estate_recommendedpropertiesdetails 
        WHERE recommendation_id = @recommendationId 
        ORDER BY score DESC
        ''',
        substitutionValues: {'recommendationId': recommendationId},
      );

      final recommendations = detailsResult.map((row) => {
        "id": row[0],
        "similarity_score": row[1],
      }).toList();

      debugPrint("Retrieved ${recommendations.length} recommendations from database");
      return recommendations;
    } catch (e) {
      debugPrint("Error fetching content-based recommendations from database: $e");
      return [];
    }
  }

  Future<local.User?> getUserBySessionId(int userId) async {
    try {
      debugPrint("[getUserBySessionId] Starting...");

      if (!_isConnected) {
        debugPrint("[getUserBySessionId] Not connected. Initializing connection...");
        await _initializeConnection();
      }

      debugPrint("[getUserBySessionId] Session userId passed: $userId");

      final results = await _connection!.query(
        '''
        SELECT * FROM users_users 
        WHERE id = @value
        ''',
        substitutionValues: {
          'value': userId,
        },
      );

      debugPrint("[getUserBySessionId] Query executed. Rows returned: ${results.length}");

      if (results.isEmpty) {
        debugPrint("[getUserBySessionId] No user found with id: $userId");
        return null;
      }

      final userData = results.first.toColumnMap();
      debugPrint("[getUserBySessionId] User data received:");

      // Safely handle created_at
      final createdAtRaw = userData['created_at'];
      final createdAt = (createdAtRaw is DateTime)
          ? createdAtRaw
          : (createdAtRaw is String)
              ? DateTime.tryParse(createdAtRaw) ?? DateTime.now()
              : DateTime.now();
      debugPrint("[getUserBySessionId] Parsed createdAt: $createdAt");

      // Safely handle dob
      final dobRaw = userData['dob'];
      final dob = (dobRaw is DateTime)
          ? dobRaw.toIso8601String()
          : (dobRaw is String)
              ? dobRaw
              : '';
      debugPrint("[getUserBySessionId] Parsed dob: $dob");

      final user = local.User(
        idd: userData['idd']?.toString(),
        id: userData['id'] as int,
        firstName: userData['firstname'] ?? '',
        lastName: userData['lastname'] ?? '',
        dob: dob,
        phone: userData['phone'] ?? '',
        country: userData['country'] ?? '',
        job: userData['job'] ?? '',
        email: userData['email'] ?? '',
        password: '', // Never retrieve password
        token: '', // Not needed here
        role: userData['role'] is int
      ? userData['role']
      : int.tryParse(userData['role'].toString()) ?? 2,

        createdAt: createdAt,
      );

      debugPrint("[getUserBySessionId] User object created: ${user.firstName}, ${user.email}");
      return user;
    } catch (e) {
      debugPrint("[getUserBySessionId] Error: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> fetchCachedAIRecommendationsRaw() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawData = prefs.getString('ai_recommendations_raw');
      debugPrint("📦 Raw recommendations data: $rawData");

      if (rawData == null || rawData.isEmpty) {
        debugPrint("⚠️ No raw recommendations found");
        return null;
      }

      // Check if the data is a simple string (like "No recommendations found.")
      if (rawData.startsWith('"') && rawData.endsWith('"')) {
        debugPrint("⚠️ Raw data is a simple string, not a JSON object");
        return null;
      }

      final dynamic decodedData = jsonDecode(rawData);
      debugPrint("🔍 Decoded raw data type: ${decodedData.runtimeType}");
      
      List<Map<String, dynamic>> recommendations = [];
      
      if (decodedData is List) {
        for (var item in decodedData) {
          if (item is Map<String, dynamic>) {
            recommendations.add(item);
          }
        }
      } else if (decodedData is Map<String, dynamic>) {
        // Handle case where it's a single recommendation
        recommendations.add(decodedData);
      }
      
      debugPrint("✅ Successfully parsed ${recommendations.length} raw recommendations");
      return recommendations;
    } catch (e) {
      debugPrint("❌ Error fetching raw AI recommendations: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchFeedbackBasedRecommendationsFromDB(int userId) async {
    try {
      if (!_isConnected) await _initializeConnection();

      // Get the latest feedback-based recommendation record for the user
      final recommendationResult = await _connection!.query(
        '''
        SELECT id FROM real_estate_recommendedproperties 
        WHERE user_id = @userId 
        AND recommendation_type = 'feedback'
        ORDER BY created_at DESC 
        LIMIT 1
        ''',
        substitutionValues: {'userId': userId},
      );

      if (recommendationResult.isEmpty) {
        debugPrint("No feedback-based recommendations found in database for user: $userId");
        return [];
      }

      final recommendationId = recommendationResult.first[0];

      // Get the property details with scores
      final detailsResult = await _connection!.query(
        '''
        SELECT property_id, score 
        FROM real_estate_recommendedpropertiesdetails 
        WHERE recommendation_id = @recommendationId 
        ORDER BY score DESC
        ''',
        substitutionValues: {'recommendationId': recommendationId},
      );

      return detailsResult.map((row) => {
        "id": row[0],
        "similarity_score": row[1],
      }).toList();
    } catch (e) {
      debugPrint("Error fetching feedback-based recommendations from database: $e");
      return [];
    }
  }
}