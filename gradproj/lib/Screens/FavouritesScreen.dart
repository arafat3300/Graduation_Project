import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradproj/Screens/CustomBottomNavBar.dart';
import 'package:gradproj/Screens/PropertyListings.dart';
import '../Providers/FavouritesProvider.dart';
import '../models/Property.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  int _currentIndex = 2; // Default index for the Favorites screen

  @override
  Widget build(BuildContext context) {
    // Get the current list of favorite properties
    final favourites = ref.watch(favouritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        centerTitle: true,
      ),
      body: favourites.isEmpty
          ? const Center(
              child: Text(
                'No favorite properties yet!',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              itemCount: favourites.length,
              itemBuilder: (context, index) {
                final property = favourites[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 16),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        property.imgUrl!, // Use the property image URL
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, size: 70),
                      ),
                    ),
                    title: Text(
                      property.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(property.location),
                        const SizedBox(height: 4),
                        Text(
                          '\$${property.price}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        // Remove property from favourites
                        ref
                            .read(favouritesProvider.notifier)
                            .removeProperty(property);
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

          // Handle navigation based on selected index
          if (_currentIndex == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const PropertyListScreen(),
              ),
            );
          } else if (_currentIndex == 1) {
            // Navigate to Search screen (if implemented)
          } else if (_currentIndex == 2) {
            // Stay on Favorites screen (no action needed)
          } else if (_currentIndex == 3) {
            // Navigate to Profile screen (if implemented)
          }
        },
      ),
    );
  }
}
