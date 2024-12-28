import 'package:flutter/material.dart';
import 'package:gradproj/models/Property.dart';

class PropertyCard extends StatelessWidget {
  final Property property;

  const PropertyCard({
    super.key,
    required this.property,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property image with placeholder handling
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                height: 680, // Adjust height as needed
                child: Image.network(
                  property.imgUrl?.isNotEmpty == true
                      ? property.imgUrl!.first
                      : 'https://agentrealestateschools.com/wp-content/uploads/2021/11/real-estate-property.jpg',
                  fit: BoxFit.cover, // Ensures the image fills the container
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint("Image failed to load: $error");
                    return const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 70,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            ),
            // Property details
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 0 , 50),
              child: 
                 Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Property name
                    Text(
                  
                      property.type,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),
                    // Property type and rent/sale
                    Text(
                      "${property.type} - ${property.paymentOption}",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Property price
                    Text(
                      "\$${property.price.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF398AE5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Property size
                    Text(
                      "${property.area} sqft",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Property location
                    Text(
                      "${property.city}, ${property.compound ?? 'Unknown Compound'}",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Number of rooms and bathrooms
                    Text(
                      "${property.bedrooms} Beds • ${property.bathrooms} Baths",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Furnished status
                    Text(
                      "Furnished: ${property.furnished}",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
          
          ],
        ),
      ),
    );
  }
}
