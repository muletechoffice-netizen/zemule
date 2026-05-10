import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zemule/models/business.dart';
import 'package:zemule/providers/business_provider.dart';
import 'package:zemule/providers/business_detail_provider.dart';
import 'package:zemule/services/analytics_service.dart';
import 'package:zemule/widgets/review_card.dart';

class BusinessDetailScreen extends StatefulWidget {
  const BusinessDetailScreen({super.key, required this.businessId});

  final String businessId;

  @override
  State<BusinessDetailScreen> createState() => _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends State<BusinessDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _reviewsKey = GlobalKey();
  final PageController _pageController = PageController();
  final AnalyticsService _analyticsService = AnalyticsService();
  int _currentImagePage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<BusinessDetailProvider>().initialize();
      _analyticsService.trackBusinessView(widget.businessId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessDetailProvider>();
    final business = provider.business;

    return Scaffold(
      appBar: AppBar(
        title: Text(business?.name ?? 'Business Details'),
        actions: [
          IconButton(
            onPressed: business == null
                ? null
                : () async {
                    await provider.shareBusiness();
                  },
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            onPressed: business == null
                ? null
                : () async {
                    await provider.toggleFavoriteStatus();
                  },
            icon: Icon(
              provider.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: provider.isFavorite ? Colors.red : null,
            ),
          ),
        ],
      ),
      body: provider.isLoading && business == null
          ? const Center(child: CircularProgressIndicator())
          : provider.errorMessage != null && business == null
          ? Center(child: Text(provider.errorMessage!))
          : business == null
          ? const Center(child: Text('Business not found'))
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImageGallery(context, business),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBusinessInfo(context, provider, business),
                        const SizedBox(height: 16),
                        _buildActionButtons(context, business),
                        const SizedBox(height: 20),
                        _buildAboutSection(provider, business),
                        const SizedBox(height: 20),
                        _buildServicesSection(provider),
                        const SizedBox(height: 20),
                        _buildLocationSection(context, business),
                        const SizedBox(height: 20),
                        _buildReviewsSection(context, provider, business),
                        const SizedBox(height: 20),
                        _buildSimilarBusinesses(context, provider),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildImageGallery(BuildContext context, Business business) {
    final photos = business.photoUrls;
    final colors = Theme.of(context).colorScheme;

    if (photos.isEmpty) {
      return Container(
        width: double.infinity,
        height: 230,
        color: colors.surface,
        alignment: Alignment.center,
        child: Icon(
          Icons.storefront_outlined,
          size: 48,
          color: colors.primary.withValues(alpha: 0.75),
        ),
      );
    }

    return Stack(
      children: [
        SizedBox(
          height: 230,
          child: PageView.builder(
            controller: _pageController,
            itemCount: photos.length,
            onPageChanged: (index) {
              setState(() {
                _currentImagePage = index;
              });
            },
            itemBuilder: (_, index) {
              final url = photos[index];
              return GestureDetector(
                onTap: () => _showFullScreenImage(context, url),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, __) => Container(
                    color: colors.surface,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: colors.surface,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(photos.length, (index) {
              final selected = _currentImagePage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: selected ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.white70,
                  borderRadius: BorderRadius.circular(20),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessInfo(
    BuildContext context,
    BusinessDetailProvider provider,
    Business business,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                business.name,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (business.isPremium)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'PREMIUM',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
          Row(
            children: [
              Icon(_categoryIcon(business.subcategory), size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                [
                  if (business.mainCategory.isNotEmpty) business.mainCategory,
                  if (business.subcategory.isNotEmpty) business.subcategory,
                ].where((e) => e.isNotEmpty).join(' • '),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on_outlined, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(business.address)),
            InkWell(
              onTap: () => _openMapAtLocation(business),
              child: Text(
                'Map',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _scrollToReviews,
          child: Row(
            children: [
              ...List<Widget>.generate(5, (index) {
                final fill = index < business.rating.round();
                return Icon(
                  Icons.star,
                  size: 18,
                  color: fill ? Colors.orange : Colors.grey.shade400,
                );
              }),
              const SizedBox(width: 6),
              Text(
                '${business.rating.toStringAsFixed(1)} (${business.reviewCount})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        if (provider.openingHoursText != null &&
            provider.openingHoursText!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.schedule, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(provider.openingHoursText!)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, Business business) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => _makeCall(
                    business.phoneNumber,
                    area: business.area,
                  ),
                  icon: const Icon(Icons.call),
                  label: const Text('Call Now'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () async {
                    unawaited(
                      _analyticsService.trackWhatsAppClick(
                        widget.businessId,
                        area: business.area,
                      ),
                    );
                    await _launchWhatsApp(
                      business.whatsappNumber ?? business.phoneNumber,
                    );
                  },
                  icon: const Icon(Icons.message_outlined),
                  label: const Text('WhatsApp'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: business.phoneNumber));
            if (!context.mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Number copied')),
            );
          },
          child: Text(
            'Copy number',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BusinessDetailProvider provider, Business business) {
    final founded = provider.foundedText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          business.description.trim().isEmpty
              ? 'No description added yet.'
              : business.description,
        ),
        if (founded != null && founded.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Established: $founded',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }

  Widget _buildServicesSection(BusinessDetailProvider provider) {
    final services = provider.services;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Services & Prices',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (services.isEmpty)
          const Text('No services added yet')
        else
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: List<Widget>.generate(services.length, (index) {
                final service = services[index];
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(service.name)),
                          Text(
                            service.price.isEmpty ? '-' : service.price,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    if (index != services.length - 1)
                      Divider(
                        height: 1,
                        color: Colors.grey.withValues(alpha: 0.25),
                      ),
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildLocationSection(BuildContext context, Business business) {
    final coords = latlong2.LatLng(business.latitude, business.longitude);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 170,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: coords,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.zemule.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: coords,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(business.address),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _openMapDirections(business),
          child: Text(
            'Get Directions',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection(
    BuildContext context,
    BusinessDetailProvider provider,
    Business business,
  ) {
    final reviews = provider.reviews;
    final preview = reviews.take(3).toList();

    return Container(
      key: _reviewsKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Reviews',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Text(
                '${business.rating.toStringAsFixed(1)} (${business.reviewCount})',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final detailProvider = context.read<BusinessDetailProvider>();
              final businessProvider = context.read<BusinessProvider>();
              final submitted = await Navigator.pushNamed(
                context,
                '/write-review',
                arguments: business.id,
              );
              if (!mounted || submitted != true) {
                return;
              }
              await detailProvider.initialize();
              await businessProvider.fetchBusinesses();
            },
            child: const Text('Write a Review'),
          ),
          const SizedBox(height: 8),
          if (reviews.isEmpty)
            const Text('No reviews yet.')
          else
            ...preview.map((review) => ReviewCard(review: review)),
          if (reviews.length > 3) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _showAllReviews(context, reviews),
              child: Text(
                'See all',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimilarBusinesses(
    BuildContext context,
    BusinessDetailProvider provider,
  ) {
    final similar = provider.similarBusinesses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'More like this',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (similar.isEmpty)
          const Text('No similar businesses found.')
        else
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: similar.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                final item = similar[index];
                return _SimilarBusinessCard(
                  business: item,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/business-detail',
                      arguments: item.id,
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  void _showAllReviews(BuildContext context, List<BusinessReview> reviews) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ListView.builder(
              itemCount: reviews.length,
              itemBuilder: (_, index) => ReviewCard(review: reviews[index]),
            ),
          ),
        );
      },
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.all(8),
          child: InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        );
      },
    );
  }

  Future<void> _makeCall(String? phoneNumber, {String? area}) async {
    unawaited(
      _analyticsService.trackCallClick(
        widget.businessId,
        area: area,
      ),
    );
    if (phoneNumber == null || phoneNumber.isEmpty) {
      _showSnack('No phone number available');
      return;
    }

    String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) cleanPhone = cleanPhone.substring(1);
    if (!cleanPhone.startsWith('260')) cleanPhone = '260$cleanPhone';

    final Uri dialUri = Uri(scheme: 'tel', path: '+$cleanPhone');

    if (await canLaunchUrl(dialUri)) {
      await launchUrl(dialUri);
    } else {
      _showSnack('No dialer available on this device');
    }
  }

  Future<void> _launchWhatsApp(String? phoneNumber) async {
    final digits = _cleanToZambiaNumber(phoneNumber);
    if (digits == null) {
      _showSnack('No phone number available');
      return;
    }
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    _showSnack('WhatsApp is not installed on this device');
  }

  Future<void> _openMapAtLocation(Business business) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${business.latitude},${business.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openMapDirections(Business business) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${business.latitude},${business.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _scrollToReviews() {
    final context = _reviewsKey.currentContext;
    if (context == null) {
      return;
    }
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      alignment: 0.05,
    );
  }

  IconData _categoryIcon(String category) {
    final key = category.toLowerCase();
    if (key.contains('barber')) {
      return Icons.content_cut;
    }
    if (key.contains('salon')) {
      return Icons.spa_outlined;
    }
    if (key.contains('mechanic') || key.contains('repair')) {
      return Icons.build;
    }
    if (key.contains('plumber')) {
      return Icons.plumbing;
    }
    if (key.contains('gaming') || key.contains('game')) {
      return Icons.sports_esports;
    }
    return Icons.storefront;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _cleanToZambiaNumber(String? raw) {
    if (raw == null) return null;
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (!digits.startsWith('260')) {
      digits = '260$digits';
    }
    return digits;
  }
}

class _SimilarBusinessCard extends StatelessWidget {
  const _SimilarBusinessCard({required this.business, required this.onTap});

  final Business business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        width: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                height: 94,
                width: double.infinity,
                child: business.photoUrls.isEmpty
                    ? Container(
                        color: colors.surface,
                        child: const Icon(Icons.storefront_outlined),
                      )
                    : CachedNetworkImage(
                        imageUrl: business.photoUrls.first,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: colors.surface,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
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
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
