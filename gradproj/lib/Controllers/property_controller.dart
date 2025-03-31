import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:multi_image_picker_plus/multi_image_picker_plus.dart';
import 'package:uuid/uuid.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../Models/propertyClass.dart';

class PropertyController {
    final SupabaseClient supabase;
  final Uuid uuid = const Uuid();

  PropertyController(this.supabase);
  
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
Future<List<Property>> getPendingProperties(SupabaseClient supabase) async {
    try {
      final response = await supabase
          .from('properties')
          .select('*')
          .filter('status', 'eq', 'pending');

      if (response.isEmpty) {
        return [];
      }

      // Map response to a list of Property objects
      return (response as List).map((data) => Property.fromJson(data)).toList();
    } catch (e) {
      debugPrint("Error fetching  properties: $e");
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

   Future<bool> submitPropertyForm({
    required Map<String, dynamic> property,
    required List<Asset> selectedImages,
    required Function(List<String>) onImagesUploaded, 
  }) async {
    try {
      // Upload images and get URLs
      List<String> uploadedImageUrls = await uploadImages(selectedImages);

      // Update UI state via callback
      onImagesUploaded(uploadedImageUrls);

      // Add image URLs to property data
      property["img_url"] = uploadedImageUrls;

      // Insert property into Supabase
      await supabase.from('properties').insert(property);

      return true; // Success
    } catch (e) {
      debugPrint("Error submitting form: $e");
      return false; // Failure
    }
  }
 

  Future<List<String>> uploadImages(List<Asset> selectedImages) async {
    List<String> uploadedImageUrls = [];

    if (selectedImages.isEmpty) {
      throw Exception("No images to upload");
    }

    for (var asset in selectedImages) {
      try {
        final byteData = await asset.getByteData();
        final fileBytes = byteData.buffer.asUint8List();
        final uniqueFileName = "${uuid.v4()}_${asset.name.replaceAll(' ', '_')}";

        debugPrint("Preparing to upload image: $uniqueFileName...");
        debugPrint("File size: ${fileBytes.length} bytes");

        final filePath = await supabase.storage
            .from('properties-images')
            .uploadBinary(uniqueFileName, fileBytes);

        if (filePath.isEmpty) {
          throw Exception("Upload failed for $uniqueFileName");
        }

        debugPrint("Image uploaded successfully: $filePath");

        final relativePath = filePath.replaceFirst('properties-images/', '');

        final publicUrl = supabase.storage
            .from('properties-images')
            .getPublicUrl(relativePath);

        if (publicUrl.isEmpty) {
          throw Exception("Failed to generate public URL for $uniqueFileName");
        }

        debugPrint("Public URL generated: $publicUrl");

        uploadedImageUrls.add(publicUrl);
      } catch (e) {
        debugPrint("Error uploading image: $e");
      }
    }

    debugPrint("All images processed successfully.");
    return uploadedImageUrls;
  }
   Map<String, dynamic> buildPropertyData({
    required TextEditingController typeController,
    required TextEditingController priceController,
    required TextEditingController bedroomsController,
    required TextEditingController bathroomsController,
    required TextEditingController areaController,
    required TextEditingController levelController,
    required TextEditingController compoundController,
    required TextEditingController cityController,
    required String? furnished,
    required String? paymentOption,
    required String? transactionType,
    required int? userId,
  }) {
    return {
      "type": typeController.text,
      "price": int.parse(priceController.text),
      "bedrooms": int.parse(bedroomsController.text),
      "bathrooms": int.parse(bathroomsController.text),
      "area": int.parse(areaController.text),
      "furnished": furnished,
      "level": levelController.text.isNotEmpty
          ? int.parse(levelController.text)
          : null,
      "compound": compoundController.text.isNotEmpty
          ? compoundController.text
          : "Unavailable",
      "payment_option": paymentOption,
      "city": cityController.text,
      "user_id": userId,
      "sale_rent": transactionType
    };
  }


  Future<List<Property>> fetchPropertiesFromIdsWithScores(
  List<Map<String, dynamic>> recommendedData
) async {
  try {
    final ids = recommendedData.map<int>((e) => e['id'] as int).toList();
    Map<int, double> scoreMap = {
      for (var e in recommendedData) e['id'] as int: (e['similarity_score'] as num).toDouble()
    };

    final response = await supabase
        .from('properties')
        .select('*')
        .filter('id', 'in', ids);

    if (response.isEmpty) return [];

    final List<Property> result = (response as List).map((json) {
      final property = Property.fromJson(json);
      property.similarityScore = scoreMap[property.id];
      return property;
    }).toList();

    result.sort((a, b) => b.similarityScore!.compareTo(a.similarityScore!));
    return result;
  } catch (e) {
    debugPrint("Error in fetchPropertiesFromIdsWithScores: $e");
    return [];
  }
}


Future<List<Property>> fetchApprovedProperties() async {
    try {
      final response = await supabase
          .from('properties')
          .select("*")
          .filter('status', 'eq', 'approved');

      if (response is List && response.isNotEmpty) {
        return response.map((entry) => Property.fromJson(entry)).toList();
      } else {
        return [];
      }
    } catch (e) {
      print("Error in PropertyController.fetchApprovedProperties: $e");
      rethrow;
    }
  }
List<Property> applySorting(List<Property> properties, String? sortOption) {
  if (sortOption == null) return properties;

  final sorted = List<Property>.from(properties);
  switch (sortOption) {
    case 'PriceLowHigh':
      sorted.sort((a, b) => a.price.compareTo(b.price));
      break;
    case 'PriceHighLow':
      sorted.sort((a, b) => b.price.compareTo(a.price));
      break;
    case 'BestSellers':
      // Add logic for best sellers if applicable
      break;
  }
  return sorted;
}


}