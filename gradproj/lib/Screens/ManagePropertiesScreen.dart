import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../Models/propertyClass.dart'; // Import your Property class

class ManagePropertiesScreen extends StatefulWidget {
  const ManagePropertiesScreen({Key? key}) : super(key: key);

  @override
  _ManagePropertiesScreenState createState() => _ManagePropertiesScreenState();
}

class _ManagePropertiesScreenState extends State<ManagePropertiesScreen> {
  bool _isLoading = false;
  List<Property> _properties = []; 
  List<Property> _filteredProperties = []; 
  final TextEditingController _searchController = TextEditingController(); 
  @override
  void initState() {
    super.initState();
    _fetchProperties();
  }

  Future<void> _fetchProperties() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final List response = await supabase
          .from('properties')
          .select('*')
          .eq('status', 'approved') 
          .then((result) {
        return result is List ? List<Map<String, dynamic>>.from(result) : [];
      }).catchError((error) {
        debugPrint('Supabase query error: $error');
        return <Map<String, dynamic>>[];
      });

      if (response.isNotEmpty) {
        final properties =
            response.map((data) => Property.fromJson(data)).toList();
        setState(() {
          _properties = properties;
          _filteredProperties = properties; 
        });
      }
    } catch (e) {
      debugPrint('Error fetching properties: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _searchProperties(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredProperties = _properties;
      });
      return;
    }

    final lowerCaseQuery = query.toLowerCase();
    setState(() {
      _filteredProperties = _properties.where((property) {
        final idMatch = property.id.toString().contains(lowerCaseQuery);
        final typeMatch = property.type.toLowerCase().contains(lowerCaseQuery);
        final cityMatch = property.city.toLowerCase().contains(lowerCaseQuery);
        return idMatch || typeMatch || cityMatch;
      }).toList();
    });
  }

  Future<void> _deleteProperty(int id) async {
    try {
      setState(() => _isLoading = true);

      final supabase = Supabase.instance.client;
      await supabase.from('properties').delete().eq('id', id);

      setState(() {
        _properties.removeWhere((property) => property.id == id);
        _filteredProperties.removeWhere((property) => property.id == id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property deleted successfully!')),
      );
    } catch (e) {
      debugPrint('Error deleting property: $e');
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
        title: const Text('Manage Properties'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchProperties),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by ID, Type, or City',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: _searchProperties, 
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProperties.isEmpty
                    ? const Center(child: Text('No matching properties found.'))
                    : SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('ID')),
                            DataColumn(label: Text('Type')),
                            DataColumn(label: Text('Price')),
                            DataColumn(label: Text('Bedrooms')),
                            DataColumn(label: Text('Bathrooms')),
                            DataColumn(label: Text('City')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: _filteredProperties.map((property) {
                            return DataRow(
                              cells: [
                                DataCell(Text(property.id.toString())),
                                DataCell(Text(property.type)),
                                DataCell(Text('\$${property.price}')),
                                DataCell(Text(property.bedrooms.toString())),
                                DataCell(Text(property.bathrooms.toString())),
                                DataCell(Text(property.city)),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteProperty(property.id!),
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
