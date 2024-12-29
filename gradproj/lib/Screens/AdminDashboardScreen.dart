import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;

  int _userCount = 0;
  int _propertyCount = 0;

  int _adminCount = 0;         
  int _activeProperties = 0;   

  @override
  void initState() {
    super.initState();
    _fetchAllDashboardData();
  }

  Future<void> _fetchAllDashboardData() async {
    try {
      setState(() => _isLoading = true);

      final supabase = Supabase.instance.client;

     

      final userCount =  0;

      // ---- 2) Count total properties
      final propertyResponse = await supabase
          .from('properties')
          .select()
          .count(CountOption.exact);

      debugPrint('--- propertyResponse ---');
      debugPrint('data: ${propertyResponse.data}');
      debugPrint('count: ${propertyResponse.count}');

      final propertyCount = propertyResponse.count ?? 0;

      
      final adminResponse = await supabase
          .from('admins') 
          .select()
          .count(CountOption.exact);

      debugPrint('--- adminResponse ---');
      debugPrint('data: ${adminResponse.data}');
      debugPrint('count: ${adminResponse.count}');

      final adminCount = adminResponse.count ?? 0;

      // ---- 4) Count how many properties are "active"
      // Adjust if you do not have a 'status' column or need a different filter
      final activeResponse = await supabase
          .from('properties')
          .select()
          .count(CountOption.exact);

      debugPrint('--- activeResponse ---');
      debugPrint('data: ${activeResponse.data}');
      debugPrint('count: ${activeResponse.count}');

      final activeCount = activeResponse.count ?? 0;

      setState(() {
        _userCount = userCount;
        _propertyCount = propertyCount;
        _adminCount = adminCount;
        _activeProperties = activeCount;
      });
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onRefresh() => _fetchAllDashboardData();

  @override
  Widget build(BuildContext context) {
    debugPrint(">>> BUILD: _userCount=$_userCount, _propertyCount=$_propertyCount");

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        actions: [
          // A refresh icon
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAllDashboardData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _DashboardCard(
                            title: 'Total Users',
                            value: _userCount.toString(),
                            icon: Icons.people,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _DashboardCard(
                            title: 'Total Properties',
                            value: _propertyCount.toString(),
                            icon: Icons.home_work,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _DashboardCard(
                            title: 'Admin Users',
                            value: _adminCount.toString(),
                            icon: Icons.shield,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _DashboardCard(
                            title: 'Active Props',
                            value: _activeProperties.toString(),
                            icon: Icons.check_circle,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Action Buttons
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.list, size: 24),
                          label: const Text('View All Users'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            minimumSize: const Size.fromHeight(50),
                          ),
                          onPressed: () {
                            // TODO: navigate to user management screen
                          },
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.business, size: 24),
                          label: const Text('View All Properties'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            minimumSize: const Size.fromHeight(50),
                          ),
                          onPressed: () {
                            // TODO: navigate to property management screen
                          },
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.security, size: 24),
                          label: const Text('Manage Admins'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            minimumSize: const Size.fromHeight(50),
                          ),
                          onPressed: () {
                            Navigator.pushNamed(context, '/manageAdmins');

                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Reusable Card widget for showing a label, number, and icon.
class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _DashboardCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
