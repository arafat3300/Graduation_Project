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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    
    return Card(
      elevation: 5,
      // Use surfaceVariant color for card background
      color: theme.colorScheme.surfaceVariant,
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
                      // Use theme's disabled color for error icon
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
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
                          style: textTheme.titleLarge?.copyWith(
                            fontSize: isPortrait ? 24 : 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "\$${property.price.toStringAsFixed(0)}",
                        style: textTheme.titleLarge?.copyWith(
                          fontSize: isPortrait ? 24 : 11,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: isPortrait ? 4 : 2),
                  
                  // Payment Option
                  Text(
                    property.paymentOption,
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: isPortrait ? 13 : 10,
                      color: theme.colorScheme.onSurfaceVariant,
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
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: isPortrait ? 12 : 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "${property.area}sqft",
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: isPortrait ? 12 : 10,
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
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: isPortrait ? 12 : 10,
                        ),
                      ),
                      Text(
                        property.furnished,
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: isPortrait ? 12 : 10,
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