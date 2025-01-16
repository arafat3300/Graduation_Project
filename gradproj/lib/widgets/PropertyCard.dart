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
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 5,
      color: isDark ? Colors.grey[850] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
            child: AspectRatio(
              aspectRatio: isPortrait ? 16/9 : 16/10,
              child: Image.network(
                property.imgUrl?.isNotEmpty == true
                    ? property.imgUrl!.first
                    : 'https://agentrealestateschools.com/wp-content/uploads/2021/11/real-estate-property.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 40,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Property details
          Flexible(
            child: Padding(
              padding: EdgeInsets.all(isPortrait ? 8.0 : 6.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Price Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          property.type,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isPortrait ? 24 : 12,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "\$${property.price.toStringAsFixed(0)}",
                        style: TextStyle(
                          fontSize: isPortrait ? 24 : 11,
                          color: isDark ? Colors.lightBlue[300] : const Color(0xFF398AE5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: isPortrait ? 4 : 2),
                  
                  // Payment Option
                  Text(
                    property.paymentOption,
                    style: TextStyle(
                      fontSize: isPortrait ? 13 : 10,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  SizedBox(height: isPortrait ? 4 : 2),
                  
                  // Location and Area Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "${property.city}",
                          style: TextStyle(
                            fontSize: isPortrait ? 12 : 10,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "${property.area}sqft",
                        style: TextStyle(
                          fontSize: isPortrait ? 12 : 10,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: isPortrait ? 4 : 2),
                  
                  // Beds, Baths and Furnished Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${property.bedrooms}B ${property.bathrooms}B",
                        style: TextStyle(
                          fontSize: isPortrait ? 12 : 10,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      Text(
                        property.furnished,
                        style: TextStyle(
                          fontSize: isPortrait ? 12 : 10,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}