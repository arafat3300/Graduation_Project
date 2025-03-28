import 'package:flutter/material.dart';
import 'package:gradproj/Controllers/admin_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Controllers/property_controller.dart';
import '../models/Property.dart';
import '../Screens/PropertyDetails.dart';

class ApproveProperty extends StatefulWidget {
  const ApproveProperty({Key? key}) : super(key: key);

  @override
  _ApprovePropertyState createState() => _ApprovePropertyState();
}

class _ApprovePropertyState extends State<ApproveProperty> {
  final PropertyController propertyController = PropertyController(Supabase.instance.client);
  final AdminController adminController = AdminController(Supabase.instance.client);

  List<Property> properties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPendingProperties();
  }

  /// Fetch properties with a pending status
  Future<void> fetchPendingProperties() async {
    setState(() => _isLoading = true);
    
    final pendingProperties = await propertyController.getPendingProperties(); // ✅ Fixed call
    setState(() {
      properties = pendingProperties;
      _isLoading = false;
    });
  }

  /// Approve or reject a property
  Future<void> updatePropertyStatus(int propertyId, String newStatus) async {
    bool success = await adminController.updatePropertyStatus(propertyId, newStatus);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Property status updated to $newStatus!")),
      );
      fetchPendingProperties(); // Refresh list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update property status.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Approve Properties"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchPendingProperties,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : properties.isEmpty
              ? const Center(
                  child: Text(
                    "No pending properties to review.",
                    style: TextStyle(fontSize: 18.0),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: properties.length,
                  itemBuilder: (context, index) {
                    final property = properties[index];
                    return _buildPropertyCard(property);
                  },
                ),
    );
  }

  Widget _buildPropertyCard(Property property) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: _buildPropertyImage(property),
        title: Text(
          property.type,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "Status: ${property.status ?? 'N/A'}",
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        trailing: _buildActionButtons(property),
      ),
    );
  }

  Widget _buildPropertyImage(Property property) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Image.network(
        property.imgUrl != null && property.imgUrl!.isNotEmpty
            ? property.imgUrl!.first
            : 'https://agentrealestateschools.com/wp-content/uploads/2021/11/real-estate-property.jpg',
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Image.network(
          'https://agentrealestateschools.com/wp-content/uploads/2021/11/real-estate-property.jpg',
          width: 70,
          height: 70,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildActionButtons(Property property) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.visibility, color: Colors.blue),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PropertyDetails(property: property),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.check, color: Colors.green),
          onPressed: () async {
            await updatePropertyStatus(property.id!, 'approved');
          },
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: () async {
            await updatePropertyStatus(property.id!, 'unavailable');
          },
        ),
      ],
    );
  }
}
