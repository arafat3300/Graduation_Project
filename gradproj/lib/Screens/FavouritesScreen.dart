import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradproj/Screens/CustomBottomNavBar.dart';
import 'package:gradproj/Screens/Profile.dart';
import 'package:gradproj/Screens/PropertyDetails.dart';
import 'package:gradproj/Screens/PropertyListings.dart';
import 'package:gradproj/Screens/search.dart';
import '../Providers/FavouritesProvider.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  final VoidCallback toggleTheme;

  const FavoritesScreen({super.key, required this.toggleTheme});

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  int _currentIndex = 2;

  @override
  Widget build(BuildContext context) {
    final favourites = ref.watch(favouritesProvider);
    final theme = Theme.of(context); // Get the current theme

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
      body: favourites.isEmpty
          ? Center(
              child: Text(
                'No favorite properties yet!',
                style: theme.textTheme.bodyLarge, // Use theme text style
              ),
            )
          : ListView.builder(
              itemCount: favourites.length,
              itemBuilder: (context, index) {
                final property = favourites[index];

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: theme.cardColor, // Use theme card color
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
                            Icon(Icons.broken_image, size: 70, color: theme.colorScheme.error), // Use theme error color
                      ),
                    ),
                    title: Text(
                      property.type,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold), // Use theme text style
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          property.city,
                          style: theme.textTheme.bodyMedium, // Use theme text style
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
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: theme.colorScheme.error), // Use theme error color
                      onPressed: () {
                        final favouritesNotifier = ref.read(favouritesProvider.notifier);
                        favouritesNotifier.removeProperty(property);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("${property.type} removed from favorites"),
                            duration: const Duration(seconds: 5),
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
                  ),
                );
              },
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
          } else if (_currentIndex == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SearchScreen(toggleTheme: widget.toggleTheme),
              ),
            );
          } else if (_currentIndex == 3) {
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
