import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/Admin.dart';

class ManageAdminsScreen extends StatefulWidget {
  const ManageAdminsScreen({Key? key}) : super(key: key);

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

  Future<void> _fetchAdmins() async {
    try {
      setState(() => _isLoading = true);
      final supabase = Supabase.instance.client;

  final response = await supabase
      .from('admins')
      .select('id, email, first_name, last_name, password');

  if (response != null && response is List<dynamic>) {
    final admins = response.map((map) => AdminRecord.fromMap(map as Map<String, dynamic>)).toList();
    setState(() {
      _admins = admins;
    });
  } else {
    throw Exception('Unexpected response format.');
  }
} catch (error) {
  debugPrint('Error fetching admins: $error');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error fetching admins: $error')),
  );
}finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addAdmin(String email, String firstName, String lastName, String password) async {
    try {
      setState(() => _isLoading = true);

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('admins')
          .insert({
            'email': email,
            'first_name': firstName,
            'last_name': lastName,
            'password': password,
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
      final response = await supabase
          .from('admins')
          .update({
            'email': newEmail,
            'first_name': newFirstName,
            'last_name': newLastName,
            'password': newPassword,
          })
          .eq('id', id);


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
    try {
      setState(() => _isLoading = true);

      final supabase = Supabase.instance.client;
      final response = await supabase.from('admins').delete().eq('id', id);


      setState(() {
        _admins.removeWhere((admin) => admin.id == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin deleted successfully!')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Admins'), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchAdmins)]),
      floatingActionButton: FloatingActionButton(onPressed: _showAddAdminDialog, child: const Icon(Icons.add)),
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
                                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _deleteAdmin(admin.id)),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteAdmin(admin.id)),
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
