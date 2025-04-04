import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradproj/Controllers/property_controller.dart';
import 'package:gradproj/Controllers/user_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Models/propertyClass.dart';
import 'package:gradproj/Screens/CustomBottomNavBar.dart';
import 'package:gradproj/Screens/Profile.dart';
import 'package:gradproj/Screens/PropertyDetails.dart';
import 'package:gradproj/Screens/PropertyListings.dart';
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
  final _userController = UserController();
  final _propertyController = PropertyController(Supabase.instance.client);

  int _currentIndex = 1;
  List<Property> recommendations = [];

  @override
  void initState() {
    super.initState();
    ref.read(favouritesProvider.notifier).fetchFavorites();

    final userId = singletonSession().userId;
    if (userId != null) {
      fetchRecommendationsAndSetState(userId);
    } else {
      debugPrint("User ID is NULL! Recommendations not fetched.");
    }
  }

  Future<void> fetchRecommendationsAndSetState(int userId) async {
    final rawRecommendations = await _userController.fetchRecommendationsRaw(userId);
    if (rawRecommendations.isEmpty) {
      debugPrint("No raw recommendations received.");
      return;
    }

    final fetchedProperties =
        await _propertyController.fetchPropertiesFromIdsWithScores(rawRecommendations);

    setState(() {
      recommendations = fetchedProperties;
    });
  }






  // Future<void> fetchPropertiesFromSupabase(List<Map<String, dynamic>> recommendedData) async {
  //   final supabase = Supabase.instance.client;

  //   try {
  //     List<int> propertyIds = recommendedData.map<int>((item) => item['id'] as int).toList();
  //     Map<int, double> similarityScores = {
  //       for (var item in recommendedData) item['id'] as int: (item['similarity_score'] as num).toDouble()
  //     };

  //     final List<Map<String, dynamic>> response = await supabase
  //         .from('properties')
  //         .select('*')
  //         .filter('id', 'in', propertyIds);

  //     if (response.isEmpty) {
  //       debugPrint("Supabase Error: No properties found for IDs: $propertyIds");
  //       return;
  //     }

  //     setState(() {
  //       recommendations = response.map<Property>((json) {
  //         Property property = Property.fromJson(json);

  //         if (similarityScores.containsKey(property.id)) {
  //           property.similarityScore = similarityScores[property.id];
  //         }

  //         return property;
  //       }).toList();

  //       recommendations.sort((a, b) => b.similarityScore!.compareTo(a.similarityScore!));
  //     });

  //     debugPrint("Sorted Property Data from Supabase with Similarity Scores: $recommendations");
  //   } catch (e) {
  //     debugPrint("Exception fetching from Supabase: $e");
  //   }
  // }

  // Future<void> fetchRecommendations(int userId) async {
  //   const String apiUrl = 'http://192.168.1.12:8080/recommendations/';
  //   final Uri url = Uri.parse(apiUrl);

  //   debugPrint("Sending request to: $url with user_id: $userId");

  //   try {
  //     final response = await http.post(
  //       url,
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode({'user_id': userId}),
  //     );

  //     debugPrint("Response Status Code: ${response.statusCode}");
  //     debugPrint("Response Body: ${response.body}");

  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);

  //       if (data.containsKey('recommendations') && data['recommendations'] is List) {
  //         List<Map<String, dynamic>> recommendedData = (data['recommendations'] as List)
  //             .map((item) => {
  //                   "id": item['id'],
  //                   "similarity_score": item['similarity_score'],
  //                 })
  //             .toList();

  //         debugPrint("Recommended Data: $recommendedData");

  //         await fetchPropertiesFromSupabase(recommendedData);
  //       } else {
  //         debugPrint("Error: 'recommendations' key missing or not a list.");
  //       }
  //     } else {
  //       debugPrint("Error: ${response.statusCode} ${response.reasonPhrase}");
  //     }
  //   } catch (e) {
  //     debugPrint("Exception: $e");
  //   }
  // }

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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Favorites',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              favourites.isEmpty
                  ? Center(
                      child: Text(
                        'No favorite properties yet!',
                        style: theme.textTheme.bodyLarge,
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: favourites.length,
                      separatorBuilder: (context, index) => SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final property = favourites[index];

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: theme.cardColor,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                              '${property.type}',
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
                                  'id : ${property.id.toString()}',
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
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: theme.colorScheme.error),
                              onPressed: () {
                                final favouritesNotifier = ref.read(favouritesProvider.notifier);
                                favouritesNotifier.removeProperty(property);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("${property.type} removed from favorites"),
                                    duration: const Duration(seconds: 3),
                                    action: SnackBarAction(
                                      label: "Undo",
                                      onPressed: () {
                                        favouritesNotifier.addProperty(property);
                                      },
                                    ),
                                  ),
                                );
                              },
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
              const SizedBox(height: 20),
              if (recommendations.isNotEmpty) ...[
                Divider(thickness: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Recommendations Based on Your Likes',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: recommendations.length,
                  separatorBuilder: (context, index) => SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final Property recommendation = recommendations[index];
                    return RecommendationCard(
                      property: recommendation,
                    );
                  },
                ),
              ],
            ],
          ),
        ),
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
