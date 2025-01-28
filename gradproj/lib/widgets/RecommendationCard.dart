import '../models/Property.dart';
import 'package:flutter/material.dart';
import '../Screens/PropertyDetails.dart';

class RecommendationCard extends StatelessWidget {
  final Property property;

  const RecommendationCard({
    Key? key,
    required this.property,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ✅ Correctly fetch similarity score
    double? similarityScore = property.similarityScore;
    String similarityText = similarityScore != null && similarityScore > 0
        ? "Similarity: ${(similarityScore * 100).toStringAsFixed(1)}%"  // ✅ Correct display
        : "Similarity: N/A";  // ✅ Show "N/A" instead of 0.0%

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: theme.cardColor,
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            property.imgUrl?.isNotEmpty == true
                ? property.imgUrl!.first
                : 'https://agentrealestateschools.com/wp-content/uploads/2021/11/real-estate-property.jpg',
            width: 70,
            height: 70,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Icon(Icons.broken_image, size: 70, color: theme.colorScheme.error),
          ),
        ),
        title: Text(
          property.type,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              property.city,
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              '\$${property.price.toStringAsFixed(2)}',  // ✅ Show price
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              similarityText,  // ✅ Show similarity score correctly
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PropertyDetails(property: property),
            ),
          );
        },
      ),
    );
  }
}
