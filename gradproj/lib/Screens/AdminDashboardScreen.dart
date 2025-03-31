import 'package:flutter/material.dart';
import 'package:gradproj/Controllers/admin_controller.dart';
import 'package:gradproj/Screens/ApproveProperties.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gradproj/Controllers/user_controller.dart';


class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;

  int _userCount = 0;
  int _propertyCount = 0;

  int _adminCount = 0;         
  int _activeProperties = 0;   
    final UserController _userController = UserController();
    final AdminController _adminController = AdminController(Supabase.instance.client);



  @override
  void initState() {
    super.initState();
    _fetchAllDashboardData();
  }
Future<void> _fetchAllDashboardData() async {
  setState(() => _isLoading = true);

  final counts = await _adminController.fetchDashboardCounts();

  setState(() {
    _userCount = counts['users'] ?? 0;
    _propertyCount = counts['properties'] ?? 0;
    _adminCount = counts['admins'] ?? 0;
    _activeProperties = counts['activeProps'] ?? 0;
    _isLoading = false;
  });
}


  // Future<void> _fetchAllDashboardData() async {
  //   try {
  //     setState(() => _isLoading = true);

  //     final supabase = Supabase.instance.client;

     

  //     final UserResponse= await supabase
  //         .from('users')
  //         .select()
  //         .count(CountOption.exact);

  //     debugPrint('--- propertyResponse ---');
  //     // debugPrint('data: ${UserResponse.data}');
  //     debugPrint('count: ${UserResponse.count}');

  //     final userCount = UserResponse.count ?? 0;
  //     final propertyResponse = await supabase
  //         .from('properties')
  //         .select()
  //         .count(CountOption.exact);

  //     debugPrint('--- propertyResponse ---');
  //     // debugPrint('data: ${propertyResponse.data}');
  //     debugPrint('count: ${propertyResponse.count}');

  //     final propertyCount = propertyResponse.count ?? 0;

      
  //     final adminResponse = await supabase
  //         .from('admins') 
  //         .select()
  //         .count(CountOption.exact);

  //     debugPrint('--- adminResponse ---');
  //     // debugPrint('data: ${adminResponse.data}');
  //     debugPrint('count: ${adminResponse.count}');

  //     final adminCount = adminResponse.count ?? 0;

 
  //     final activeResponse = await supabase
  //         .from('properties')
  //         .select()
  //         .eq('status', "approved")
  //         .count(CountOption.exact);

  //     debugPrint('--- activeResponse ---');
  //     debugPrint('data: ${activeResponse.data}');
  //     debugPrint('count: ${activeResponse.count}');

  //     final activeCount = activeResponse.count ?? 0;


      

  //     setState(() {
  //       _userCount = userCount;
  //       _propertyCount = propertyCount;
  //       _adminCount = adminCount;
  //       _activeProperties = activeCount;
  //     });
  //   } catch (e) {
  //     debugPrint('Error fetching dashboard data: $e');
  //   } finally {
  //     setState(() => _isLoading = false);
  //   }
  // }

  Future<void> _onRefresh() => _fetchAllDashboardData();

Future<void> _logout(BuildContext context) async {
    await _userController.saveSessionToken(""); 
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }
  @override
  Widget build(BuildContext context) {
    debugPrint(">>> BUILD: _userCount=$_userCount, _propertyCount=$_propertyCount");

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAllDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _logout(context);
            },
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
                          label: const Text('Manage Users'),
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
                            Navigator.pushNamed(context, '/manageUsers');
                          },
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.business, size: 24),
                          label: const Text('Manage Properties'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:const Color.fromARGB(255, 0, 0, 0),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            minimumSize: const Size.fromHeight(50),
                          ),
                          onPressed: () {
                            Navigator.pushNamed(context, '/manageProps');
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
                        ),const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.done_outline_outlined, size: 24),
                          label: const Text('Approve Properties'),
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
                            Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                       const ApproveProperty(),
                                  ),
                                );
                          },
                        )
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
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

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
