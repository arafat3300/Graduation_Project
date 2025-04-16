import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../Models/Admin.dart';
import '../models/User.dart' as local;
import '../Models/propertyClass.dart';
import 'package:flutter/cupertino.dart';
import 'package:postgres/postgres.dart';
import '../config/database_config.dart';

class AdminController {
  final SupabaseClient supabase;
  final Uuid _uuid = const Uuid();
  PostgreSQLConnection? _connection;
  bool _isConnected = false;

  AdminController(this.supabase) {
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

  Future<bool> updatePropertyStatus(int propertyId, String newStatus) async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      await _connection!.execute(
        'UPDATE real_estate_property SET status = @status WHERE id = @propertyId',
        substitutionValues: {
          'status': newStatus,
          'propertyId': propertyId,
        },
      );
      return true;
    } catch (e) {
      print("Error updating property status: $e");
      return false;
    }
  }
  

  Future<Map<String, int>> fetchDashboardCounts() async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      final userCount = await _connection!.query(
        'SELECT COUNT(*) FROM users_users'
      );
      
      final propertyCount = await _connection!.query(
        'SELECT COUNT(*) FROM real_estate_property'
      );
      
      final adminCount = await _connection!.query(
        'SELECT COUNT(*) FROM real_estate_admins'
      );
      
      final activeCount = await _connection!.query(
        'SELECT COUNT(*) FROM real_estate_property WHERE status = @status',
        substitutionValues: {'status': 'approved'},
      );

      return {
        'users': userCount.first.first as int,
        'properties': propertyCount.first.first as int,
        'admins': adminCount.first.first as int,
        'activeProps': activeCount.first.first as int,
      };
    } catch (e) {
      print("Error fetching dashboard data: $e");
      return {
        'users': 0,
        'properties': 0,
        'admins': 0,
        'activeProps': 0,
      };
    }
  }


  Future<List<local.User>> fetchUsers() async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      final results = await _connection!.query('SELECT * FROM users_users');
      return results.map((data) => local.User.fromJson(data.toColumnMap())).toList();
    } catch (e) {
      debugPrint('Error fetching users: $e');
      return [];
    }
  }

  Future<Map<int, int>> fetchActiveListings(List<local.User> users) async {
    Map<int, int> listingMap = {};
    try {
      if (!_isConnected) await _initializeConnection();
      
      for (var user in users) {
        final results = await _connection!.query(
          '''
          SELECT COUNT(*) FROM real_estate_property 
          WHERE user_id = @userId AND status = @status
          ''',
          substitutionValues: {
            'userId': user.id,
            'status': 'approved',
          },
        );
        listingMap[user.id!] = results.first.first as int;
      }
    } catch (e) {
      debugPrint('Error fetching active listings: $e');
    }
    return listingMap;
  }

  Future<Map<String, dynamic>> deleteUserById(int id, List<local.User> users) async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      final userToDelete = users.firstWhere((user) => user.id == id);
      final deletedUser = {
        'id': userToDelete.id,
        'idd': userToDelete.idd,
        'firstname': userToDelete.firstName,
        'lastname': userToDelete.lastName,
        'dob': userToDelete.dob,
        'phone': userToDelete.phone,
        'country': userToDelete.country,
        'job': userToDelete.job,
        'email': userToDelete.email,
        'password': userToDelete.password,
        'token': userToDelete.token,
        'created_at': userToDelete.createdAt?.toIso8601String(),
        'role': userToDelete.role,
      };

      await _connection!.execute(
        'DELETE FROM users_users WHERE id = @id',
        substitutionValues: {'id': id},
      );
      return deletedUser;
    } catch (e) {
      debugPrint('Error deleting user: $e');
      rethrow;
    }
  }

  Future<void> restoreUser(Map<String, dynamic> userData) async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      await _connection!.execute(
        '''
        INSERT INTO users_users (
          id, idd, firstname, lastname, dob, phone, country,
          job, email, password, token, created_at, role
        ) VALUES (
          @id, @idd, @firstname, @lastname, @dob, @phone, @country,
          @job, @email, @password, @token, @createdAt, @role
        )
        ''',
        substitutionValues: userData,
      );
    } catch (e) {
      debugPrint('Error restoring user: $e');
      rethrow;
    }
  }

