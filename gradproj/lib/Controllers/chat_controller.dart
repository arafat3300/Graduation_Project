import 'package:flutter/cupertino.dart';
import 'package:postgres/postgres.dart';
import '../config/database_config.dart';
import '../Models/User.dart' as local;
import '../Models/singletonSession.dart';
import 'dart:async';

class ChatController {
  PostgreSQLConnection? _connection;
  bool _isConnected = false;
  Timer? _messageCheckTimer;
  final _messageController = StreamController<List<Map<String, dynamic>>>.broadcast();

  ChatController() {
    _initializeConnection();
  }

  Future<void> _initializeConnection() async {
    try {
      debugPrint('\nGetting shared database connection...');
      _connection = await DatabaseConfig.getConnection();
      _isConnected = true;
      print('Successfully connected to PostgreSQL database');
    } catch (e) {
      print('Error connecting to PostgreSQL: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchUserName(int userId) async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      final results = await _connection!.query(
        '''
        SELECT firstname, lastname 
        FROM users_users 
        WHERE id = @userId
        ''',
        substitutionValues: {'userId': userId},
      );

      if (results.isNotEmpty) {
        final userData = results.first.toColumnMap();
        return {
          'fullName': '${userData['firstname'] ?? 'Unknown'} ${userData['lastname'] ?? 'User'}'
        };
      }
    } catch (e) {
      throw Exception('Error fetching user name for ID $userId: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> loadChats(int userId) async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      final results = await _connection!.query(
        '''
        SELECT DISTINCT ON (property_id, sender_id, rec_id)
          property_id, sender_id, rec_id, content, created_at
        FROM real_estate_messages
        WHERE sender_id = @userId OR rec_id = @userId
        ORDER BY property_id, sender_id, rec_id, created_at DESC
        ''',
        substitutionValues: {'userId': userId},
      );

      return results.map((row) => row.toColumnMap()).toList();
    } catch (e) {
      debugPrint("Error loading chats: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(int propertyId) async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      final results = await _connection!.query(
        '''
        SELECT m.*, 
               s.firstname as sender_firstname, 
               s.lastname as sender_lastname,
               r.firstname as receiver_firstname,
               r.lastname as receiver_lastname
        FROM real_estate_messages m
        JOIN users_users s ON m.sender_id = s.id
        JOIN users_users r ON m.receiver_id = r.id
        WHERE m.property_id = @propertyId
        ORDER BY m.created_at ASC
        ''',
        substitutionValues: {'propertyId': propertyId},
      );
      return results.map((row) => row.toColumnMap()).toList();
    } catch (e) {
      debugPrint("Error getting messages: $e");
      return [];
    }
  }

  Future<void> sendMessage({
    required int senderId,
    required int receiverId,
    required int propertyId,
    required String content,
  }) async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      await _connection!.execute(
        '''
        INSERT INTO real_estate_messages (
          sender_id, rec_id, property_id, content, created_at
        ) VALUES (
          @senderId, @receiverId, @propertyId, @content, NOW()
        )
        ''',
        substitutionValues: {
          'senderId': senderId,
          'receiverId': receiverId,
          'propertyId': propertyId,
          'content': content,
        },
      );
    } catch (e) {
      debugPrint("Error sending message: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUserChats(int userId) async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      final results = await _connection!.query(
        '''
        SELECT DISTINCT p.*, 
               u.firstname, u.lastname,
               (SELECT content 
                FROM real_estate_messages 
                WHERE (sender_id = @userId OR receiver_id = @userId)
                AND property_id = p.id
                ORDER BY created_at DESC 
                LIMIT 1) as last_message,
               (SELECT created_at 
                FROM real_estate_messages 
                WHERE (sender_id = @userId OR receiver_id = @userId)
                AND property_id = p.id
                ORDER BY created_at DESC 
                LIMIT 1) as last_message_time
        FROM real_estate_property p
        JOIN users_users u ON p.user_id = u.id
        WHERE EXISTS (
          SELECT 1 FROM real_estate_messages m
          WHERE m.property_id = p.id
          AND (m.sender_id = @userId OR m.receiver_id = @userId)
        )
        ORDER BY last_message_time DESC
        ''',
        substitutionValues: {'userId': userId},
      );
      return results.map((row) => row.toColumnMap()).toList();
    } catch (e) {
      debugPrint("Error getting user chats: $e");
      return [];
    }
  }

  // Keep Supabase real-time subscription for new messages
  Stream<List<Map<String, dynamic>>> subscribeToMessages(int propertyId) {
    final controller = StreamController<List<Map<String, dynamic>>>();
    DateTime lastCheck = DateTime.now();

    _messageCheckTimer?.cancel();
    _messageCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        if (!_isConnected) await _initializeConnection();
        
        final results = await _connection!.query(
          '''
          SELECT m.*, 
                 s.firstname as sender_firstname, 
                 s.lastname as sender_lastname,
                 r.firstname as receiver_firstname,
                 r.lastname as receiver_lastname
          FROM real_estate_messages m
          JOIN users_users s ON m.sender_id = s.id
          JOIN users_users r ON m.receiver_id = r.id
          WHERE m.property_id = @propertyId
          AND m.created_at > @lastCheck
          ORDER BY m.created_at ASC
          ''',
          substitutionValues: {
            'propertyId': propertyId,
            'lastCheck': lastCheck.toIso8601String(),
          },
        );

        if (results.isNotEmpty) {
          final messages = results.map((row) => row.toColumnMap()).toList();
          controller.add(messages);
          lastCheck = DateTime.now();
        }
      } catch (e) {
        debugPrint("Error polling messages: $e");
      }
    });

    return controller.stream;
  }

  Future<void> dispose() async {
    _messageCheckTimer?.cancel();
    _messageController.close();
    if (_isConnected && _connection != null) {
      await _connection!.close();
      _isConnected = false;
      print('Disconnected from PostgreSQL database');
    }
  }
}
