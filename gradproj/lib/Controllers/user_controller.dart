import 'dart:convert';
import 'dart:async'; // Add this import for TimeoutException

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
        caseSensitive: false);
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
              : DateTime.now());
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
              : DateTime.now());
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
        final expiration =
            DateTime.fromMillisecondsSinceEpoch(jwt.payload['exp'] * 1000);
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

      return results
          .map((row) => Property.fromJson(row.toColumnMap()))
          .toList();
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
    const String apiUrl = 'http://10.0.2.2:8010/recommendations/';
    // const String apiUrl = 'http://$dbHost:8080/recommendations/';

    final Uri url = Uri.parse(apiUrl);

    try {
      // First check if user has favorites
      if (!_isConnected) await _initializeConnection();

      final favoritesResult = await _connection!.query(
        '''
        SELECT COUNT(*) as favorite_count 
        FROM real_estate_user_favorites 
        WHERE user_id = @userId
        ''',
        substitutionValues: {'userId': userId},
      );

      final favoriteCount = favoritesResult.first[0] as int;
      debugPrint("User $userId has $favoriteCount favorites");

      if (favoriteCount == 0) {
        debugPrint(
            "No favorites found for user $userId. Skipping content-based recommendations.");
        return [];
      }

      String host = DatabaseConfig.host;

      // Add timeout to the HTTP request
      final response = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'host': host}),
      )
          .timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint(
              "Content-based server request timed out. Falling back to database...");
          throw TimeoutException('Request timed out');
        },
      );

      if (response.statusCode == 200) {
        debugPrint("Successfully got response from content-based server");
        return await fetchContentBasedRecommendationsFromDB(userId);
      } else {
        debugPrint(
            "Content-based server returned status code: ${response.statusCode}. Falling back to database...");
        return await fetchContentBasedRecommendationsFromDB(userId);
      }
    } on TimeoutException {
      debugPrint(
          "Content-based server is not responding. Falling back to database...");
      return await fetchContentBasedRecommendationsFromDB(userId);
    } catch (e) {
      debugPrint(
          "Error in content-based server request: $e. Falling back to database...");
      return await fetchContentBasedRecommendationsFromDB(userId);
    }
  }

  Future<List<Map<String, dynamic>>> fetchContentBasedRecommendationsFromDB(
      int userId) async {
    try {
      if (!_isConnected) await _initializeConnection();

      debugPrint(
          "Fetching content-based recommendations from database for user: $userId");

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
        debugPrint(
            "No content-based recommendations found in database for user: $userId");
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

      final recommendations = detailsResult
          .map((row) => {
                "id": row[0],
                "similarity_score": row[1],
              })
          .toList();

      debugPrint(
          "Retrieved ${recommendations.length} recommendations from database");
      return recommendations;
    } catch (e) {
      debugPrint(
          "Error fetching content-based recommendations from database: $e");
      return [];
    }
  }

  Future<local.User?> getUserBySessionId(int userId) async {
    try {
      debugPrint("[getUserBySessionId] Starting...");

      if (!_isConnected) {
        debugPrint(
            "[getUserBySessionId] Not connected. Initializing connection...");
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

      debugPrint(
          "[getUserBySessionId] Query executed. Rows returned: ${results.length}");

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

      debugPrint(
          "[getUserBySessionId] User object created: ${user.firstName}, ${user.email}");
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

      debugPrint(
          "✅ Successfully parsed ${recommendations.length} raw recommendations");
      return recommendations;
    } catch (e) {
      debugPrint("❌ Error fetching raw AI recommendations: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchFeedbackBasedRecommendationsFromDB(
      int userId) async {
    try {
      if (!_isConnected) await _initializeConnection();

      debugPrint(
          "🔍 Checking for feedback-based recommendations for user: $userId");

      // First, let's check what recommendation types exist for this user
      final allRecommendationsResult = await _connection!.query(
        '''
        SELECT id, recommendation_type, created_at 
        FROM real_estate_recommendedproperties 
        WHERE user_id = @userId 
        ORDER BY created_at DESC
        ''',
        substitutionValues: {'userId': userId},
      );

      debugPrint("📊 All recommendations for user $userId:");
      for (var row in allRecommendationsResult) {
        debugPrint("  - ID: ${row[0]}, Type: '${row[1]}', Created: ${row[2]}");
      }

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
        debugPrint(
            "❌ No feedback-based recommendations found in database for user: $userId");
        debugPrint("💡 This could mean:");
        debugPrint("   1. User hasn't submitted any feedback yet");
        debugPrint("   2. Feedback service isn't saving recommendations");
        debugPrint("   3. Recommendation_type is not 'feedback'");
        return [];
      }

      final recommendationId = recommendationResult.first[0];
      debugPrint("✅ Found feedback recommendation ID: $recommendationId");

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

      final recommendations = detailsResult
          .map((row) => {
                "id": row[0],
                "similarity_score": row[1],
              })
          .toList();

      debugPrint(
          "✅ Retrieved ${recommendations.length} feedback-based recommendations");
      return recommendations;
    } catch (e) {
      debugPrint(
          "❌ Error fetching feedback-based recommendations from database: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>?> getUserClusterInfo(int userId) async {
    try {
      if (!_isConnected) await _initializeConnection();

      // First, check if cluster info already exists in database
      debugPrint("Fetching cluster info from database for user: $userId");
      final results = await _connection!.query(
        '''
        SELECT u.cluster_id, c.message 
        FROM users_users u
        LEFT JOIN real_estate_clusters c ON u.cluster_id = c.cluster_id
        WHERE u.id = @userId
        ''',
        substitutionValues: {'userId': userId},
      );

      if (results.isNotEmpty) {
        final row = results.first;
        final clusterInfo = {
          'cluster_id': row[0],
          'message': row[1],
        };
        debugPrint("Found existing cluster info: $clusterInfo");
        return clusterInfo;
      }

      // If no cluster info exists, trigger the segmentation service
      debugPrint("No cluster info found, triggering segmentation service");
      String dbHost = DatabaseConfig.host;
      try {
        final response = await http
            .post(
              Uri.parse('http://10.0.2.2:8012/property-segmentation/'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'user_id': userId,
                'host': dbHost,
                'limit': 10,
                'find_optimal_clusters': false
              }),
            )
            .timeout(const Duration(seconds: 25));

        debugPrint(
            "Segmentation service response status: ${response.statusCode}");

        if (response.statusCode == 200) {
          debugPrint('Successfully triggered segmentation service');
          // Return a status indicating the process is running
          return {
            'status': 'processing',
            'message':
                'User segmentation is being processed. Please check back later.',
            'cluster_id': null,
          };
        } else {
          debugPrint(
              'Segmentation service returned error: ${response.statusCode}');
          return {
            'status': 'error',
            'message': 'Failed to start user segmentation process.',
            'cluster_id': null,
          };
        }
      } catch (e) {
        debugPrint('HTTP request failed or timed out: $e');
        return {
          'status': 'error',
          'message': 'Unable to connect to segmentation service.',
          'cluster_id': null,
        };
      }
    } catch (e) {
      debugPrint("Error in getUserClusterInfo: $e");
      return {
        'status': 'error',
        'message': 'An error occurred while fetching cluster information.',
        'cluster_id': null,
      };
    }
  }

  // Add a method to poll for cluster info updates
  Future<Map<String, dynamic>?> pollForClusterInfo(int userId,
      {int maxAttempts = 5}) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      debugPrint("Polling attempt $attempt for user $userId");

      final clusterInfo = await getUserClusterInfo(userId);

      if (clusterInfo != null && clusterInfo['cluster_id'] != null) {
        debugPrint("Cluster info found on attempt $attempt");
        return clusterInfo;
      }

      if (attempt < maxAttempts) {
        debugPrint("Waiting 10 seconds before next attempt...");
        await Future.delayed(const Duration(seconds: 10));
      }
    }

    debugPrint("No cluster info found after $maxAttempts attempts");
    return {
      'status': 'timeout',
      'message':
          'User segmentation is still processing. Please try again later.',
      'cluster_id': null,
    };
  }
}
