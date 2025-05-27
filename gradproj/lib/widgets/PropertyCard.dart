import 'package:flutter/material.dart';
import '../Models/propertyClass.dart';

class PropertyCard extends StatelessWidget {
  final Property property;

  const PropertyCard({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      elevation: 8,
      shadowColor: theme.colorScheme.primary.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                property.imgUrl?.isNotEmpty == true
                    ? property.imgUrl!.first
                    : 'https://agentrealestateschools.com/wp-content/uploads/2021/11/real-estate-property.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: theme.colorScheme.surfaceVariant,
                    alignment: Alignment.center,
                    child: Icon(Icons.broken_image, size: 60, color: Colors.grey.shade400),
                  );
                },
              ),
            ),
          ),
// const SizedBox(height:30),
          // Property Info 
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                _buildRow([
                  _buildLabeledColumn(Icons.home, "Type", property.type, theme, textTheme),
                  _buildLabeledColumn(Icons.attach_money, "Price", "\$${property.price.toStringAsFixed(0)}", theme, textTheme),
                ]),
                _buildRow([
                  _buildLabeledColumn(Icons.payment, "Payment", property.paymentOption, theme, textTheme),
                  _buildLabeledColumn(Icons.location_on, "City", property.city, theme, textTheme),
                ]),
                _buildRow([
                  _buildLabeledColumn(Icons.square_foot, "Area", "${property.area} sqft", theme, textTheme),
                  _buildLabeledColumn(Icons.king_bed, "Bedrooms", "${property.bedrooms}", theme, textTheme),
                ]),
                _buildRow([
                  _buildLabeledColumn(Icons.bathtub, "Bathrooms", "${property.bathrooms}", theme, textTheme),
                  _buildLabeledColumn(Icons.chair, "Furnished", property.furnished, theme, textTheme),
                ]),
                _buildRow([
                  _buildLabeledColumn(Icons.sell, "Transaction", property.sale_rent, theme, textTheme),
                  _buildLabeledColumn(Icons.tag, "Property ID", property.id.toString(), theme, textTheme),
                ]),
                if (property.sale_rent == "sale") ...[
                  _buildRow([
                    _buildLabeledColumn(Icons.payments, "Down Payment", "${property.downPayment?.toStringAsFixed(1)}%", theme, textTheme),
                    _buildLabeledColumn(Icons.calendar_today, "Installment Years", "${property.installmentYears ?? 'N/A'}", theme, textTheme),
                  ]),
                  _buildRow([
                    _buildLabeledColumn(Icons.event, "Delivery Year", "${property.deliveryIn ?? 'N/A'}", theme, textTheme),
                    _buildLabeledColumn(Icons.home_work, "Finishing", property.finishing ?? "N/A", theme, textTheme),
                  ]),
                ],
              ],
            ),
          ),
          // Amenities Section
          if (property.amenities != null && property.amenities!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Amenities",
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12.0,
                    runSpacing: 8.0,
                    children: property.amenities!.map((amenity) {
                      IconData iconData = Icons.category; // Default icon
                      switch (amenity.toLowerCase()) {
                        case 'clubhouse':
                          iconData = Icons.golf_course;
                          break;
                        case 'schools':
                          iconData = Icons.school;
                          break;
                        case 'business hub':
                          iconData = Icons.business_center;
                          break;
                        case 'sports clubs':
                          iconData = Icons.sports_baseball;
                          break;
                        case 'mosque':
                          iconData = Icons.mosque;
                          break;
                        case 'disability support':
                          iconData = Icons.accessible;
                          break;
                         case 'bicycles lanes':
                          iconData = Icons.directions_bike;
                          break;
                         case 'pool':
                          iconData = Icons.pool;
                          break;
                        case 'gym':
                          iconData = Icons.fitness_center;
                          break;
                        case 'parking':
                          iconData = Icons.local_parking;
                          break;
                        case 'balcony':
                          iconData = Icons.balcony;
                          break;
                        case 'garden':
                          iconData = Icons.local_florist;
                          break;
                        case 'fireplace':
                          iconData = Icons.fireplace;
                          break;
                        case 'elevator':
                          iconData = Icons.elevator;
                          break;
                        case 'storage':
                          iconData = Icons.storage;
                          break;
                        case 'dishwasher':
                          iconData = Icons.kitchen;
                          break;
                        case 'hardwood':
                          iconData = Icons.texture;
                          break;
                        case 'security':
                          iconData = Icons.security;
                          break;
                        case 'concierge':
                          iconData = Icons.room_service;
                          break;
                        case 'doorman':
                          iconData = Icons.vpn_key;
                          break;
                        case 'sauna':
                          iconData = Icons.hot_tub;
                          break;
                        case 'spa':
                          iconData = Icons.spa;
                          break;
                        case 'playground':
                          iconData = Icons.child_friendly;
                          break;
                        case 'rooftop':
                          iconData = Icons.roofing;
                          break;
                        case 'garage':
                          iconData = Icons.garage;
                          break;
                        case 'wifi':
                          iconData = Icons.wifi;
                          break;
                        case 'laundry':
                          iconData = Icons.local_laundry_service;
                          break;
                        // Add more cases for other amenities
                      }
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(iconData, size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            amenity,
                            style: textTheme.bodyMedium,
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: children,
      ),
    );
  }

  Widget _buildLabeledColumn(IconData icon, String label, String value, ThemeData theme, TextTheme textTheme) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 26, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(value, style: textTheme.bodyLarge?.copyWith(fontSize: 18, color: theme.colorScheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
