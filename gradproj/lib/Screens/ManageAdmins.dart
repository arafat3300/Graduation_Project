import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/Admin.dart';

class ManageAdminsScreen extends StatefulWidget {
  const ManageAdminsScreen({super.key});

  @override
  _ManageAdminsScreenState createState() => _ManageAdminsScreenState();
}

class _ManageAdminsScreenState extends State<ManageAdminsScreen> {
  bool _isLoading = false;
  List<AdminRecord> _admins = [];

  @override
  void initState() {
    super.initState();
    _fetchAdmins();
  }

   Future<void> _saveSession(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }


Future<void> _fetchAdmins() async {
  setState(() => _isLoading = true);

  try {
    final supabase = Supabase.instance.client;

    final List response = await supabase
        .from('admins')
        .select('id, email, first_name, last_name, password')
        .then((result) {
      return result is List ? List<Map<String, dynamic>>.from(result) : [];
    }).catchError((error) {
      debugPrint('Supabase query error: $error');
      return <Map<String, dynamic>>[];
    });

    if (response.isEmpty) {
      debugPrint('No admin records found');
      setState(() {
        _admins = []; 
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No admin records available')),
      );
      return;
    }

    final List<AdminRecord> processedAdmins = response.map((adminData) {
      try {
        return AdminRecord.fromMap({
          'id': adminData['id'] ?? 0,
          'email': adminData['email'] ?? '',
          'first_name': adminData['first_name'] ?? '',
          'last_name': adminData['last_name'] ?? '',
          'password': adminData['password'] ?? '',
          'token': adminData['token'] ?? '', 
        });
      } catch (mappingError) {
        debugPrint('Error mapping admin record: $mappingError');
        return null;
      }
    }).whereType<AdminRecord>().toList(); 

    setState(() {
      _admins = processedAdmins;
    });

    debugPrint('Successfully fetched ${processedAdmins.length} admin records');

  } catch (generalError) {
    debugPrint('Unexpected error in admin fetching: $generalError');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to load admin records: $generalError')),
    );

    setState(() {
      _admins = [];
    });
  } finally {
    setState(() => _isLoading = false);
  }
}

 String generateSessionToken(String id) {
    return id;
  }
  Future<void> _addAdmin(
    String email, String firstName, String lastName, String password) async {
  try {
    setState(() => _isLoading = true);
    final Uuid _uuid = const Uuid();

    String hashPassword(String password) {
      final bytes = utf8.encode(password.trim());
      final digest = sha256.convert(bytes);
      return digest.toString();
    }

    final hashedPassword = hashPassword(password);

    final supabase = Supabase.instance.client;
    final id = _uuid.v4();
    final sessionToken = generateSessionToken(id); 

    await supabase.from('admins').insert({
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'password': hashedPassword, 
      'role': 1, 
      'token': sessionToken,
      'idd': id,
    });

    await _fetchAdmins();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Admin added successfully!')),
    );
  } catch (e) {
    debugPrint('Exception in _addAdmin(): $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exception: $e')),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}

  Future<void> _updateAdmin(
      int id, String newEmail, String newFirstName, String newLastName, String newPassword) async {
    try {
      setState(() => _isLoading = true);

      final supabase = Supabase.instance.client;
      await supabase.from('admins').update({
        'email': newEmail,
        'first_name': newFirstName,
        'last_name': newLastName,
        'password': newPassword,
      }).eq('id', id);

      await _fetchAdmins();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin updated successfully!')),
      );
    } catch (e) {
      debugPrint('Exception in _updateAdmin(): $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exception: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAdmin(int id) async {
    Map<String, dynamic>? deletedAdmin;
    try {
      setState(() => _isLoading = true);

      final supabase = Supabase.instance.client;
      final adminToDelete = _admins.firstWhere((admin) => admin.id == id);
      deletedAdmin = {
      'email': adminToDelete.email,
      'first_name': adminToDelete.firstName,
      'last_name': adminToDelete.lastName,
      'password': adminToDelete.password,
      'token': adminToDelete.token,
      'idd': adminToDelete.id,
      };

      await supabase.from('admins').delete().eq('id', id);
      setState(() {
        _admins.removeWhere((admin) => admin.id == id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Admin deleted successfully!'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            if (deletedAdmin != null) {
              await supabase.from('admins').insert(deletedAdmin);
              await _fetchAdmins();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Admin restored successfully!')),
              );
            }
          },
        ),
      ),
    );
    } catch (e) {
      debugPrint('Exception in _deleteAdmin(): $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exception: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddAdminDialog() {
    final emailController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Admin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: firstNameController, decoration: const InputDecoration(labelText: 'First Name')),
              TextField(controller: lastNameController, decoration: const InputDecoration(labelText: 'Last Name')),
              TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Password')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _addAdmin(emailController.text.trim(), firstNameController.text.trim(),
                    lastNameController.text.trim(), passwordController.text.trim());
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditAdminDialog(AdminRecord admin) {
    final emailController = TextEditingController(text: admin.email);
    final firstNameController = TextEditingController(text: admin.first_name);
    final lastNameController = TextEditingController(text: admin.last_name);
    final passwordController = TextEditingController(text: admin.password);

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Admin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: firstNameController, decoration: const InputDecoration(labelText: 'First Name')),
              TextField(controller: lastNameController, decoration: const InputDecoration(labelText: 'Last Name')),
              TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Password')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _updateAdmin(
                  admin.id,
                  emailController.text.trim(),
                  firstNameController.text.trim(),
                  lastNameController.text.trim(),
                  passwordController.text.trim(),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Admins'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAdmins,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAdminDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _admins.isEmpty
              ? const Center(child: Text('No admins found.'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('First Name')),
                      DataColumn(label: Text('Last Name')),
                      DataColumn(label: Text('Password')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _admins.map((admin) {
                      return DataRow(
                        cells: [
                          DataCell(Text('${admin.id}')),
                          DataCell(Text(admin.email)),
                          DataCell(Text(admin.first_name)),
                          DataCell(Text(admin.last_name)),
                          DataCell(Text(admin.password)),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _showEditAdminDialog(admin),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteAdmin(admin.id),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
    );
  }
}
