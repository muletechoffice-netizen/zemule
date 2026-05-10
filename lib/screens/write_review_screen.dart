import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:zemule/models/business.dart';
import 'package:zemule/providers/review_provider.dart';
import 'package:zemule/services/supabase_service.dart';

class WriteReviewScreen extends StatefulWidget {
  const WriteReviewScreen({super.key, required this.businessId});

  final String businessId;

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final SupabaseService _supabase = SupabaseService.instance;
  final TextEditingController _commentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final int _maxPhotos = 3;
  final int _maxChars = 500;

  int _rating = 0;
  bool _isAnonymous = false;
  List<File> _photos = <File>[];
  late final Future<Business?> _businessFuture;

  @override
  void initState() {
    super.initState();
    _businessFuture = _loadBusiness();
    _commentController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReviewProvider>();
    final canSubmit = _rating > 0 && !provider.isLoading;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Write Review'),
        actions: [
          TextButton(
            onPressed: canSubmit ? () => _submit(provider) : null,
            child: Text(
              'Submit',
              style: TextStyle(
                color: canSubmit ? colorScheme.onPrimary : colorScheme.onPrimary.withValues(alpha: 0.6),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBusinessSummary(),
            const SizedBox(height: 20),
            _buildRatingSection(),
            const SizedBox(height: 20),
            _buildCommentSection(),
            const SizedBox(height: 20),
            _buildPhotosSection(),
            const SizedBox(height: 14),
            CheckboxListTile(
              value: _isAnonymous,
              contentPadding: EdgeInsets.zero,
              title: const Text('Post anonymously'),
              onChanged: (value) {
                setState(() {
                  _isAnonymous = value ?? false;
                });
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: canSubmit ? () => _submit(provider) : null,
            child: provider.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit Review'),
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessSummary() {
    return FutureBuilder<Business?>(
      future: _businessFuture,
      builder: (_, snapshot) {
        final business = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (business == null) {
          return const SizedBox.shrink();
        }

        final imageUrl = business.photoUrls.isNotEmpty ? business.photoUrls.first : null;

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pushNamed(
              context,
              '/business-detail',
              arguments: widget.businessId,
            );
          },
          child: Ink(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 62,
                    height: 62,
                    child: imageUrl == null
                        ? Container(
                            color: Colors.grey.withValues(alpha: 0.12),
                            child: const Icon(Icons.storefront_outlined),
                          )
                        : CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.grey.withValues(alpha: 0.12),
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        business.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (business.mainCategory.isNotEmpty) business.mainCategory,
                          if (business.subcategory.isNotEmpty) business.subcategory,
                        ].where((e) => e.isNotEmpty).join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tap to rate',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 12),
        RatingBar.builder(
          initialRating: _rating.toDouble(),
          minRating: 1,
          direction: Axis.horizontal,
          allowHalfRating: false,
          itemCount: 5,
          itemSize: 40,
          itemBuilder: (_, __) => const Icon(Icons.star, color: Colors.orange),
          onRatingUpdate: (value) {
            setState(() {
              _rating = value.toInt();
            });
          },
        ),
        const SizedBox(height: 6),
        Text(_rating == 0 ? 'No rating selected' : '$_rating stars'),
      ],
    );
  }

  Widget _buildCommentSection() {
    final count = _commentController.text.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your review',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _commentController,
          minLines: 3,
          maxLines: 10,
          maxLength: _maxChars,
          decoration: const InputDecoration(
            hintText: 'Share your experience... What did you like? What could improve?',
            border: OutlineInputBorder(),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text('$count/$_maxChars'),
        ),
      ],
    );
  }

  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add photos (optional)',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _AddPhotoBox(
                enabled: _photos.length < _maxPhotos,
                onTap: _photos.length < _maxPhotos ? _pickPhoto : null,
              ),
              const SizedBox(width: 10),
              ..._photos.asMap().entries.map((entry) {
                final index = entry.key;
                final file = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          file,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _photos = List<File>.from(_photos)..removeAt(index);
                            });
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black54,
                            ),
                            padding: const EdgeInsets.all(3),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 78,
        maxWidth: 1500,
      );
      if (!mounted || picked == null) {
        return;
      }

      setState(() {
        if (_photos.length < _maxPhotos) {
          _photos = <File>[..._photos, File(picked.path)];
        }
      });
    } on PlatformException {
      _showErrorSafe(
        source == ImageSource.camera
            ? 'Unable to access camera. Check camera permission and try again.'
            : 'Unable to access gallery. Check photos permission and try again.',
      );
    } catch (_) {
      _showErrorSafe(
        source == ImageSource.camera
            ? 'Failed to capture photo. Please try again.'
            : 'Failed to select photo. Please try again.',
      );
    }
  }

  Future<void> _submit(ReviewProvider provider) async {
    final success = await provider.submitReview(
      businessId: widget.businessId,
      rating: _rating,
      comment: _commentController.text.trim(),
      photos: _photos,
      isAnonymous: _isAnonymous,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted successfully')),
      );
      Navigator.of(context).pop(true);
      return;
    }

    final message = provider.error ?? 'Failed to submit review.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => _submit(provider),
        ),
      ),
    );
  }

  Future<Business?> _loadBusiness() async {
    try {
      final row = await _supabase.getBusinessById(widget.businessId);
      if (row == null) {
        return null;
      }
      return Business.fromMap(row);
    } catch (_) {
      return null;
    }
  }

  void _showErrorSafe(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      debugPrint('WriteReviewScreen snack error: $message');
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AddPhotoBox extends StatelessWidget {
  const _AddPhotoBox({required this.enabled, this.onTap});

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Ink(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.35)),
          color: enabled ? Colors.grey.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.18),
        ),
        child: Icon(
          Icons.add_a_photo_outlined,
          color: enabled ? Colors.grey.shade700 : Colors.grey.shade500,
        ),
      ),
    );
  }
}
