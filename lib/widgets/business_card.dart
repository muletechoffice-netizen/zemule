import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zemule/models/business.dart';
import 'package:zemule/services/analytics_service.dart';

class BusinessCard extends StatefulWidget {
  const BusinessCard({
    super.key,
    required this.business,
    required this.distanceKm,
    this.onTap,
  });

  final Business business;
  final double? distanceKm;
  final VoidCallback? onTap;

  @override
  State<BusinessCard> createState() => _BusinessCardState();
}

class _BusinessCardState extends State<BusinessCard> {
  final AnalyticsService _analyticsService = AnalyticsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final businessId = widget.business.id.trim();
      if (businessId.isEmpty) {
        return;
      }
      unawaited(
        _analyticsService.trackBusinessCardImpression(
          businessId,
          area: widget.business.area,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shadowColor = theme.brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.24)
        : Colors.black.withValues(alpha: 0.05);
    final business = widget.business;
    final distanceKm = widget.distanceKm;
    final hasImage = business.photoUrls.isNotEmpty;
    final categoryLine = [
      if (business.mainCategory.trim().isNotEmpty) business.mainCategory.trim(),
      if (business.subcategory.trim().isNotEmpty) business.subcategory.trim(),
    ].join(' • ');
    final distanceLabel = distanceKm != null && distanceKm.isFinite
        ? '${distanceKm.toStringAsFixed(1)} km'
        : '';
    final locationLine = [
      if (business.area.trim().isNotEmpty) business.area.trim(),
      if (distanceLabel.isNotEmpty) distanceLabel,
    ].join(' • ');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: widget.onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    width: 112,
                    height: 126,
                    child: hasImage
                        ? CachedNetworkImage(
                            imageUrl: business.photoUrls.first,
                            fit: BoxFit.cover,
                            memCacheWidth: 320,
                            placeholder: (_, __) =>
                                _imageLoadingPlaceholder(colors),
                            errorWidget: (_, __, ___) =>
                                _imagePlaceholder(colors),
                          )
                        : _imagePlaceholder(colors),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              business.name.trim().isEmpty
                                  ? 'Unnamed business'
                                  : business.name.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (business.isPremium || business.isPromoted) ...[
                            const SizedBox(width: 8),
                            _buildBadge(
                              label: 'Popular',
                              backgroundColor: Colors.amber.shade100,
                              textColor: Colors.amber.shade900,
                              icon: Icons.local_fire_department_outlined,
                            ),
                          ],
                        ],
                      ),
                      if (categoryLine.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              _categoryIcon(business.subcategory),
                              size: 16,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                categoryLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (locationLine.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                locationLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (business.status.trim().toLowerCase() == 'approved')
                            _buildBadge(
                              label: 'Verified',
                              backgroundColor:
                                  Colors.green.withValues(alpha: 0.12),
                              textColor: Colors.green.shade800,
                              icon: Icons.verified_outlined,
                            ),
                          if (business.reviewCount <= 0)
                            _buildBadge(
                              label: 'New',
                              backgroundColor:
                                  colors.primary.withValues(alpha: 0.10),
                              textColor: colors.primary,
                              icon: Icons.fiber_new_rounded,
                            )
                          else
                            _buildBadge(
                              label:
                                  '★ ${business.rating.toStringAsFixed(1)} (${business.reviewCount})',
                              backgroundColor:
                                  Colors.orange.withValues(alpha: 0.12),
                              textColor: Colors.orange.shade900,
                              icon: Icons.star_rounded,
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _makeCall(context, business.phoneNumber),
                                icon: const Icon(Icons.call_outlined, size: 18),
                                label: const Text(
                                  'Call',
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: colors.primary),
                                  foregroundColor: colors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: FilledButton.icon(
                                onPressed: () => _launchWhatsApp(
                                  context,
                                  business.whatsappNumber ?? business.phoneNumber,
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 10),
                                ),
                                icon: const Icon(Icons.message_outlined, size: 18),
                                label: const Text(
                                  'WhatsApp',
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageLoadingPlaceholder(ColorScheme colors) {
    return Container(
      color: colors.surfaceContainerHighest,
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _imagePlaceholder(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withValues(alpha: 0.14),
            colors.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 34,
            color: colors.primary.withValues(alpha: 0.75),
          ),
          const SizedBox(height: 6),
          Text(
            'No photo',
            style: TextStyle(
              color: colors.primary.withValues(alpha: 0.82),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    final key = category.toLowerCase();
    if (key.contains('electric')) {
      if (key.contains('auto')) return Icons.ev_station;
      return Icons.electrical_services;
    }
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
    if (key.contains('tire')) return Icons.tire_repair;
    if (key.contains('wash')) return Icons.local_car_wash;
    if (key.contains('towing') || key.contains('tow')) return Icons.car_repair;
    if (key.contains('painter')) return Icons.format_paint;
    if (key.contains('carpenter')) return Icons.chair_alt;
    if (key.contains('lock')) return Icons.lock;
    if (key.contains('garden') || key.contains('landscap')) return Icons.grass;
    if (key.contains('pool')) return Icons.pool;
    if (key.contains('nail')) return Icons.brush;
    if (key.contains('spa')) return Icons.spa;
    if (key.contains('makeup')) return Icons.face_retouching_natural;
    if (key.contains('tailor')) return Icons.design_services;
    if (key.contains('laundry')) return Icons.local_laundry_service;
    if (key.contains('gym')) return Icons.fitness_center;
    if (key.contains('trainer')) return Icons.directions_run;
    if (key.contains('doctor') || key.contains('dentist')) {
      return Icons.medical_services;
    }
    if (key.contains('pharm')) return Icons.local_pharmacy;
    if (key.contains('photo') || key.contains('video')) return Icons.camera_alt;
    if (key.contains('dj')) return Icons.music_note;
    if (key.contains('planner') || key.contains('event')) return Icons.event;
    if (key.contains('cater')) return Icons.restaurant_menu;
    if (key.contains('phone')) return Icons.phone_iphone;
    if (key.contains('computer')) return Icons.computer;
    if (key.contains('web')) return Icons.web;
    if (key.contains('graphic')) return Icons.palette;
    if (key.contains('account')) return Icons.account_balance_wallet;
    if (key.contains('law')) return Icons.gavel;
    if (key.contains('real estate')) return Icons.house_outlined;
    if (key.contains('clean')) return Icons.cleaning_services;
    if (key.contains('karaoke')) return Icons.mic;
    if (key.contains('venue')) return Icons.location_city;
    if (key.contains('tutor') || key.contains('teacher')) return Icons.school;
    return Icons.storefront;
  }

  Future<void> _makeCall(BuildContext context, String? phoneNumber) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final businessId = widget.business.id.trim();
    if (businessId.isNotEmpty) {
      unawaited(
        _analyticsService.trackCallClick(
          businessId,
          area: widget.business.area,
        ),
      );
    }
    if (phoneNumber == null || phoneNumber.isEmpty) {
      _showSnack(messenger, 'No phone number available');
      return;
    }

    String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) cleanPhone = cleanPhone.substring(1);
    if (!cleanPhone.startsWith('260')) cleanPhone = '260$cleanPhone';

    final Uri dialUri = Uri(scheme: 'tel', path: '+$cleanPhone');

    if (await canLaunchUrl(dialUri)) {
      await launchUrl(dialUri);
    } else {
      _showSnack(messenger, 'No dialer available on this device');
    }
  }

  Future<void> _launchWhatsApp(BuildContext context, String? phoneNumber) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final businessId = widget.business.id.trim();
    if (businessId.isNotEmpty) {
      unawaited(
        _analyticsService.trackWhatsAppClick(
          businessId,
          area: widget.business.area,
        ),
      );
    }
    final digits = _cleanToZambiaNumber(phoneNumber);
    if (digits == null) {
      _showSnack(messenger, 'No phone number available');
      return;
    }
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    _showSnack(messenger, 'WhatsApp is not installed on this device');
  }

  void _showSnack(ScaffoldMessengerState? messenger, String message) {
    messenger?.showSnackBar(SnackBar(content: Text(message)));
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
