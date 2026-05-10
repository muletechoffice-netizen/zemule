import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zemule/providers/business_detail_provider.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review});

  final BusinessReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final displayName = review.userName.trim().isEmpty
        ? 'Anonymous'
        : review.userName.trim();
    final initial = displayName.substring(0, 1).toUpperCase();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colors.primary.withValues(alpha: 0.12),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          ...List<Widget>.generate(5, (index) {
                            final filled = index < review.rating.round();
                            return Icon(
                              Icons.star,
                              size: 16,
                              color: filled
                                  ? Colors.orange
                                  : Colors.grey.withValues(alpha: 0.4),
                            );
                          }),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMM d, y').format(review.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (review.comment.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(review.comment),
            ],
            if (review.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 82,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.photoUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final url = review.photoUrls[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        width: 82,
                        height: 82,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 82,
                          height: 82,
                          color: colors.surface,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
