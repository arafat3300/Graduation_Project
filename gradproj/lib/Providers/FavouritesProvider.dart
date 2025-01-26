import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/Property.dart';
import '../Models/singletonSession.dart';

final favouritesProvider =
    StateNotifierProvider<FavouritesPropertyNotifier, List<Property>>((ref) {
  return FavouritesPropertyNotifier();
});

class FavouritesPropertyNotifier extends StateNotifier<List<Property>> {
  FavouritesPropertyNotifier() : super([]);

  final supabase = Supabase.instance.client;

  Future<void> fetchFavorites() async {
    final userId = singletonSession().userId;
    if (userId == null) return;

    try {
      final response = await supabase
          .from('user_favorites')
          .select('property_id, properties(*)')
          .eq('user_id', userId);

      if (response != null && response is List) {
        final favorites = response.map((item) {
          return Property.fromJson(item['properties']);
        }).toList();
        state = favorites;
      }
    } catch (e) {
      print('Error fetching favorites: $e');
    }
  }

  Future<void> addProperty(Property property) async {
    final userId = singletonSession().userId;
    if (userId == null) return;

    try {
      await supabase.from('user_favorites').insert({
        'user_id': userId,
        'property_id': property.id,
      });

      state = [...state, property];
    } catch (e) {
      print('Error adding property to favorites: $e');
    }
  }

  Future<void> removeProperty(Property property) async {
    final userId = singletonSession().userId;
    if (userId == null) return;

    try {
      await supabase.from('user_favorites').delete().match({
        'user_id': userId,
        'property_id': property.id,
      });

      state = state.where((p) => p.id != property.id).toList();
    } catch (e) {
      print('Error removing property from favorites: $e');
    }
  }
}
