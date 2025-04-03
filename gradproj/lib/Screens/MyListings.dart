import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Screens/PropertyDetails.dart';
import '../Controllers/property_controller.dart';
import '../Models/propertyClass.dart';

class MyListings extends StatefulWidget {
  final int userId;
  const MyListings({Key? key, required this.userId}) : super(key: key);

  @override
  _MyListingsState createState() => _MyListingsState();
}

class _MyListingsState extends State<MyListings> {

  final PropertyController propertyController = PropertyController(Supabase.instance.client);
  List<Property> properties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserProperties();
  }

  Future<void> fetchUserProperties() async {
    setState(() => _isLoading = true);

    final userProperties = await propertyController
        .getUserPropertiesWithDetails(widget.userId);
    setState(() {
      properties = userProperties;
      _isLoading = false;
    });
  }


  Future<void> deleteProperty(int propertyId) async {
    final success = await propertyController.deleteProperty(propertyId);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Property deleted successfully!")),
      );
      fetchUserProperties(); // Refresh the property list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to delete property.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Listings"),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : properties.isEmpty
              ? const Center(
                  child: Text(
                    "You don't have any properties listed.",
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
                          "Status: ${property.status ?? 'N/A'} (ID: ${property.id})",
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        trailing: Row(
                          mainAxisSize:
                              MainAxisSize.min, // Keep buttons compact
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
                            const SizedBox(width: 8), // Spacing between buttons
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("Confirm Deletion"),
                                    content: const Text(
                                        "Are you sure you want to delete this property?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text("Delete"),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm ?? false) {
                                  await deleteProperty(property.id!);
                                }
                              },
                              child: const Text(
                                "Delete",
                                style: TextStyle(color: Colors.white),
                              ),
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
