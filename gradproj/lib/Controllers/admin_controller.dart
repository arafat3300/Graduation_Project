import 'package:supabase_flutter/supabase_flutter.dart';

import '../Models/property.dart';

class AdminController {
  final SupabaseClient supabase;

  AdminController(this.supabase);

  

  Future<bool> updatePropertyStatus(int propertyId, String newStatus) async {
    try {
      final response = await supabase
          .from('properties')
          .update({'status': newStatus})
          .eq('id', propertyId);

      return response == null; // Return true if update was successful
    } catch (e) {
      print("Error updating property status: $e");
      return false; // Return false if an error occurs
    }
  }
}