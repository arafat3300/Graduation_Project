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
    // Get the current theme
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      child: Card(
        elevation: 10,
        // Use theme-aware colors for the card
        color: theme.cardColor,
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
              child: SizedBox(
                width: double.infinity,
                height: 680,
                child: Image.network(
                  property.imgUrl?.isNotEmpty == true
                      ? property.imgUrl!.first
                      : 'https://agentrealestateschools.com/wp-content/uploads/2021/11/real-estate-property.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint("Image failed to load: $error");
                    return Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 70,
                        // Use theme-aware color for the error icon
                        color: theme.disabledColor,
                      ),
                    );
                  },
                ),
              ),
            ),
            // Property details
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 0, 50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Property name
                  Text(
                    property.type,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 24),
                  // Property type and rent/sale
                  Text(
                    "${property.type} - ${property.paymentOption}",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Property price
                  Text(
                    "\$${property.price.toStringAsFixed(2)}",
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF398AE5),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Property size
                  Text(
                    "${property.area} sqft",
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  // Property location
                  Text(
                    "${property.city}, ${property.compound ?? 'Unknown Compound'}",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Number of rooms and bathrooms
                  Text(
                    "${property.bedrooms} Beds • ${property.bathrooms} Baths",
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  // Furnished status
                  Text(
                    "Furnished: ${property.furnished}",
                    style: theme.textTheme.bodySmall,
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