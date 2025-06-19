import '../Models/propertyClass.dart';
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

    double? similarityScore = property.similarityScore;
    bool hasValidScore = similarityScore != null && similarityScore > 0;
    String similarityText = hasValidScore
        ? "${(similarityScore * 100).toStringAsFixed(1)}%"
        : "";

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: theme.cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              'ID: ${property.id}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: hasValidScore ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
              children: [
                Text(
                  '\$${property.price.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Color.fromARGB(255, 8, 145, 236),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (hasValidScore) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color.fromARGB(255, 8, 145, 236),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Score: $similarityText',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color.fromARGB(255, 255, 255, 255),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
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
