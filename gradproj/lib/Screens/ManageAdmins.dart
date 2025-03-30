import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:gradproj/Controllers/admin_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../Models/Admin.dart';
import '../Models/propertyClass.dart';

class ManageAdminsScreen extends StatefulWidget {
  const ManageAdminsScreen({super.key});

  @override
  _ManageAdminsScreenState createState() => _ManageAdminsScreenState();
}

class _ManageAdminsScreenState extends State<ManageAdminsScreen> {
  bool _isLoading = false;
  List<AdminRecord> _admins = [];
  final AdminController _adminController = AdminController(Supabase.instance.client);


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
    final fetched = await _adminController.fetchAdmins();
    setState(() => _admins = fetched);

    if (fetched.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No admin records available')),
      );
    }
  } catch (e) {
    debugPrint('Error fetching admins: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to load admins: $e')),
    );
    setState(() => _admins = []);
  } finally {
    setState(() => _isLoading = false);
  }
}


 String generateSessionToken(String id) {
    return id;
  }
Future<void> _addAdmin(String email, String firstName, String lastName, String password) async {
  try {
    if (email.isEmpty || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid email address')));
      return;
    }
    if (firstName.isEmpty || lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name fields cannot be empty')));
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password too short')));
      return;
    }

    setState(() => _isLoading = true);

    await _adminController.addAdmin(email, firstName, lastName, password);
    await _fetchAdmins();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Admin added successfully!')),
    );
  } catch (e) {
    debugPrint('Error adding admin: $e');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
  } finally {
    setState(() => _isLoading = false);
  }
}


 Future<void> _updateAdmin(
    int id, String email, String firstName, String lastName, String password) async {
  try {
    if (firstName.isEmpty || lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name fields cannot be empty')),
      );
      return;
    }
    if (password.isNotEmpty && password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);

    await _adminController.updateAdmin(id, email, firstName, lastName, password);
    await _fetchAdmins();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Admin updated successfully!')),
    );
  } catch (e) {
    debugPrint('Error updating admin: $e');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
  } finally {
    setState(() => _isLoading = false);
  }
}


Future<void> _deleteAdmin(int id) async {
  Map<String, dynamic>? deletedAdmin;
  bool isUndoTriggered = false;

  try {
    setState(() => _isLoading = true);

    final adminToDelete = _admins.firstWhere((admin) => admin.id == id);
    deletedAdmin = await _adminController.deleteAdmin(adminToDelete);

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
              try {
                await _adminController.restoreAdmin(deletedAdmin!);
                await _fetchAdmins();

                isUndoTriggered = true;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Admin restored successfully!')),
                );
              } catch (e) {
                debugPrint('Error restoring admin: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error restoring admin: $e')),
                );
              }
            }
          },
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 5));

    if (!isUndoTriggered) {
      debugPrint('Undo was not triggered. Deletion finalized.');
    }
  } catch (e) {
    debugPrint('Error deleting admin: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
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
