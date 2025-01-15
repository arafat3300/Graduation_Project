import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/User.dart' as local; // Alias your custom User class

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({Key? key}) : super(key: key);

  @override
  _ManageUsersScreenState createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  bool _isLoading = false;
  List<local.User> _users = []; // Use the aliased User class
  Map<int, int> _activeListings = {}; // Map to store user ID and active listings count

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final List response = await supabase
          .from('users')
          .select('*')
          .then((result) {
        return result is List ? List<Map<String, dynamic>>.from(result) : [];
      }).catchError((error) {
        debugPrint('Supabase query error: $error');
        return <Map<String, dynamic>>[];
      });

      if (response.isNotEmpty) {
        final users = response.map((data) => local.User.fromJson(data)).toList();
        setState(() {
          _users = users;
        });
        await _fetchActiveListings(users);
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchActiveListings(List<local.User> users) async {
    try {
      final supabase = Supabase.instance.client;

      // Iterate through users to fetch the count of their active properties
      for (var user in users) {
        final response = await supabase
            .from('properties')
            .select('*')
            .eq('user_id', user.id as int)
            .eq('status', 'approved')
            .count(CountOption.exact);

        // Update the active listings count for each user
        setState(() {
          _activeListings[user.id!] = response.count ?? 0; // Use count from response
        });
      }
    } catch (e) {
      debugPrint('Error fetching active listings: $e');
    }
  }

  Future<void> _deleteUser(int id) async {
    try {
      setState(() => _isLoading = true);

      final supabase = Supabase.instance.client;
      await supabase.from('users').delete().eq('id', id);

      setState(() {
        _users.removeWhere((user) => user.id == id);
        _activeListings.remove(id); // Remove associated active listing count
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted successfully!')),
      );
    } catch (e) {
      debugPrint('Error deleting user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchUsers),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('No users found.'))
              : SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('First Name')),
                      DataColumn(label: Text('Last Name')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Active Listings')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _users.map((user) {
                      return DataRow(
                        cells: [
                          DataCell(Text(user.id.toString())),
                          DataCell(Text(user.firstName)),
                          DataCell(Text(user.lastName)),
                          DataCell(Text(user.email)),
                          DataCell(Text(_activeListings[user.id]?.toString() ?? 'Loading...')),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteUser(user.id!),
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
