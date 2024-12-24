import 'package:flutter/material.dart';
import 'package:gradproj/Models/property.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddPropertyScreen extends StatefulWidget {
  @override
  _AddPropertyScreenState createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for form fields
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _bedroomsController = TextEditingController();
  final TextEditingController _bathroomsController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _levelController = TextEditingController();
  final TextEditingController _compoundController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _imgUrlController = TextEditingController();

  String? _furnished = "Yes";
  String? _paymentOption = "Cash";
  final supabase = Supabase.instance.client;

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final property = Property(
        type: _typeController.text,
        price: double.parse(_priceController.text),
        bedrooms: int.parse(_bedroomsController.text),
        bathrooms: int.parse(_bathroomsController.text),
        area: int.parse(_areaController.text),
        furnished: _furnished!,
        level: _levelController.text.isNotEmpty ? int.parse(_levelController.text) : null,
        compound: _compoundController.text.isNotEmpty ? _compoundController.text : null,
        paymentOption: _paymentOption!,
        city: _cityController.text,
        feedback: [],
        imgUrl: _imgUrlController.text.isNotEmpty ? _imgUrlController.text : null,
      );
      _addToSupabase(property);
    }
  }

  void _addToSupabase(Property property) async {
    try {
      final response = await supabase.from('properties').insert(property.toJson());

      if (response.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Property added successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error adding property")),
        );
      }
    } catch (e) {
      debugPrint('An unexpected error occurred: $e');
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
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _typeController,
                        decoration: const InputDecoration(
                          labelText: "Type",
                          prefixIcon: Icon(Icons.home),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return "Type is required";
                          return null;
                        },
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
                              validator: (value) {
                                if (value == null || value.isEmpty) return "Bedrooms are required";
                                return null;
                              },
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
                              validator: (value) {
                                if (value == null || value.isEmpty) return "Bathrooms are required";
                                return null;
                              },
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
                        validator: (value) {
                          if (value == null || value.isEmpty) return "Area is required";
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _furnished,
                        decoration: const InputDecoration(
                          labelText: "Furnished",
                          prefixIcon: Icon(Icons.check),
                        ),
                        items: ["Yes", "No"]
                            .map((furnished) =>
                                DropdownMenuItem(value: furnished, child: Text(furnished)))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _furnished = value!;
                          });
                        },
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
                      DropdownButtonFormField<String>(
                        value: _paymentOption,
                        decoration: const InputDecoration(
                          labelText: "Payment Option",
                          prefixIcon: Icon(Icons.payment),
                        ),
                        items: ["Cash", "Installments"]
                            .map((option) =>
                                DropdownMenuItem(value: option, child: Text(option)))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _paymentOption = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: "City",
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return "City is required";
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _imgUrlController,
                        decoration: const InputDecoration(
                          labelText: "Image URL (optional)",
                          prefixIcon: Icon(Icons.image),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "ADD PROPERTY",
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
