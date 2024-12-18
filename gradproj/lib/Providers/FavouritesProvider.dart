import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/Property.dart';

final favouritesProvider =
    StateNotifierProvider<FavouritesPropertyNotifier, List<Property>>((ref) {
  return FavouritesPropertyNotifier();
});

class FavouritesPropertyNotifier extends StateNotifier<List<Property>> {
  FavouritesPropertyNotifier() : super([]);

  void addProperty(Property property) {
    state = [...state, property];
  }

  void removeProperty(Property property) {
    state = state.where((p) => p.id != property.id).toList();
  }
}
