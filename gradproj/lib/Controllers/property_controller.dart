import 'package:flutter/cupertino.dart';
import '../models/Property.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PropertyController {
Future<List<Property>> getUserPropertiesWithDetails(int userId, SupabaseClient supabase) async {
    try {
      final response = await supabase
          .from('properties')
          .select('*')
          .filter('user_id', 'eq', userId);

      if (response.isEmpty) {
        return [];
      }

      // Map response to a list of Property objects
      return (response as List).map((data) => Property.fromJson(data)).toList();
    } catch (e) {
      debugPrint("Error fetching user properties: $e");
      return [];
    }
  }



Future<bool> deleteProperty(int propertyId, SupabaseClient supabase) async {
  try {
    final response = await supabase
        .from('properties')
        .delete()
        .eq('id', propertyId);

    // Check if the response data is not null and contains at least one item
    if (response == null || response.isEmpty) {
    debugPrint("Property deleted successfully}");
    return true;
    }

    // If deletion succeeded
    debugPrint("delete failed : $response}");
    return false;
  } catch (e) {
    debugPrint("Error deleting property: $e");
    return false;
  }
}

}