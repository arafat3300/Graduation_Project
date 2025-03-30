import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../Models/Admin.dart';
import '../models/User.dart' as local;
import '../Models/propertyClass.dart';

class AdminController {
  final SupabaseClient supabase;
  final Uuid _uuid = const Uuid();

  AdminController(this.supabase);

  

  Future<bool> updatePropertyStatus(int propertyId, String newStatus) async {
    try {
      final response = await supabase
          .from('properties')
          .update({'status': newStatus})
          .eq('id', propertyId);

      return response == null; // Return true if update was successful
    } catch (e) {
      print("Error updating property status: $e");
      return false; // Return false if an error occurs
    }
  }
  

  Future<Map<String, int>> fetchDashboardCounts() async {
    try {
      final userResponse = await supabase
          .from('users')
          .select()
          .count(CountOption.exact);

      final propertyResponse = await supabase
          .from('properties')
          .select()
          .count(CountOption.exact);

      final adminResponse = await supabase
          .from('admins')
          .select()
          .count(CountOption.exact);

      final activeResponse = await supabase
          .from('properties')
          .select()
          .eq('status', "approved")
          .count(CountOption.exact);

      return {
        'users': userResponse.count ?? 0,
        'properties': propertyResponse.count ?? 0,
        'admins': adminResponse.count ?? 0,
        'activeProps': activeResponse.count ?? 0,
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
      final List response = await supabase
          .from('users')
          .select('*')
          .then((result) {
        return result is List ? List<Map<String, dynamic>>.from(result) : [];
      }).catchError((error) {
        debugPrint('Supabase query error: $error');
        return <Map<String, dynamic>>[];
      });

      return response.map((data) => local.User.fromJson(data)).toList();
    } catch (e) {
      debugPrint('Error fetching users: $e');
      return [];
    }
  }

  Future<Map<int, int>> fetchActiveListings(List<local.User> users) async {
    Map<int, int> listingMap = {};
    try {
      for (var user in users) {
        final response = await supabase
            .from('properties')
            .select('*')
            .eq('user_id', user.id as int)
            .eq('status', 'approved')
            .count(CountOption.exact);

        listingMap[user.id!] = response.count ?? 0;
      }
    } catch (e) {
      debugPrint('Error fetching active listings: $e');
    }
    return listingMap;
  }

  Future<Map<String, dynamic>> deleteUserById(int id, List<local.User> users) async {
    Map<String, dynamic>? deletedUser;
    try {
      final userToDelete = users.firstWhere((user) => user.id == id);
      deletedUser = {
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

      await supabase.from('users').delete().eq('id', id);
      return deletedUser;
    } catch (e) {
      debugPrint('Error deleting user: $e');
      rethrow;
    }
  }

  Future<void> restoreUser(Map<String, dynamic> userData) async {
    await supabase.from('users').insert(userData);
  }

String hashPassword(String password) {
    final bytes = utf8.encode(password.trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<List<AdminRecord>> fetchAdmins() async {
    final List response = await supabase
        .from('admins')
        .select('id, email, first_name, last_name, password, token')
        .then((result) => List<Map<String, dynamic>>.from(result))
        .catchError((error) {
          debugPrint('Supabase query error: $error');
          return <Map<String, dynamic>>[];
        });

    return response.map((adminData) {
      try {
        return AdminRecord.fromMap({
          'id': adminData['id'] ?? 0,
          'email': adminData['email'] ?? '',
          'first_name': adminData['first_name'] ?? '',
          'last_name': adminData['last_name'] ?? '',
          'password': adminData['password'] ?? '',
          'token': adminData['token'] ?? '',
        });
      } catch (e) {
        debugPrint('Error mapping admin record: $e');
        return null;
      }
    }).whereType<AdminRecord>().toList();
  }

  Future<void> addAdmin(String email, String firstName, String lastName, String password) async {
    final id = _uuid.v4();
    final hashedPassword = hashPassword(password);

    await supabase.from('admins').insert({
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'password': hashedPassword,
      'role': 1,
      'token': id,
      'idd': id,
    });
  }

  Future<void> updateAdmin(int id, String email, String firstName, String lastName, String password) async {
    await supabase.from('admins').update({
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'password': password,
    }).eq('id', id);
  }

  Future<Map<String, dynamic>> deleteAdmin(AdminRecord admin) async {
    final deleted = {
      'email': admin.email,
      'first_name': admin.first_name,
      'last_name': admin.last_name,
      'password': admin.password,
      'token': admin.token,
      'idd': admin.id,
    };

    await supabase.from('admins').delete().eq('id', admin.id);
    return deleted;
  }

  Future<void> restoreAdmin(Map<String, dynamic> adminData) async {
    await supabase.from('admins').insert(adminData);
  }

 Future<List<Property>> fetchApprovedProperties() async {
    final List response = await supabase
        .from('properties')
        .select('*')
        .eq('status', 'approved')
        .then((result) {
          return result is List ? List<Map<String, dynamic>>.from(result) : [];
        })
        .catchError((error) {
          print('Supabase query error: $error');
          return <Map<String, dynamic>>[];
        });

    return response.map((data) => Property.fromJson(data)).toList();
  }

  Future<void> deletePropertyById(int id) async {
    await supabase.from('properties').delete().eq('id', id);
  }

}