import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:multi_image_picker_plus/multi_image_picker_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class AddPropertyScreen extends StatefulWidget {
  @override
  _AddPropertyScreenState createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _bedroomsController = TextEditingController();
  final TextEditingController _bathroomsController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _levelController = TextEditingController();
  final TextEditingController _compoundController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  String? _furnished = "Yes";
  String? _paymentOption = "Cash";

  List<Asset> _selectedImages = [];
  List<String> _uploadedImageUrls = [];
  final Uuid uuid = Uuid();

  Future<void> _pickImages() async {
    try {
      setState(() {
        _selectedImages.clear();
      });

      final List<Asset> resultList = await MultiImagePicker.pickImages(
        androidOptions: const AndroidOptions(maxImages: 10),
      );

      if (resultList.isNotEmpty) {
        debugPrint("Images selected: ${resultList.length}");
        setState(() {
          _selectedImages = resultList;
        });
      } else {
        debugPrint("No images selected.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No images selected.")),
        );
      }
    } catch (e) {
      debugPrint("Error picking images: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _uploadImages() async {
    try {
      if (_selectedImages.isEmpty) {
        throw Exception("No images to upload");
      }

      for (var asset in _selectedImages) {
        final byteData = await asset.getByteData();
        final fileBytes = byteData.buffer.asUint8List();
        final uniqueFileName =
            "${uuid.v4()}_${asset.name.replaceAll(' ', '_')}";

        debugPrint("Preparing to upload image: $uniqueFileName...");
        debugPrint("File size: ${fileBytes.length} bytes");

        try {
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
            throw Exception(
                "Failed to generate public URL for $uniqueFileName");
          }

          debugPrint("Public URL generated: $publicUrl");

          setState(() {
            _uploadedImageUrls.add(publicUrl);
          });
        } catch (e) {
          debugPrint("Error uploading image: $uniqueFileName, Error: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error uploading $uniqueFileName: $e")),
          );
        }
      }

      debugPrint("All images processed successfully.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Images uploaded successfully.")),
      );
    } catch (e) {
      debugPrint("Error during image upload: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        final property = {
          "type": _typeController.text,
          "price": int.parse(_priceController.text),
          "bedrooms": int.parse(_bedroomsController.text),
          "bathrooms": int.parse(_bathroomsController.text),
          "area": int.parse(_areaController.text),
          "furnished": _furnished,
          "level": _levelController.text.isNotEmpty
              ? int.parse(_levelController.text)
              : null,
          "compound": _compoundController.text.isNotEmpty
              ? _compoundController.text
              : "Unavailable",
          "payment_option": _paymentOption,
          "city": _cityController.text,
          "img_url": _uploadedImageUrls,
        };

        await _uploadImages();

        await supabase.from('properties').insert(property);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Property added successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        await Future.delayed(const Duration(seconds: 4), () {
          Navigator.pushNamed(context, "/property-listings");
        });
      } catch (e) {
        debugPrint('Error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Property"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Property Details",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _typeController,
                decoration: const InputDecoration(
                  labelText: "Type",
                  prefixIcon: Icon(Icons.home),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? "Type is required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: "Price",
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value == null || value.isEmpty ? "Price is required" : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bedroomsController,
                      decoration: const InputDecoration(
                        labelText: "Bedrooms",
                        prefixIcon: Icon(Icons.bed),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value == null || value.isEmpty
                          ? "Bedrooms are required"
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _bathroomsController,
                      decoration: const InputDecoration(
                        labelText: "Bathrooms",
                        prefixIcon: Icon(Icons.bathroom),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value == null || value.isEmpty
                          ? "Bathrooms are required"
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(
                  labelText: "Area (sq ft)",
                  prefixIcon: Icon(Icons.square_foot),
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value == null || value.isEmpty ? "Area is required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _levelController,
                decoration: const InputDecoration(
                  labelText: "Level (optional)",
                  prefixIcon: Icon(Icons.layers),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _compoundController,
                decoration: const InputDecoration(
                  labelText: "Compound (optional)",
                  prefixIcon: Icon(Icons.location_city),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: "City",
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? "City is required" : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _furnished,
                decoration: const InputDecoration(
                  labelText: "Furnished",
                  prefixIcon: Icon(Icons.check),
                ),
                items: ["Yes", "No"]
                    .map((furnished) => DropdownMenuItem(
                          value: furnished,
                          child: Text(furnished),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _furnished = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _paymentOption,
                decoration: const InputDecoration(
                  labelText: "Payment Option",
                  prefixIcon: Icon(Icons.payment),
                ),
                items: ["Cash", "Installments"]
                    .map((option) => DropdownMenuItem(
                          value: option,
                          child: Text(option),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _paymentOption = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.image),
                    label: const Text("Pick Images"),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Selected: ${_selectedImages.length}",
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              // const SizedBox(height: 8),
              // ElevatedButton.icon(
              //   onPressed: _uploadImages,
              //   icon: const Icon(Icons.cloud_upload),
              //   label: const Text("Upload Images"),
              // ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                  ),
                  child: const Text(
                    "Add Property",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
