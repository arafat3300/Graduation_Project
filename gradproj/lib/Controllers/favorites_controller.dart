import 'package:flutter/cupertino.dart';
import 'package:postgres/postgres.dart';
import '../config/database_config.dart';
import '../Models/propertyClass.dart';

class FavoritesController {
  PostgreSQLConnection? _connection;
  bool _isConnected = false;

  FavoritesController() {
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

  Future<List<Property>> getUserFavorites(int userId) async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      final results = await _connection!.query(
        '''
        SELECT p.*
        FROM real_estate_property p
        JOIN real_estate_user_favorites f ON p.id = f.property_id
        WHERE f.user_id = @userId
        ''',
        substitutionValues: {'userId': userId},
      );
      return results.map((data) => Property.fromJson(data.toColumnMap())).toList();
    } catch (e) {
      debugPrint("Error getting user favorites: $e");
      return [];
    }
  }

  Future<bool> addToFavorites(int userId, int propertyId) async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      await _connection!.execute(
        '''
        INSERT INTO real_estate_user_favorites (
          user_id, property_id
        ) VALUES (
          @userId, @propertyId
        )
        ''',
        substitutionValues: {
          'userId': userId,
          'propertyId': propertyId,
        },
      );
      return true;
    } catch (e) {
      debugPrint("Error adding to favorites: $e");
      return false;
    }
  }

  Future<bool> removeFromFavorites(int userId, int propertyId) async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      await _connection!.execute(
        '''
        DELETE FROM real_estate_user_favorites
        WHERE user_id = @userId AND property_id = @propertyId
        ''',
        substitutionValues: {
          'userId': userId,
          'propertyId': propertyId,
        },
      );
      return true;
    } catch (e) {
      debugPrint("Error removing from favorites: $e");
      return false;
    }
  }

  Future<bool> isFavorite(int userId, int propertyId) async {
    
    try {
      if (!_isConnected) await _initializeConnection();
      
      final results = await _connection!.query(
        '''
        SELECT 1 FROM real_estate_user_favorites
        WHERE user_id = @userId AND property_id = @propertyId
        ''',
        substitutionValues: {
          'userId': userId,
          'propertyId': propertyId,
        },
      );
      return results.isNotEmpty;
    } catch (e) {
      debugPrint("Error checking favorite status: $e");
      return false;
    }
  }

  Future<void> dispose() async {
    if (_isConnected && _connection != null) {
      await _connection!.close();
      _isConnected = false;
      debugPrint('Disconnected from PostgreSQL database');
    }
  }
} 