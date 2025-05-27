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

// Add DotPatternPainter class
class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color.fromARGB(18, 255, 255, 255)
      ..style = PaintingStyle.fill;
    const double spacing = 32;
    const double radius = 2.2;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
  List<Property> contentBasedRecommendations = [];
  List<Property> feedbackBasedRecommendations = [];
  bool _isLoadingContentBasedRecommendations = false;
  bool _isLoadingFeedbackBasedRecommendations = false;

  @override
  void initState() {
    super.initState();
    ref.read(favouritesProvider.notifier).fetchFavorites();

    final userId = singletonSession().userId;
    if (userId != null) {
      fetchContentBasedRecommendationsAndSetState(userId);
      fetchFeedbackBasedRecommendationsAndSetState(userId);
    } else {
      debugPrint("User ID is NULL! Recommendations not fetched.");
    }
  }

  Future<void> fetchContentBasedRecommendationsAndSetState(int userId) async {
    setState(() {
      _isLoadingContentBasedRecommendations = true;
    });

    try {
      final rawRecommendations = await _userController.fetchRecommendationsRaw(userId);
      if (rawRecommendations.isEmpty) {
        debugPrint("No content-based recommendations received.");
        return;
      }

      final fetchedProperties =
          await _propertyController.fetchPropertiesFromIdsWithScores(rawRecommendations);

      setState(() {
        contentBasedRecommendations = fetchedProperties;
      });
    } catch (e) {
      debugPrint("Error fetching content-based recommendations: $e");
    } finally {
      setState(() {
        _isLoadingContentBasedRecommendations = false;
      });
    }
  }

  Future<void> fetchFeedbackBasedRecommendationsAndSetState(int userId) async {
    setState(() {
      _isLoadingFeedbackBasedRecommendations = true;
    });

    try {
      final rawRecommendations = await _userController.fetchFeedbackBasedRecommendationsFromDB(userId);
      if (rawRecommendations.isEmpty) {
        debugPrint("No feedback-based recommendations received.");
        return;
      }

      final fetchedProperties =
          await _propertyController.fetchPropertiesFromIdsWithScores(rawRecommendations);

      setState(() {
        feedbackBasedRecommendations = fetchedProperties;
      });
    } catch (e) {
      debugPrint("Error fetching feedback-based recommendations: $e");
    } finally {
      setState(() {
        _isLoadingFeedbackBasedRecommendations = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final favourites = ref.watch(favouritesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              colors: [
                Color.fromARGB(255, 8, 145, 236),
                                                 Color.fromARGB(255, 2, 48, 79), 
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds);
          },
          child: const Text(
            'Favorites',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white, // masked by gradient
              letterSpacing: 1.1,
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: Icon(Icons.dark_mode, color: theme.iconTheme.color),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Gradient background with dot pattern and highlight
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                
                    Colors.white,
                     Colors.white,
                   
                                                                           
                ],
                // Removed stops as default is fine for 2 colors
              ),
            ),
            child: Stack(
              children: [
                // Subtle white dot pattern overlay
                CustomPaint(
                  size: Size.infinite,
                  painter: _DotPatternPainter(),
                ),
                // Soft radial white highlight/spotlight
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(0, -0.2),
                          radius: 0.7,
                          colors: [
                            Color.fromARGB(60, 255, 255, 255),
                            Colors.transparent,
                          ],
                          stops: [0.0, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content over background
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 'Your Favorites' as bold orange text
                  Text(
                    'Your Favorites',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 0, 0, 0), 
                      letterSpacing: 1.1,
                    ),
                  ),
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
                              color: Colors.white,
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
                                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black),
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
                                        color:  Color.fromARGB(255, 8, 145, 236,),
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
                  if (_isLoadingContentBasedRecommendations)
                    Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 10),
                          Text(
                            'Loading content-based recommendations...',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  else if (contentBasedRecommendations.isNotEmpty) ...[
                    Divider(thickness: 2),
                    // 'Recommendations based on your favorites' as bold orange text
                    Text(
                      'Recommendations based on your favorites',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 0, 0, 0), // Bold orange
                        letterSpacing: 1.1,
                      ),
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: contentBasedRecommendations.length,
                      separatorBuilder: (context, index) => SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final Property recommendation = contentBasedRecommendations[index];
                        return RecommendationCard(
                          property: recommendation,
                        );
                      },
                    ),
                  ],
                  if (_isLoadingFeedbackBasedRecommendations)
                    Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 10),
                          Text(
                            'Loading feedback-based recommendations...',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  else if (feedbackBasedRecommendations.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Divider(thickness: 2),
                    // 'Recommendations based on your feedback' as bold orange text
                    Text(
                      'Recommendations based on your feedback',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color:Color.fromARGB(255, 20, 20, 20), // Bold orange
                        letterSpacing: 1.1,
                      ),
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: feedbackBasedRecommendations.length,
                      separatorBuilder: (context, index) => SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final Property recommendation = feedbackBasedRecommendations[index];
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
