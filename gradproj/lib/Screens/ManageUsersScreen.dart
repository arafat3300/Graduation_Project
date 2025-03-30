import 'package:flutter/material.dart';
import 'package:gradproj/Controllers/admin_controller.dart';
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
  List<local.User> _filteredUsers = []; // For displaying filtered results
  Map<int, int> _activeListings = {}; // Map to store user ID and active listings count
  final TextEditingController _searchController = TextEditingController(); // Controller for search input
final AdminController _adminController = AdminController(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }
Future<void> _fetchUsers() async {
  setState(() => _isLoading = true);

  try {
    final users = await _adminController.fetchUsers();
    setState(() {
      _users = users;
      _filteredUsers = users;
    });
    final listings = await _adminController.fetchActiveListings(users);
    setState(() {
      _activeListings = listings;
    });
  } catch (e) {
    debugPrint('Error fetching users or listings: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}



Future<void> _deleteUser(int id) async {
  Map<String, dynamic>? deletedUser;
  bool isUndoTriggered = false;

  try {
    setState(() => _isLoading = true);

    deletedUser = await _adminController.deleteUserById(id, _users);

    setState(() {
      _users.removeWhere((user) => user.id == id);
      _filteredUsers.removeWhere((user) => user.id == id);
      _activeListings.remove(id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('User deleted successfully!'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            if (deletedUser != null) {
              try {
                await _adminController.restoreUser(deletedUser!);
                await _fetchUsers();

                isUndoTriggered = true;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User restored successfully!')),
                );
              } catch (e) {
                debugPrint('Error restoring user: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error restoring user: $e')),
                );
              }
            }
          },
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 5));

    if (!isUndoTriggered) {
      debugPrint('Undo not triggered. User deletion finalized.');
    }
  } catch (e) {
    debugPrint('Error deleting user: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}






  void _searchUsers(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredUsers = _users;
      });
      return;
    }

    final lowerCaseQuery = query.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        return user.email.toLowerCase().contains(lowerCaseQuery);
      }).toList();
    });
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by Email',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: _searchUsers, // Trigger search on input change
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? const Center(child: Text('No matching users found.'))
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
                          rows: _filteredUsers.map((user) {
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
          ),
        ],
      ),
    );
  }
}
