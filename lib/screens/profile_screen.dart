import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:zemule/models/activity.dart';
import 'package:zemule/models/review.dart';
import 'package:zemule/providers/user_provider.dart';
import 'package:zemule/screens/edit_profile_screen.dart';
import 'package:zemule/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = _authService.currentUser;
      if (!mounted || user == null) {
        return;
      }
      context.read<UserProvider>().loadAll(user.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final profile = provider.user;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: provider.isLoading && profile == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                final user = _authService.currentUser;
                if (user == null) {
                  return;
                }
                await provider.loadAll(user.uid);
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(context, provider),
                  const SizedBox(height: 16),
                  _buildStats(context, provider),
                  const SizedBox(height: 16),
                  _buildBusinessOwner(context, provider),
                  const SizedBox(height: 16),
                  _buildRecentActivity(context, provider),
                  const SizedBox(height: 16),
                  _buildMyReviews(context, provider),
                  const SizedBox(height: 16),
                  _buildMyFavorites(context, provider),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Version 1.0.0+1',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSignOutSection(context),
                ],
              ),
            ),
    );
  }

  Widget _buildSignOutSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isSigningOut ? null : () => _confirmAndSignOut(context),
        icon: _isSigningOut
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.error),
                ),
              )
            : const Icon(Icons.logout),
        label: Text(_isSigningOut ? 'Signing Out...' : 'Sign Out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.error,
          side: BorderSide(color: colorScheme.error),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Future<void> _confirmAndSignOut(BuildContext context) async {
    final userProvider = context.read<UserProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) {
      return;
    }

    setState(() => _isSigningOut = true);

    try {
      await _authService.signOut();
      if (!mounted) {
        return;
      }
      userProvider.clearUserData();
      navigator.pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to sign out. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  Widget _buildHeader(BuildContext context, UserProvider provider) {
    final profile = provider.user;
    final theme = Theme.of(context);
    final memberSince = DateFormat(
      'MMMM yyyy',
    ).format(profile?.memberSince ?? DateTime(2025, 3));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundImage: profile?.photoUrl?.isNotEmpty == true
                  ? CachedNetworkImageProvider(profile!.photoUrl!)
                  : null,
              child: profile?.photoUrl?.isNotEmpty == true
                  ? null
                  : Text(
                      (profile?.name.trim().isNotEmpty == true
                              ? profile!.name.trim().characters.first
                              : 'U')
                          .toUpperCase(),
                      style: theme.textTheme.headlineSmall,
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    profile?.name.trim().isNotEmpty == true
                        ? profile!.name.trim()
                        : 'Your Name',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      Navigator.pushNamed(context, '/edit-profile'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              profile?.email?.trim().isNotEmpty == true
                  ? profile!.email!
                  : 'No email found',
            ),
            const SizedBox(height: 4),
            Text('Member since $memberSince'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => const EditProfileScreen(asBottomSheet: true),
                );
              },
              child: const Text('Edit Profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(BuildContext context, UserProvider provider) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: '${provider.myReviews.length}',
            subtitle: 'Reviews',
            onTap: () => Navigator.pushNamed(context, '/my-reviews'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            title: '${provider.myFavorites.length}',
            subtitle: 'Favorites',
            onTap: () => Navigator.pushNamed(context, '/my-favorites'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            title: '${provider.myFavorites.take(3).length}',
            subtitle: 'Saved',
            onTap: () => Navigator.pushNamed(context, '/my-favorites'),
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessOwner(BuildContext context, UserProvider provider) {
    final profile = provider.user;
    final businessName = profile?.businessName;
    final businessPhoto = profile?.businessPhotoUrl;

    if (profile?.isBusinessOwner != true ||
        businessName == null ||
        businessName.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.storefront_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Own a business? List it for free',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/business-registration'),
                  icon: const Icon(Icons.add_business_outlined),
                  label: const Text('Own a business? List it for free'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: businessPhoto?.isNotEmpty == true
                        ? CachedNetworkImage(
                            imageUrl: businessPhoto!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const Icon(Icons.store),
                          )
                        : Container(
                            color: Theme.of(context).colorScheme.surface,
                            child: const Icon(Icons.store),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    businessName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/business-dashboard'),
              child: const Text('Switch to Business Mode'),
            ),
            const SizedBox(height: 10),
            Text(
              'Last 7 days: ${profile?.last7DaysViews ?? 0} views, ${profile?.last7DaysCalls ?? 0} calls',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, UserProvider provider) {
    final items = provider.recentActivity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No recent activity yet.'),
            ),
          )
        else
          ...items
              .take(5)
              .map(
                (activity) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: CircleAvatar(
                    child: Icon(_activityIcon(activity.type)),
                  ),
                  title: Text(_activityLabel(activity)),
                  subtitle: Text(_relativeTime(activity.timestamp)),
                  onTap: () {
                    if (activity.businessId.isNotEmpty) {
                      Navigator.pushNamed(
                        context,
                        '/business-detail',
                        arguments: activity.businessId,
                      );
                    }
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildMyReviews(BuildContext context, UserProvider provider) {
    final reviews = provider.myReviews;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'My Reviews',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/my-reviews'),
              child: const Text('See all'),
            ),
          ],
        ),
        if (reviews.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No reviews yet'),
            ),
          )
        else
          ...reviews.take(3).map((review) => _ReviewTile(review: review)),
      ],
    );
  }

  Widget _buildMyFavorites(BuildContext context, UserProvider provider) {
    final favorites = provider.myFavorites;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'My Favorites',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/my-favorites'),
              child: const Text('See all'),
            ),
          ],
        ),
        if (favorites.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No favorites yet'),
            ),
          )
        else
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: favorites.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                final item = favorites[index];
                return SizedBox(
                  width: 170,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/business-detail',
                        arguments: item.id,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: item.photoUrls.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: item.photoUrls.first,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      child: const Icon(Icons.store),
                                    ),
                                  )
                                : Container(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    child: const Center(
                                      child: Icon(Icons.storefront_outlined),
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        item.category,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      provider.removeFavorite(item.id),
                                  icon: const Icon(
                                    Icons.favorite,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  IconData _activityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.review:
        return Icons.rate_review_outlined;
      case ActivityType.favorite:
        return Icons.favorite;
      case ActivityType.call:
        return Icons.call_outlined;
      case ActivityType.view:
        return Icons.visibility_outlined;
    }
  }

  String _activityLabel(Activity activity) {
    switch (activity.type) {
      case ActivityType.review:
        return 'Reviewed "${activity.businessName}"';
      case ActivityType.favorite:
        return 'Saved "${activity.businessName}"';
      case ActivityType.call:
        return 'Called "${activity.businessName}"';
      case ActivityType.view:
        return 'Viewed "${activity.businessName}"';
    }
  }

  String _relativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays >= 7) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks week${weeks == 1 ? '' : 's'} ago';
    }
    if (diff.inDays >= 1) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    if (diff.inHours >= 1) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    return 'Just now';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(subtitle),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final businessName = provider.businessNameFor(review.businessId);
    final businessPhoto = provider.businessPhotoFor(review.businessId);

    return Card(
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
                    width: 46,
                    height: 46,
                    child: businessPhoto?.isNotEmpty == true
                        ? CachedNetworkImage(
                            imageUrl: businessPhoto!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const Icon(Icons.store),
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
                Text(
                  DateFormat('dd MMM yyyy').format(review.createdAt),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: List<Widget>.generate(
                5,
                (index) => Icon(
                  index < review.rating ? Icons.star : Icons.star_border,
                  size: 18,
                  color: Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(review.comment, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/my-reviews'),
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: () =>
                      context.read<UserProvider>().deleteReview(review.id),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
