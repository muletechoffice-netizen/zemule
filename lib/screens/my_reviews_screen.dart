import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:zemule/models/review.dart';
import 'package:zemule/providers/user_provider.dart';
import 'package:zemule/services/auth_service.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = _authService.currentUser;
      if (user == null || !mounted) {
        return;
      }
      context.read<UserProvider>().loadMyReviews(user.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('My Reviews')),
      body: RefreshIndicator(
        onRefresh: () async {
          final user = _authService.currentUser;
          if (user == null) {
            return;
          }
          await context.read<UserProvider>().loadMyReviews(user.uid);
        },
        child: provider.myReviews.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('No reviews yet')),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: provider.myReviews.length,
                itemBuilder: (_, index) {
                  final review = provider.myReviews[index];
                  return _ReviewItem(review: review);
                },
              ),
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final businessName = provider.businessNameFor(review.businessId);
    final businessPhoto = provider.businessPhotoFor(review.businessId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: businessPhoto?.isNotEmpty == true
                        ? CachedNetworkImage(
                            imageUrl: businessPhoto!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(Icons.store),
                          )
                        : Container(
                            color: Theme.of(context).colorScheme.surface,
                            child: const Icon(Icons.storefront_outlined),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    businessName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(DateFormat('dd MMM yyyy').format(review.createdAt)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: List<Widget>.generate(
                5,
                (index) => Icon(
                  index < review.rating ? Icons.star : Icons.star_border,
                  color: Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(review.comment),
            if (review.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.photoUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: review.photoUrls[index],
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 76,
                        height: 76,
                        color: Theme.of(context).colorScheme.surface,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => _showEditDialog(context, review),
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: () => context.read<UserProvider>().deleteReview(review.id),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, Review review) async {
    final commentController = TextEditingController(text: review.comment);
    int rating = review.rating;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit review'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: List<Widget>.generate(
                      5,
                      (index) => IconButton(
                        onPressed: () => setState(() => rating = index + 1),
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Comment',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave != true || !context.mounted) {
      return;
    }

    await context.read<UserProvider>().updateReview(
      review.id,
      rating: rating,
      comment: commentController.text,
    );
  }
}
