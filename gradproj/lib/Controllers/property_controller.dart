import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:multi_image_picker_plus/multi_image_picker_plus.dart';
import 'package:uuid/uuid.dart';

import 'package:postgres/postgres.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../Models/propertyClass.dart';
import '../config/database_config.dart';

class PropertyController {
    final Uuid uuid = const Uuid();
    final SupabaseClient supabase;
    PostgreSQLConnection? _connection;
    bool _isConnected = false;

    PropertyController(this.supabase) {
        _initializeConnection();
    }

    Future<void> _initializeConnection() async {
        try {
            debugPrint('\nGetting shared database connection...');
            _connection = await DatabaseConfig.getConnection();
            _isConnected = true;
            print('Successfully connected to PostgreSQL database');
        } catch (e) {
            print('Error connecting to PostgreSQL: $e');
        }
    }

    Future<List<Property>> getUserPropertiesWithDetails(int userId) async {
        try {
            if (!_isConnected) await _initializeConnection();
            
            final results = await _connection!.query(
                'SELECT * FROM real_estate_property WHERE user_id = @userId',
                substitutionValues: {'userId': userId},
            );

            if (results.isEmpty) {
                return [];
            }

            return results.map((data) => Property.fromJson(data.toColumnMap())).toList();
        } catch (e) {
            debugPrint("Error fetching user properties: $e");
            return [];
        }
    }

    Future<List<Property>> getPendingProperties() async {
        try {
            if (!_isConnected) await _initializeConnection();
            
            final results = await _connection!.query(
                'SELECT * FROM real_estate_property WHERE status = @status',
                substitutionValues: {'status': 'pending'},
            );

            if (results.isEmpty) {
                return [];
            }

            return results.map((data) => Property.fromJson(data.toColumnMap())).toList();
        } catch (e) {
            debugPrint("Error fetching pending properties: $e");
            return [];
        }
    }

    Future<List<Property>> getApprovedProperties() async {
        try {
            if (!_isConnected) await _initializeConnection();
            
            final results = await _connection!.query(
                'SELECT * FROM real_estate_property WHERE status = @status',
                substitutionValues: {'status': 'approved'},
            );

            if (results.isEmpty) {
                return [];
            }

            return results.map((data) => Property.fromJson(data.toColumnMap())).toList();
        } catch (e) {
            debugPrint("Error fetching approved properties: $e");
            return [];
        }
    }

    Future<bool> deleteProperty(int propertyId) async {
        try {
            if (!_isConnected) await _initializeConnection();
            
            await _connection!.execute(
                'DELETE FROM real_estate_property WHERE id = @propertyId',
                substitutionValues: {'propertyId': propertyId},
            );
            debugPrint("Property deleted successfully");
            return true;
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
            // Upload images to Supabase and get URLs
            List<String> uploadedImageUrls = await uploadImages(selectedImages);
            onImagesUploaded(uploadedImageUrls);

            // Add image URLs to property data as a PostgreSQL array
            property["img_url"] = '{${uploadedImageUrls.join(',')}}';  // Format as PostgreSQL array

            if (!_isConnected) await _initializeConnection();
            debugPrint("Inserting property: $property");
            
            // Insert property into PostgreSQL with Supabase image URLs
            await _connection!.execute(
                '''
                INSERT INTO real_estate_property (
                    type, price, bedrooms, bathrooms, area, furnished,
                    level, compound, payment_option, city, user_id,
                    sale_rent, img_url, status
                ) VALUES (
                    @type, @price, @bedrooms, @bathrooms, @area, @furnished,
                    @level, @compound, @paymentOption, @city, @userId,
                    @saleRent, @imgUrl, 'pending'
                )
                ''',
                substitutionValues: {
                    'type': property['type'],
                    'price': property['price'],
                    'bedrooms': property['bedrooms'],
                    'bathrooms': property['bathrooms'],
                    'area': property['area'],
                    'furnished': property['furnished'],
                    'level': property['level'],
                    'compound': property['compound'],
                    'paymentOption': property['payment_option'],
                    'city': property['city'],
                    'userId': property['user_id'],
                    'saleRent': property['sale_rent'],
                    'imgUrl': property['img_url'],  // Now formatted as an array
                },
            );

            return true;
        } catch (e) {
            debugPrint("Error submitting form: $e");
            return false;
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

                // Upload to Supabase storage
                final filePath = await supabase.storage
                    .from('properties-images')
                    .uploadBinary(uniqueFileName, fileBytes);

                if (filePath.isEmpty) {
                    throw Exception("Upload failed for $uniqueFileName");
                }

                debugPrint("Image uploaded successfully: $filePath");

                final relativePath = filePath.replaceFirst('properties-images/', '');

                // Get public URL from Supabase
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

            if (!_isConnected) await _initializeConnection();
            
            final results = await _connection!.query(
                'SELECT * FROM real_estate_property WHERE id = ANY(@ids)',
                substitutionValues: {'ids': ids},
            );

            final List<Property> result = results.map((data) {
                final property = Property.fromJson(data.toColumnMap());
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

    Future<void> dispose() async {
        if (_isConnected && _connection != null) {
            await _connection!.close();
            _isConnected = false;
            print('Disconnected from PostgreSQL database');
        }
    }

    Future<List<Property>> fetchApprovedProperties() async {
        try {
            if (!_isConnected) await _initializeConnection();
            
            final results = await _connection!.query(
                '''
                SELECT * FROM real_estate_property
                WHERE status = 'approved'
                '''
            );
            
            return results.map((data) => Property.fromJson(data.toColumnMap())).toList();
        } catch (e) {
            debugPrint('Error fetching approved properties: $e');
            return [];
        }
    }
}