import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/Property.dart';
import 'package:gradproj/Screens/CustomBottomNavBar.dart';
import 'package:gradproj/Screens/Profile.dart';
import 'package:gradproj/Screens/PropertyDetails.dart';
import 'package:gradproj/Screens/PropertyListings.dart';
import 'package:gradproj/Screens/search.dart';
import '../Providers/FavouritesProvider.dart';
import '../Models/singletonSession.dart';
import '../widgets/RecommendationCard.dart';
import 'package:http/http.dart' as http;


class FavoritesScreen extends ConsumerStatefulWidget {
  final VoidCallback toggleTheme;

  const FavoritesScreen({super.key, required this.toggleTheme});

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  int _currentIndex = 1;
  List<Property> recommendations = []; 

  @override
  void initState() {
    super.initState();
    final favouritesNotifier = ref.read(favouritesProvider.notifier);
    favouritesNotifier.fetchFavorites(); 

    int? userId = singletonSession().userId;
    debugPrint("User ID in Singleton: $userId");

    if (userId != null) {
      fetchRecommendations(userId);
    } else {
      debugPrint("User ID is NULL! Recommendations not fetched.");
    }
  }

Future<void> fetchPropertiesFromSupabase(List<Map<String, dynamic>> recommendedData) async {
  final supabase = Supabase.instance.client;
  String test = 't';

  try {
    // ✅ Extract property IDs and map similarity scores
    List<int> propertyIds = recommendedData.map<int>((item) => item['id'] as int).toList();
    Map<int, double> similarityScores = {
      for (var item in recommendedData) item['id'] as int: (item['similarity_score'] as num).toDouble()
    };

    final List<Map<String, dynamic>> response = await supabase
        .from('properties')
        .select('*')
        .filter('id', 'in', propertyIds);

    if (response.isEmpty) {
      debugPrint("Supabase Error: No properties found for IDs: $propertyIds");
      return;
    }

    setState(() {
      recommendations = response.map<Property>((json) {
        Property property = Property.fromJson(json);

        // ✅ Assign similarity score from the API response
        if (similarityScores.containsKey(property.id)) {
          property.similarityScore = similarityScores[property.id];
        }

        return property;
      }).toList();

      // ✅ Sort recommendations in descending order by similarity_score
      recommendations.sort((a, b) => b.similarityScore!.compareTo(a.similarityScore!));
    });

    debugPrint(" Sorted Property Data from Supabase with Similarity Scores: $recommendations");
  } catch (e) {
    debugPrint("Exception fetching from Supabase: $e");
  }
}


Future<void> fetchRecommendations(int userId) async {
  const String apiUrl = 'http://172.20.10.5:8080/recommendations/';
  final Uri url = Uri.parse(apiUrl);

  debugPrint(" Sending request to: $url with user_id: $userId");

  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );

    debugPrint(" Response Status Code: ${response.statusCode}");
    debugPrint(" Response Body: ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data.containsKey('recommendations') && data['recommendations'] is List) {
        List<Map<String, dynamic>> recommendedData = (data['recommendations'] as List)
            .map((item) => {
                  "id": item['id'],
                  "similarity_score": item['similarity_score'],
                })
            .toList();

        debugPrint(" Recommended Data: $recommendedData");

     
        await fetchPropertiesFromSupabase(recommendedData);
      } else {
        debugPrint(" Error: 'recommendations' key missing or not a list.");
      }
    } else {
      debugPrint(" Error: ${response.statusCode} ${response.reasonPhrase}");
    }
  } catch (e) {
    debugPrint("Exception: $e");
  }
}










  @override
  Widget build(BuildContext context) {
    final favourites = ref.watch(favouritesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.dark_mode, color: theme.iconTheme.color),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: Column(
        children: [
          
          Expanded(
            flex: 1,
            child: favourites.isEmpty
                ? Center(
                    child: Text(
                      'No favorite properties yet!',
                      style: theme.textTheme.bodyLarge,
                    ),
                  )
                : ListView.builder(
                    itemCount: favourites.length,
                    itemBuilder: (context, index) {
                      final property = favourites[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        color: theme.cardColor,
                        child: ListTile(
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
                              const SizedBox(height: 4),
                              Text(
                                '\$${property.price.toStringAsFixed(2)}',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
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

          // ✅ Recommendations Section (NEW)
          if (recommendations.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Recommendations Based on Your Likes',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              flex: 1,
              child: ListView.builder(
                itemCount: recommendations.length,
                itemBuilder: (context, index) {
                  final Property recommendation = recommendations[index];
                  return RecommendationCard(
                    property: recommendation,
                  );
                },
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (_currentIndex == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PropertyListScreen(toggleTheme: widget.toggleTheme),
              ),
            );
          } else if (_currentIndex == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ViewProfilePage(),
              ),
            );
          }
        },
      ),
    );
  }
}

