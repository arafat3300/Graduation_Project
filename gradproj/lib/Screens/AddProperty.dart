import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gradproj/Models/singletonSession.dart';
import 'package:multi_image_picker_plus/multi_image_picker_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

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
  int? _userId = singletonSession().userId;

  List<Asset> _selectedImages = [];
  final List<String> _uploadedImageUrls = [];
  final Uuid uuid = const Uuid();

  File? _capturedImage;
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickImages() async {
    try {
      final List<Asset> resultList = await MultiImagePicker.pickImages(
        androidOptions: const AndroidOptions(maxImages: 10),
      );

      if (resultList.isNotEmpty) {
        setState(() {
          _selectedImages = resultList;
        });
      }
    } catch (e) {
      debugPrint("Error picking images: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _captureImage() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (photo != null) {
        setState(() {
          _capturedImage = File(photo.path);
        });
      }
    } catch (e) {
      debugPrint("Error capturing image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _uploadCapturedImage() async {
    if (_capturedImage == null) return;

    try {
      final fileBytes = await _capturedImage!.readAsBytes();
      final uniqueFileName = "${uuid.v4()}_${_capturedImage!.path.split('/').last}";

      final filePath = await supabase.storage
          .from('properties-images')
          .uploadBinary(uniqueFileName, fileBytes);

      final publicUrl = supabase.storage
          .from('properties-images')
          .getPublicUrl(filePath.replaceFirst('properties-images/', ''));

      setState(() {
        _uploadedImageUrls.add(publicUrl);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image captured and uploaded successfully.")),
      );
    } catch (e) {
      debugPrint("Error uploading captured image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _uploadImages() async {
    if (_selectedImages.isEmpty) return;

    for (var asset in _selectedImages) {
      try {
        final byteData = await asset.getByteData();
        final fileBytes = byteData.buffer.asUint8List();
        final uniqueFileName = "${uuid.v4()}_${asset.name.replaceAll(' ', '_')}";

        final filePath = await supabase.storage
            .from('properties-images')
            .uploadBinary(uniqueFileName, fileBytes);

        final publicUrl = supabase.storage
            .from('properties-images')
            .getPublicUrl(filePath.replaceFirst('properties-images/', ''));

        setState(() {
          _uploadedImageUrls.add(publicUrl);
        });
      } catch (e) {
        debugPrint("Error uploading image: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading image: $e")),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _uploadImages();

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
          "user_id": _userId,
        };

        await supabase.from('properties').insert(property);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Property added successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushNamed(context, "/property-listings");
      } catch (e) {
        debugPrint("Error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.image),
                    label: const Text("Pick Images"),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _captureImage();
                      await _uploadCapturedImage();
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Capture Image"),
                  ),
                ],
              ),
              if (_capturedImage != null) ...[
                const SizedBox(height: 16),
                Image.file(
                  _capturedImage!,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ],
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _submitForm,
                  child: const Text("Add Property"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
