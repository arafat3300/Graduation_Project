import 'package:flutter/material.dart';
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
  final PropertyController propertyController = PropertyController();
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
    final supabase = Supabase.instance.client;

    final pendingProperties =
        await propertyController.getPendingProperties(supabase);
    setState(() {
      properties = pendingProperties;
      _isLoading = false;
    });
  }

  /// Approve or reject a property
  Future<void> updatePropertyStatus(
      int propertyId, String newStatus) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('properties')
          .update({'status': newStatus})
          .eq('id', propertyId);

      if (response == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Property status updated to $newStatus!")),
        );
        await fetchPendingProperties(); // Refresh the property list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update property status.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error updating property status ")),
      );
   print(e);
   }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Approve Properties"),
        centerTitle: true,
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
                  itemCount: properties.length,
                  itemBuilder: (context, index) {
                    final property = properties[index];
                    return Card(
                      margin: const EdgeInsets.all(10),
                      elevation: 4,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        leading: property.imgUrl != null &&
                                property.imgUrl!.isNotEmpty
                            ? Image.network(
                                property.imgUrl!.first,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Image.network(
                                  'https://agentrealestateschools.com/wp-content/uploads/2021/11/real-estate-property.jpg',
                                ),
                              )
                            : Image.network(
                                'https://agentrealestateschools.com/wp-content/uploads/2021/11/real-estate-property.jpg',
                              ),
                        title: Text(
                          property.type,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "Status: ${property.status ?? 'N/A'}",
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PropertyDetails(property: property),
                                  ),
                                );
                              },
                              child: const Text("View Details"),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              onPressed: () async {
                                await updatePropertyStatus(
                                    property.id!, 'approved');
                              },
                              child: const Text("Approve" , style: TextStyle(color: Colors.white)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                
                              ),
                              onPressed: () async {
                                await updatePropertyStatus(
                                    property.id!, 'unavailable');
                              },
                              child: const Text("Reject" , style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
