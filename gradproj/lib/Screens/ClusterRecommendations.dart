import 'package:flutter/material.dart';
import 'package:gradproj/Controllers/property_controller.dart';
import '../Models/propertyClass.dart';
import 'PropertyDetails.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClusterRecommendations extends StatefulWidget {
  final int clusterId;
  final String clusterMessage;

  const ClusterRecommendations({
    Key? key,
    required this.clusterId,
    required this.clusterMessage,
  }) : super(key: key);

  @override
  State<ClusterRecommendations> createState() => _ClusterRecommendationsState();
}

class _ClusterRecommendationsState extends State<ClusterRecommendations> {
  final PropertyController _propertyController = PropertyController(Supabase.instance.client);
  List<Property> _recommendedProperties = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRecommendedProperties();
  }

  Future<void> _fetchRecommendedProperties() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final properties = await _propertyController.getPropertiesByCluster(widget.clusterId);
      setState(() {
        _recommendedProperties = properties;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load recommendations: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommended Properties'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading recommendations...',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchRecommendedProperties,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.teal.withOpacity(0.1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Smart-Match Profile',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.clusterMessage,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _recommendedProperties.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 48, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No recommended properties found',
                                    style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _recommendedProperties.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final property = _recommendedProperties[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  color: theme.cardColor,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        property.imgUrl?.isNotEmpty == true
                                            ? property.imgUrl!.first
                                            : 'https://agentrealestateschools.com/wp-content/uploads/2021/11/real-estate-property.jpg',
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            Icon(Icons.broken_image, size: 70, color: theme.colorScheme.error),
                                      ),
                                    ),
                                    title: Text(
                                      property.type,
                                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          property.city,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                        Text(
                                          'ID: ${property.id}',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '\$${property.price.toStringAsFixed(2)}',
                                              style: theme.textTheme.bodyLarge?.copyWith(
                                                color: theme.colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (property.similarityScore != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.teal.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'Score: ${(property.similarityScore! * 100).toStringAsFixed(1)}%',
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    color: Colors.teal,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PropertyDetails(property: property),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
} 