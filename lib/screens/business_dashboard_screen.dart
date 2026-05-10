import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zemule/models/business.dart';
import 'package:zemule/models/feature_flag.dart';
import 'package:zemule/providers/business_provider.dart';
import 'package:zemule/providers/feature_flag_provider.dart';
import 'package:zemule/services/analytics_service.dart';
import 'package:zemule/services/supabase_service.dart';
import 'package:zemule/utils/opening_hours.dart';
import 'package:zemule/widgets/feature_flag_gate.dart';

class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  State<BusinessDashboardScreen> createState() =>
      _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final SupabaseService _supabase = SupabaseService.instance;

  bool _isLoading = true;
  Business? _business;
  String? _openingHoursText;
  int _reviewCount = 0;
  Map<String, int> _weeklyStats = <String, int>{};
  Map<String, int> _totalStats = <String, int>{};
  bool _showTotalInsightsFallback = false;
  List<_DashboardReview> _recentReviews = <_DashboardReview>[];
  List<MapEntry<String, int>> _topKeywords = <MapEntry<String, int>>[];
  List<MapEntry<String, int>> _demographics = <MapEntry<String, int>>[];
  List<MapEntry<int, int>> _popularTimes = <MapEntry<int, int>>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboard());
  }

  @override
  Widget build(BuildContext context) {
    final business = _business;
    final growthTips = business == null ? const <String>[] : _buildGrowthTips(business);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Dashboard'),
        actions: [
          IconButton(
            onPressed: business == null ? null : () => _shareBusiness(business),
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            onPressed: business == null
                ? null
                : () => _openEditBusiness(business.id),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : business == null
              ? _buildNoBusinessState()
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildQuickActionsCard(business),
                      const SizedBox(height: 12),
                      _buildBusinessOverviewCard(business),
                      const SizedBox(height: 12),
                      _buildStatusCard(business),
                      if (_hasZeroPerformance) ...[
                        const SizedBox(height: 12),
                        _buildEmptyStateCard(business),
                      ],
                      const SizedBox(height: 12),
                      _buildPerformanceInsightsCard(),
                      const SizedBox(height: 12),
                      _buildGrowthTipsCard(growthTips),
                      const SizedBox(height: 12),
                      _buildBoostCard(),
                      const SizedBox(height: 12),
                      _buildReviewsCard(business),
                      FeatureFlagGate(
                        flagName: kShowAnalyticsFlag,
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            _buildAnalyticsCard(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  bool get _hasZeroPerformance {
    return _statValue(_totalStats, 'views') == 0 &&
        _statValue(_totalStats, 'calls') == 0 &&
        _statValue(_totalStats, 'whatsappClicks') == 0 &&
        _reviewCount == 0;
  }

  Map<String, int> get _insightStats {
    return _showTotalInsightsFallback ? _totalStats : _weeklyStats;
  }

  Widget _buildNoBusinessState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'No business found for this owner',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessOverviewCard(Business business) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final categories = [
      if (business.mainCategory.trim().isNotEmpty) business.mainCategory.trim(),
      if (business.subcategory.trim().isNotEmpty) business.subcategory.trim(),
    ].join(' • ');
    final location = [
      business.area.trim(),
      business.city.trim(),
    ].where((value) => value.isNotEmpty).join(', ');
    final photoCount = business.photoUrls.length;
    final hoursPreview = _openingHoursText?.split('\n').first.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 80,
                height: 80,
                child: business.photoUrls.isEmpty
                    ? Container(
                        color: colors.primary.withValues(alpha: 0.10),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.storefront_outlined,
                          size: 34,
                          color: colors.primary,
                        ),
                      )
                    : Image.network(
                        business.photoUrls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            color: colors.primary.withValues(alpha: 0.10),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 30,
                              color: colors.primary,
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.name.trim().isEmpty ? 'Unnamed business' : business.name.trim(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTag(
                        icon: Icons.workspace_premium_outlined,
                        label: business.isPremium ? 'Premium plan' : 'Free plan',
                      ),
                      _buildTag(
                        icon: Icons.star_outline,
                        label: '$_reviewCount review${_reviewCount == 1 ? '' : 's'}',
                      ),
                      _buildTag(
                        icon: Icons.photo_library_outlined,
                        label: '$photoCount photo${photoCount == 1 ? '' : 's'}',
                      ),
                    ],
                  ),
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildMetaRow(Icons.category_outlined, categories),
                  ],
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildMetaRow(Icons.location_on_outlined, location),
                  ],
                  const SizedBox(height: 8),
                  _buildMetaRow(
                    Icons.schedule_outlined,
                    hoursPreview?.isNotEmpty == true
                        ? hoursPreview!
                        : 'Working hours not updated yet',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard(Business business) {
    final actions = <_DashboardAction>[
      _DashboardAction(
        label: 'Edit Business',
        icon: Icons.edit_outlined,
        onTap: () => _openEditBusiness(business.id),
      ),
      _DashboardAction(
        label: 'Add Photos',
        icon: Icons.add_a_photo_outlined,
        onTap: () => _openEditBusiness(business.id, initialStep: 3),
      ),
      _DashboardAction(
        label: 'Share Business',
        icon: Icons.share_outlined,
        onTap: () => _shareBusiness(business),
      ),
      _DashboardAction(
        label: 'View Public Listing',
        icon: Icons.public_outlined,
        onTap: () => Navigator.of(
          context,
        ).pushNamed('/business-detail', arguments: business.id),
      ),
      _DashboardAction(
        label: 'Update Working Hours',
        icon: Icons.schedule_outlined,
        onTap: () => _openEditBusiness(business.id, initialStep: 5),
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: 'Quick actions',
              subtitle: 'Make updates and bring more customers to your listing.',
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 440 ? 3 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.35,
                  ),
                  itemCount: actions.length,
                  itemBuilder: (context, index) {
                    final action = actions[index];
                    return _buildActionTile(action);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(_DashboardAction action) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant),
          color: colors.surface,
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(action.icon, color: colors.primary),
            ),
            Text(
              action.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(Business business) {
    final colors = Theme.of(context).colorScheme;
    final normalizedStatus = business.status.trim().toLowerCase();
    final isPending = normalizedStatus == 'pending';
    final isApproved = normalizedStatus == 'approved';
    final backgroundColor = isApproved
        ? Colors.green.withValues(alpha: 0.12)
        : isPending
            ? Colors.orange.withValues(alpha: 0.14)
            : colors.errorContainer;
    final accentColor = isApproved
        ? Colors.green.shade700
        : isPending
            ? Colors.orange.shade800
            : colors.error;
    final statusLabel = normalizedStatus.isEmpty
        ? 'Unknown'
        : '${normalizedStatus[0].toUpperCase()}${normalizedStatus.substring(1)}';
    final message = isApproved
        ? 'Your business is live and visible to customers.'
        : isPending
            ? 'Your business is pending approval. We will notify you when approved.'
            : business.rejectionReason?.trim().isNotEmpty == true
                ? business.rejectionReason!.trim()
                : 'Your business needs attention before it can go live.';

    return Card(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_outlined, color: accentColor),
                const SizedBox(width: 8),
                Text(
                  'Approval status: $statusLabel',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(message),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard(Business business) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your business is live 🎉 Start sharing your listing to get your first customers.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'Customers will start finding you faster when you share your listing and add a few strong photos.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _shareOnWhatsApp(business),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Share on WhatsApp'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceInsightsCard() {
    final stats = _insightStats;
    final views = _statValue(stats, 'views');
    final calls = _statValue(stats, 'calls');
    final whatsapp = _statValue(stats, 'whatsappClicks');
    final reviews = _showTotalInsightsFallback ? _reviewCount : _statValue(stats, 'newReviews');
    final conversionRate = views == 0 ? null : ((calls + whatsapp) / views) * 100;
    final periodLabel = _showTotalInsightsFallback ? 'All time' : 'This week';

    final items = <_InsightItem>[
      _InsightItem(
        label: 'Views',
        value: views,
        icon: Icons.visibility_outlined,
        color: Colors.blue.shade700,
      ),
      _InsightItem(
        label: 'Calls',
        value: calls,
        icon: Icons.call_outlined,
        color: Colors.teal.shade700,
      ),
      _InsightItem(
        label: 'WhatsApp',
        value: whatsapp,
        icon: Icons.forum_outlined,
        color: Colors.green.shade700,
      ),
      _InsightItem(
        label: 'New reviews',
        value: reviews,
        icon: Icons.star_outline,
        color: Colors.amber.shade800,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: 'Performance insights',
              subtitle: periodLabel,
            ),
            if (_showTotalInsightsFallback) ...[
              const SizedBox(height: 8),
              Text(
                'Showing total activity because weekly analytics are not available yet.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 440 ? 4 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: constraints.maxWidth >= 440 ? 1.35 : 1.55,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildInsightTile(item);
                  },
                );
              },
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Conversion rate',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Text(
                    conversionRate == null ? '—' : '${conversionRate.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightTile(_InsightItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(item.icon, color: item.color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.value}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthTipsCard(List<String> tips) {
    final isCompact = tips.isEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: 'Growth tips',
              subtitle: isCompact
                  ? 'Performance is improving.'
                  : 'Small actions that can help you get more customers.',
            ),
            const SizedBox(height: 12),
            if (isCompact)
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your listing looks healthy. Keep adding fresh photos and asking happy customers for reviews.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ],
              )
            else
              ...tips.take(4).map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(tip)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoostCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: 'Boost your business',
              subtitle: 'Get more visibility and appear higher in search results.',
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.rocket_launch_outlined),
                label: const Text('Boost Listing'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsCard(Business business) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: 'Recent reviews',
              subtitle: '$_reviewCount total review${_reviewCount == 1 ? '' : 's'}',
            ),
            const SizedBox(height: 12),
            if (_recentReviews.isEmpty) ...[
              const Text(
                'No reviews yet. Ask your customers to review your business.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _requestReview(business),
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Request Review'),
              ),
            ] else
              ..._recentReviews.asMap().entries.map((entry) {
                final index = entry.key;
                final review = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _recentReviews.length - 1 ? 0 : 12,
                  ),
                  child: _buildReviewTile(review),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewTile(_DashboardReview review) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                child: Text(
                  review.displayName.substring(0, 1).toUpperCase(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMM d, y').format(review.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List<Widget>.generate(5, (index) {
                  return Icon(
                    index < review.rating.round()
                        ? Icons.star
                        : Icons.star_border,
                    size: 16,
                    color: Colors.orange,
                  );
                }),
              ),
            ],
          ),
          if (review.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(review.comment.trim()),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: 'Analytics',
              subtitle: 'More market insights are on the way.',
            ),
            const SizedBox(height: 12),
            _buildMetaRow(
              Icons.search_outlined,
              'Top keywords: ${_topKeywords.length}',
            ),
            const SizedBox(height: 8),
            _buildMetaRow(
              Icons.groups_outlined,
              'Demographics: ${_demographics.length}',
            ),
            const SizedBox(height: 8),
            _buildMetaRow(
              Icons.schedule_outlined,
              'Popular times: ${_popularTimes.length}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag({required IconData icon, required String label}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: colors.primary.withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        if (subtitle != null && subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ],
      ],
    );
  }

  List<String> _buildGrowthTips(Business business) {
    final tips = <String>[];
    final totalViews = _statValue(_totalStats, 'views');
    final totalCalls = _statValue(_totalStats, 'calls');
    final totalWhatsApp = _statValue(_totalStats, 'whatsappClicks');

    if (business.photoUrls.length < 3) {
      tips.add('Add 3+ photos to attract more customers.');
    }
    if (totalViews < 15) {
      tips.add('Share your listing on WhatsApp groups to bring in more views.');
    }
    if (totalCalls + totalWhatsApp < 3) {
      tips.add('Keep your phone active so interested customers can reach you quickly.');
    }
    if (_reviewCount < 3) {
      tips.add('Ask customers to leave reviews so new buyers trust your business faster.');
    }
    return tips;
  }

  int _statValue(Map<String, int> stats, String key) {
    final value = stats[key];
    if (value == null || value < 0) {
      return 0;
    }
    return value;
  }

  Future<void> _openEditBusiness(
    String businessId, {
    int initialStep = 0,
  }) async {
    await Navigator.of(context).pushNamed(
      '/edit-business',
      arguments: <String, dynamic>{
        'businessId': businessId,
        'initialStep': initialStep,
      },
    );
    if (!mounted) {
      return;
    }
    await _loadDashboard();
  }

  Future<void> _shareBusiness(Business business) async {
    try {
      await Share.share(_buildShareText(business));
    } catch (_) {
      _showSnack('Unable to share business right now.');
    }
  }

  Future<void> _shareOnWhatsApp(Business business) async {
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(_buildShareText(business))}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
      await Share.share(_buildShareText(business));
    } catch (_) {
      _showSnack('Unable to open WhatsApp right now.');
    }
  }

  Future<void> _requestReview(Business business) async {
    final message = StringBuffer()
      ..writeln('Hi, thank you for supporting ${business.name}.')
      ..writeln('Please leave a review for our business on Zemule.')
      ..writeln('Your feedback helps more customers trust us.')
      ..writeln('Call: ${business.phoneNumber.trim()}');

    try {
      await Share.share(message.toString().trim());
    } catch (_) {
      _showSnack('Unable to share a review request right now.');
    }
  }

  String _buildShareText(Business business) {
    final buffer = StringBuffer()
      ..writeln(
        business.name.trim().isEmpty ? 'Business listing' : business.name.trim(),
      );

    final categoryLine = [
      if (business.mainCategory.trim().isNotEmpty) business.mainCategory.trim(),
      if (business.subcategory.trim().isNotEmpty) business.subcategory.trim(),
    ].join(' • ');
    if (categoryLine.isNotEmpty) {
      buffer.writeln(categoryLine);
    }

    final locationLine = [
      business.area.trim(),
      business.city.trim(),
    ].where((value) => value.isNotEmpty).join(', ');
    if (locationLine.isNotEmpty) {
      buffer.writeln(locationLine);
    }

    final phone = business.phoneNumber.trim();
    if (phone.isNotEmpty) {
      buffer.writeln('Call: $phone');
    }

    return buffer.toString().trim();
  }

  Future<void> _loadDashboard() async {
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = true);

    final provider = context.read<BusinessProvider>();
    final featureFlags = context.read<FeatureFlagProvider>();
    final ownerId = _supabase.currentUserId;
    Business? business;

    try {
      if (ownerId != null) {
        business = await provider.getBusinessByOwnerId(ownerId);
      }
    } catch (_) {
      business = null;
    }

    if (business == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _business = null;
        _isLoading = false;
      });
      return;
    }

    bool showAnalytics = false;
    try {
      await featureFlags.refresh(showLoader: false);
      showAnalytics = featureFlags.isEnabled(kShowAnalyticsFlag);
    } catch (_) {
      showAnalytics = false;
    }

    Map<String, int> weeklyStats = <String, int>{};
    Map<String, dynamic>? rawBusiness;
    List<Map<String, dynamic>> reviewRows = <Map<String, dynamic>>[];
    List<_DashboardReview> recentReviews = <_DashboardReview>[];

    try {
      weeklyStats = await provider.getStats(business.id, period: 'week');
    } catch (_) {
      weeklyStats = <String, int>{};
    }

    try {
      rawBusiness = await _supabase.getBusinessById(business.id);
    } catch (_) {
      rawBusiness = null;
    }

    try {
      reviewRows = await _supabase.listReviews(
        businessId: business.id,
        newestFirst: true,
      );
      recentReviews = await _loadRecentReviews(reviewRows.take(5).toList());
    } catch (_) {
      reviewRows = <Map<String, dynamic>>[];
      recentReviews = <_DashboardReview>[];
    }

    Map<String, int> totalStats = <String, int>{};
    try {
      totalStats = await _loadTotalStats(
        businessId: business.id,
        reviewRows: reviewRows,
        reviewFallback: business.reviewCount,
        rawBusiness: rawBusiness,
      );
    } catch (_) {
      totalStats = <String, int>{
        'views': 0,
        'calls': 0,
        'whatsappClicks': 0,
        'newReviews': business.reviewCount,
      };
    }

    List<MapEntry<String, int>> topKeywords = <MapEntry<String, int>>[];
    List<MapEntry<String, int>> demographics = <MapEntry<String, int>>[];
    List<MapEntry<int, int>> popularTimes = <MapEntry<int, int>>[];

    if (showAnalytics) {
      try {
        topKeywords = await _analyticsService.getTopSearchKeywords(business.id);
      } catch (_) {
        topKeywords = <MapEntry<String, int>>[];
      }
      try {
        demographics = await _analyticsService.getCustomerDemographics(
          business.id,
        );
      } catch (_) {
        demographics = <MapEntry<String, int>>[];
      }
      try {
        popularTimes = await _analyticsService.getPopularTimes(business.id);
      } catch (_) {
        popularTimes = <MapEntry<int, int>>[];
      }
    }

    final reviewCount = reviewRows.isNotEmpty ? reviewRows.length : business.reviewCount;
    final showTotalFallback = !_hasActivity(weeklyStats) && _hasActivity(totalStats);

    if (!mounted) {
      return;
    }
    setState(() {
      _business = business;
      _openingHoursText = openingHoursSummary(
        rawBusiness?['opening_hours'] ?? rawBusiness?['openingHours'],
      );
      _reviewCount = reviewCount < 0 ? 0 : reviewCount;
      _weeklyStats = weeklyStats;
      _totalStats = totalStats;
      _showTotalInsightsFallback = showTotalFallback;
      _recentReviews = recentReviews;
      _topKeywords = topKeywords;
      _demographics = demographics;
      _popularTimes = popularTimes;
      _isLoading = false;
    });
  }

  bool _hasActivity(Map<String, int> stats) {
    return _statValue(stats, 'views') > 0 ||
        _statValue(stats, 'calls') > 0 ||
        _statValue(stats, 'whatsappClicks') > 0 ||
        _statValue(stats, 'newReviews') > 0;
  }

  Future<Map<String, int>> _loadTotalStats({
    required String businessId,
    required List<Map<String, dynamic>> reviewRows,
    required int reviewFallback,
    required Map<String, dynamic>? rawBusiness,
  }) async {
    List<Map<String, dynamic>> interactionRows = <Map<String, dynamic>>[];
    try {
      interactionRows = await _supabase.listBusinessInteractions(
        businessId: businessId,
      );
    } catch (_) {
      interactionRows = <Map<String, dynamic>>[];
    }

    int countType(String type) {
      return interactionRows.where((row) {
        return (row['interaction_type']?.toString() ?? '') == type;
      }).length;
    }

    final reviews = reviewRows.isNotEmpty ? reviewRows.length : reviewFallback;
    final storedViews = _countFromRaw(rawBusiness, 'views');
    final storedCalls = _countFromRaw(rawBusiness, 'calls');
    final storedWhatsApp = _countFromRaw(
      rawBusiness,
      'whatsapp_clicks',
      fallbackKey: 'whatsappClicks',
    );
    return <String, int>{
      'views': _maxCount(countType('view'), storedViews),
      'calls': _maxCount(countType('call'), storedCalls),
      'whatsappClicks': _maxCount(countType('whatsapp'), storedWhatsApp),
      'newReviews': reviews < 0 ? 0 : reviews,
    };
  }

  int _countFromRaw(
    Map<String, dynamic>? rawBusiness,
    String key, {
    String? fallbackKey,
  }) {
    final rawValue = rawBusiness?[key] ?? (fallbackKey == null ? null : rawBusiness?[fallbackKey]);
    if (rawValue is num) {
      final value = rawValue.toInt();
      return value < 0 ? 0 : value;
    }
    if (rawValue is String) {
      final value = int.tryParse(rawValue) ?? 0;
      return value < 0 ? 0 : value;
    }
    return 0;
  }

  int _maxCount(int first, int second) {
    if (first < 0 && second < 0) {
      return 0;
    }
    return first > second ? first : second;
  }

  Future<List<_DashboardReview>> _loadRecentReviews(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) {
      return <_DashboardReview>[];
    }

    final userIds = rows
        .map((row) => row['user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final namesById = <String, String>{};

    if (userIds.isNotEmpty) {
      try {
        final userRows = await _supabase.client
            .from('users')
            .select('id,name')
            .inFilter('id', userIds);
        for (final item in (userRows as List)) {
          final row = Map<String, dynamic>.from(item as Map);
          namesById[row['id']?.toString() ?? ''] =
              (row['name'] as String?)?.trim() ?? '';
        }
      } catch (_) {
        // Reviews should still render even if user names fail to load.
      }
    }

    return rows.map((row) {
      final userId = row['user_id']?.toString() ?? '';
      final isAnonymous = row['is_anonymous'] as bool? ?? false;
      final displayName = isAnonymous
          ? 'Anonymous'
          : (namesById[userId]?.isNotEmpty == true ? namesById[userId]! : 'Customer');
      return _DashboardReview(
        displayName: displayName,
        rating: (row['rating'] as num?)?.toDouble() ?? 0,
        comment: row['comment'] as String? ?? '',
        createdAt: _toDate(row['created_at']) ?? DateTime.now(),
      );
    }).toList();
  }

  DateTime? _toDate(dynamic raw) {
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String) {
      return DateTime.tryParse(raw)?.toLocal();
    }
    return null;
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DashboardAction {
  const _DashboardAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _InsightItem {
  const _InsightItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

class _DashboardReview {
  const _DashboardReview({
    required this.displayName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String displayName;
  final double rating;
  final String comment;
  final DateTime createdAt;
}
