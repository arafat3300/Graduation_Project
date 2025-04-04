import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Models/propertyClass.dart';
import '../Models/singletonSession.dart';
import '../Controllers/favorites_controller.dart';

final favouritesProvider =
    StateNotifierProvider<FavouritesPropertyNotifier, List<Property>>((ref) {
  return FavouritesPropertyNotifier();
});

class FavouritesPropertyNotifier extends StateNotifier<List<Property>> {
  FavouritesPropertyNotifier() : super([]);

  final FavoritesController _favoritesController = FavoritesController();

  Future<void> fetchFavorites() async {
    final userId = singletonSession().userId;
    if (userId == null) return;

    try {
      final favorites = await _favoritesController.getUserFavorites(userId);
      state = favorites;
    } catch (e) {
      debugPrint('Error fetching favorites: $e');
    }
  }

  Future<void> addProperty(Property property) async {
    final userId = singletonSession().userId;
    if (userId == null) return;

    try {
      final success = await _favoritesController.addToFavorites(userId, property.id);
      if (success) {
        state = [...state, property];
      }
    } catch (e) {
      debugPrint('Error adding property to favorites: $e');
    }
  }

  Future<void> removeProperty(Property property) async {
    final userId = singletonSession().userId;
    if (userId == null) return;

    try {
      final success = await _favoritesController.removeFromFavorites(userId, property.id);
      if (success) {
        state = state.where((p) => p.id != property.id).toList();
      }
    } catch (e) {
      debugPrint('Error removing property from favorites: $e');
    }
  }
}
