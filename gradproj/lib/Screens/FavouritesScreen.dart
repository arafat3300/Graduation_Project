import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Providers/FavouritesProvider.dart';
import '../models/Property.dart';

class FavoritesScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      // child: Image.network(
                      //   property.imgUrl, // Use the property image URL
                      //   width: 70,
                      //   height: 70,
                      //   fit: BoxFit.cover,
                      // ),
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
    );
  }
}