String hashPassword(String password) {
    final bytes = utf8.encode(password.trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<List<AdminRecord>> fetchAdmins() async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      final results = await _connection!.query(
        'SELECT id, email, first_name, last_name, password, token FROM real_estate_admins'
      );

      return results.map((data) {
        final adminData = data.toColumnMap();
        return AdminRecord(
          id: int.parse(adminData['id'].toString()),
          email: adminData['email'] as String,
          first_name: adminData['first_name'] as String,
          last_name: adminData['last_name'] as String,
          password: adminData['password'] as String,
          token: adminData['token'] as String,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching admins: $e');
      return [];
    }
  }

  Future<void> addAdmin(String email, String firstName, String lastName, String password) async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      final id = _uuid.v4();
      final hashedPassword = hashPassword(password);

      await _connection!.execute(
        '''
        INSERT INTO real_estate_admins (
          email, first_name, last_name, password, role, token, idd
        ) VALUES (
          @email, @firstName, @lastName, @password, @role, @token, @idd
        )
        ''',
        substitutionValues: {
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
          'password': hashedPassword,
          'role': 1,
          'token': id,
          'idd': id,
        },
      );
    } catch (e) {
      debugPrint('Error adding admin: $e');
      rethrow;
    }
  }

  Future<void> updateAdmin(int id, String email, String firstName, String lastName, String password) async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      await _connection!.execute(
        '''
        UPDATE real_estate_admins 
        SET email = @email,
            first_name = @firstName,
            last_name = @lastName,
            password = @password
        WHERE id = @id
        ''',
        substitutionValues: {
          'id': id,
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
          'password': password,
        },
      );
    } catch (e) {
      debugPrint('Error updating admin: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteAdmin(AdminRecord admin) async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      final deleted = {
        'email': admin.email,
        'first_name': admin.first_name,
        'last_name': admin.last_name,
        'password': admin.password,
        'token': admin.token,
        'idd': admin.id,
      };

      await _connection!.execute(
        'DELETE FROM real_estate_admins WHERE id = @id',
        substitutionValues: {'id': admin.id},
      );
      return deleted;
    } catch (e) {
      debugPrint('Error deleting admin: $e');
      rethrow;
    }
  }

  Future<void> restoreAdmin(Map<String, dynamic> adminData) async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      await _connection!.execute(
        '''
        INSERT INTO real_estate_admins (
          email, first_name, last_name, password, token, idd
        ) VALUES (
          @email, @firstName, @lastName, @password, @token, @idd
        )
        ''',
        substitutionValues: {
          'email': adminData['email'] as String,
          'firstName': adminData['first_name'] as String,
          'lastName': adminData['last_name'] as String,
          'password': adminData['password'] as String,
          'token': adminData['token'] as String,
          'idd': adminData['idd'] as String,
        },
      );
    } catch (e) {
      debugPrint('Error restoring admin: $e');
      rethrow;
    }
  }

 Future<List<Property>> fetchApprovedProperties() async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      final results = await _connection!.query(
        'SELECT * FROM real_estate_property WHERE status = @status',
        substitutionValues: {'status': 'approved'},
      );
      
      return results.map((data) => Property.fromJson(data.toColumnMap())).toList();
    } catch (e) {
      debugPrint('Error fetching approved properties: $e');
      return [];
    }
  }

  Future<void> deletePropertyById(int id) async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      await _connection!.execute(
        'DELETE FROM real_estate_property WHERE id = @id',
        substitutionValues: {'id': id},
      );
    } catch (e) {
      debugPrint('Error deleting property: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllAdmins() async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      final results = await _connection!.query(
        '''
        SELECT a.*, r.name as role_name
        FROM real_estate_admins a
        JOIN real_estate_roles r ON a.role_id = r.id
        '''
      );
      return results.map((data) => data.toColumnMap()).toList();
    } catch (e) {
      debugPrint("Error getting all admins: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>?> getAdminById(int id) async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      final results = await _connection!.query(
        '''
        SELECT a.*, r.name as role_name
        FROM real_estate_admins a
        JOIN real_estate_roles r ON a.role_id = r.id
        WHERE a.id = @id
        ''',
        substitutionValues: {'id': id},
      );
      return results.isNotEmpty ? results.first.toColumnMap() : null;
    } catch (e) {
      debugPrint("Error getting admin by id: $e");
      return null;
    }
  }

  Future<bool> createAdmin(Map<String, dynamic> adminData) async {
    try {
      if (!_isConnected) await _initializeConnection();
      
      await _connection!.execute(
        '''
        INSERT INTO real_estate_admins (
          name, email, password, role_id, created_at
        ) VALUES (
          @name, @email, @password, @roleId, NOW()
        )
        ''',
        substitutionValues: {
          'name': adminData['name'],
          'email': adminData['email'],
          'password': adminData['password'],
          'roleId': adminData['role_id'],
        },
      );
      return true;
    } catch (e) {
      debugPrint("Error creating admin: $e");
      return false;
    }
  }

  Future<void> dispose() async {
    if (_isConnected && _connection != null) {
      await _connection!.close();
      _isConnected = false;
      print('Disconnected from PostgreSQL database');
    }
  }
}
