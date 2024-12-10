import 'package:flutter/material.dart';
import 'package:gradproj/models/Property.dart';

class PropertyCard extends StatelessWidget {
  final Property property;
  // final List<Color> gradientColors;

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
            // Property image with gradient overlay
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Image.network(
                    "${property.imgUrl}",
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                       
                        return Image.asset(
                          'assets/images/listingPlaceholder.jpg', 
                          fit: BoxFit.cover,
                          width: double.infinity,
                        );
                      },
                    ),
                  ),
                  // Gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        // gradient: LinearGradient(
                        //   colors: gradientColors,
                        //   begin: Alignment.topCenter,
                        //   end: Alignment.bottomCenter,
                        //   stops: const [0.5, 1.0],
                        // ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Property name
                  Text(
                    property.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Property type and rent/sale
                  Text(
                    "${property.type} - ${property.rentOrSale}",
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
                    "${property.sqft} sqft",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Property location
                  Text(
                    "${property.city}, ${property.location}",
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
                    "${property.rooms} Beds • ${property.toilets} Baths",
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
