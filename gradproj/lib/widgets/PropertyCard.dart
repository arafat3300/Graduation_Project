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
