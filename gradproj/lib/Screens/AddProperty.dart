import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gradproj/Controllers/property_controller.dart';
import 'package:gradproj/Models/singletonSession.dart';
import 'package:multi_image_picker_plus/multi_image_picker_plus.dart';
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
  final TextEditingController _downPaymentController = TextEditingController();
  final TextEditingController _installmentYearsController = TextEditingController();

final PropertyController _propertyController = PropertyController(Supabase.instance.client);

  String? _furnished = "Yes";
  String? _paymentOption = "Cash";
  String? _transactionType;
  String? _deliveryYear = "2025";
  String? _finishing = "semi finished";
  int? _userId = singletonSession().userId;

  List<Asset> _selectedImages = [];
  final List<String> _uploadedImageUrls = [];
  final Uuid uuid = const Uuid();

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
    List<String> uploadedUrls = await _propertyController.uploadImages(_selectedImages);

    setState(() {
      _uploadedImageUrls.addAll(uploadedUrls); 
    });

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
      final property = _propertyController.buildPropertyData(
        typeController: _typeController,
        priceController: _priceController,
        bedroomsController: _bedroomsController,
        bathroomsController: _bathroomsController,
        areaController: _areaController,
        levelController: _levelController,
        compoundController: _compoundController,
        cityController: _cityController,
        furnished: _furnished,
        paymentOption: _paymentOption,
        transactionType: _transactionType,
        userId: _userId,
        downPayment: _transactionType == "sale" ? double.tryParse(_downPaymentController.text) : null,
        installmentYears: _transactionType == "sale" ? int.tryParse(_installmentYearsController.text) : null,
        deliveryIn: _transactionType == "sale" ? int.tryParse(_deliveryYear ?? "2025") : null,
        finishing: _transactionType == "sale" ? _finishing : null,
      );

      bool success = await _propertyController.submitPropertyForm(
        property: property,
        selectedImages: _selectedImages,
        onImagesUploaded: (uploadedUrls) {
          setState(() {
            _uploadedImageUrls.addAll(uploadedUrls);
          });
        },
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Property added successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        Future.delayed(const Duration(seconds: 4), () {
          Navigator.pushNamed(context, "/property-listings");
        });
      } else {
        throw Exception("Failed to add property.");
      }
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
              DropdownButtonFormField<String>(
                value: _transactionType,
                decoration: const InputDecoration(
                  labelText: "Transaction Type",
                  prefixIcon: Icon(Icons.business),
                ),
                items: ["sale", "rent"]
                    .map((option) => DropdownMenuItem(
                          value: option,
                          child: Text(option),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _transactionType = value;
                  });
                },
                validator: (value) => value == null || value.isEmpty
                    ? "Transaction type is required"
                    : null,
              ),
              if (_transactionType == "sale") ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _downPaymentController,
                  decoration: const InputDecoration(
                    labelText: "Down Payment (%)",
                    prefixIcon: Icon(Icons.payments),
                    hintText: "Type in a percentage",
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Down payment is required for sale";
                    }
                    final percentage = double.tryParse(value);
                    if (percentage == null || percentage <= 0 || percentage > 100) {
                      return "Please enter a valid percentage between 0 and 100";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _installmentYearsController,
                  decoration: const InputDecoration(
                    labelText: "Installment Years",
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Installment years is required for sale";
                    }
                    final years = int.tryParse(value);
                    if (years == null || years <= 0) {
                      return "Please enter a valid number of years";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _deliveryYear,
                  decoration: const InputDecoration(
                    labelText: "Delivery Year",
                    prefixIcon: Icon(Icons.event),
                  ),
                  items: List.generate(8, (index) => (2025 + index).toString())
                      .map((year) => DropdownMenuItem(
                            value: year,
                            child: Text(year),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _deliveryYear = value;
                    });
                  },
                  validator: (value) => value == null || value.isEmpty
                      ? "Delivery year is required for sale"
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _finishing,
                  decoration: const InputDecoration(
                    labelText: "Finishing",
                    prefixIcon: Icon(Icons.home_work),
                  ),
                  items: ["semi finished", "fully finished", "unfinished"]
                      .map((finish) => DropdownMenuItem(
                            value: finish,
                            child: Text(finish),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _finishing = value;
                    });
                  },
                  validator: (value) => value == null || value.isEmpty
                      ? "Finishing is required for sale"
                      : null,
                ),
              ],
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