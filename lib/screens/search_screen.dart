import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zemule/providers/business_provider.dart';
import 'package:zemule/providers/search_provider.dart';
import 'package:zemule/widgets/business_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _didLoadInitialQuery = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadInitialQuery) {
      return;
    }
    _didLoadInitialQuery = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    final initialQuery = args is String ? args.trim() : '';
    if (initialQuery.isEmpty) {
      return;
    }

    _searchController.text = initialQuery;
    _searchController.selection = TextSelection.collapsed(
      offset: initialQuery.length,
    );
    final provider = context.read<SearchProvider>();
    provider.updateQuery(initialQuery);
    provider.addToRecentSearches(initialQuery);
    unawaited(provider.performSearch());
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchProvider = context.watch<SearchProvider>();
    final colors = Theme.of(context).colorScheme;
    final query = searchProvider.searchQuery.trim();
    final hasQuery = query.isNotEmpty;
    final recentSearches = searchProvider.recentSearches;
    final approvedSearchResults = searchProvider.searchResults
        .where((business) => business.status.trim().toLowerCase() == 'approved')
        .toList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Container(
          height: 42,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (value) => _onQueryChanged(context, value),
            onSubmitted: (_) => _executeSearch(context),
            decoration: InputDecoration(
              hintText: 'Search businesses...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () => _clearQuery(context),
                      icon: const Icon(Icons.clear),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _clearQuery(context);
              Navigator.of(context).maybePop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          if (!hasQuery) ...[
            _buildRecentSearches(context, recentSearches),
            const SizedBox(height: 24),
            _buildPopularCategories(context),
          ] else ...[
            _buildFilterChips(context, searchProvider),
            const SizedBox(height: 14),
            if (searchProvider.isLoading)
              ...List<Widget>.generate(
                4,
                (_) => const _SearchBusinessCardSkeleton(),
              )
            else if (approvedSearchResults.isEmpty)
              _buildNoResults(context)
            else ...[
              Text(
                '${approvedSearchResults.length} businesses found',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
                ...approvedSearchResults.map(
                  (business) => BusinessCard(
                    business: business,
                    distanceKm: business.distanceKm,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                      '/business-detail',
                      arguments: business.id,
                    );
                  },
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildRecentSearches(BuildContext context, List<String> recentSearches) {
    final provider = context.read<SearchProvider>();
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recent searches',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (recentSearches.isNotEmpty)
              TextButton(
                onPressed: provider.clearRecentSearches,
                child: const Text('Clear all'),
              ),
          ],
        ),
        if (recentSearches.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No recent searches yet.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          )
        else
          ...recentSearches.map(
            (term) => Card(
              elevation: 0,
              color: colors.surface,
              margin: const EdgeInsets.only(top: 8),
              child: ListTile(
                leading: const Icon(Icons.search),
                title: Text(term),
                trailing: IconButton(
                  onPressed: () => provider.removeRecentSearch(term),
                  icon: const Icon(Icons.close),
                ),
                onTap: () => _runSearch(context, term),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPopularCategories(BuildContext context) {
    final businesses = context
        .watch<BusinessProvider>()
        .businesses
        .where((business) => business.status.trim().toLowerCase() == 'approved')
        .toList();

    final categories = _popularCategories.map((category) {
      final count = businesses
          .where((business) => _normalizeCategory(business.subcategory) == category.key)
          .length;
      return _PopularCategoryViewModel(
        key: category.key,
        name: category.name,
        icon: category.icon,
        count: count,
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular categories',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          itemCount: categories.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (_, index) {
            final category = categories[index];
            return _PopularCategoryCard(
              category: category,
              onTap: () => _runSearch(context, category.name),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFilterChips(BuildContext context, SearchProvider provider) {
    final premiumOnly = provider.filters['premiumOnly'] == true;
    final openNow = provider.filters['openNow'] == true;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Distance'),
          selected: provider.sortBy == 'distance',
          onSelected: (_) => provider.applySort('distance'),
        ),
        ChoiceChip(
          label: const Text('Rating'),
          selected: provider.sortBy == 'rating',
          onSelected: (_) => provider.applySort('rating'),
        ),
        ChoiceChip(
          label: const Text('Most Reviewed'),
          selected: provider.sortBy == 'reviews',
          onSelected: (_) => provider.applySort('reviews'),
        ),
        FilterChip(
          label: const Text('Premium only'),
          selected: premiumOnly,
          onSelected: (value) => provider.applyFilters({'premiumOnly': value}),
        ),
        FilterChip(
          label: const Text('Open now'),
          selected: openNow,
          onSelected: (value) => provider.applyFilters({'openNow': value}),
        ),
      ],
    );
  }

  Widget _buildNoResults(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 72, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(
            'No results found',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Try a different keyword or adjust your filters.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  void _onQueryChanged(BuildContext context, String value) {
    context.read<SearchProvider>().updateQuery(value);
    if (mounted) {
      setState(() {});
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      if (!mounted) {
        return;
      }
      context.read<SearchProvider>().performSearch();
    });
  }

  void _executeSearch(BuildContext context) {
    _debounceTimer?.cancel();
    final provider = context.read<SearchProvider>();
    provider.performSearch();
    provider.addToRecentSearches(provider.searchQuery);
  }

  void _runSearch(BuildContext context, String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.collapsed(offset: query.length);
    final provider = context.read<SearchProvider>();
    provider.updateQuery(query);
    provider.addToRecentSearches(query);
    provider.performSearch();
    if (mounted) {
      setState(() {});
    }
  }

  void _clearQuery(BuildContext context) {
    _debounceTimer?.cancel();
    _searchController.clear();
    final provider = context.read<SearchProvider>();
    provider.updateQuery('');
    provider.performSearch();
    if (mounted) {
      setState(() {});
    }
  }

  String _normalizeCategory(String category) {
    final value = category.toLowerCase().trim();
    if (value.contains('barber')) {
      return 'barber';
    }
    if (value.contains('salon')) {
      return 'hair_salon';
    }
    if (value.contains('mechanic')) {
      return 'mechanic';
    }
    if (value.contains('plumber')) {
      return 'plumber';
    }
    if (value.contains('gaming') || value.contains('game')) {
      return 'gaming';
    }
    return value;
  }
}

class _SearchBusinessCardSkeleton extends StatelessWidget {
  const _SearchBusinessCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = colors.surface.withValues(alpha: 0.85);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: placeholder,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, color: placeholder),
                  const SizedBox(height: 10),
                  Container(height: 12, width: 120, color: placeholder),
                  const SizedBox(height: 10),
                  Container(height: 12, width: 160, color: placeholder),
                  const SizedBox(height: 10),
                  Container(height: 12, width: 90, color: placeholder),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularCategoryCard extends StatelessWidget {
  const _PopularCategoryCard({required this.category, required this.onTap});

  final _PopularCategoryViewModel category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(category.icon, size: 34, color: colors.primary),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              '${category.count} businesses',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularCategorySeed {
  const _PopularCategorySeed({
    required this.key,
    required this.name,
    required this.icon,
  });

  final String key;
  final String name;
  final IconData icon;
}

class _PopularCategoryViewModel {
  const _PopularCategoryViewModel({
    required this.key,
    required this.name,
    required this.icon,
    required this.count,
  });

  final String key;
  final String name;
  final IconData icon;
  final int count;
}

const List<_PopularCategorySeed> _popularCategories = <_PopularCategorySeed>[
  _PopularCategorySeed(
    key: 'barber',
    name: 'Barber',
    icon: Icons.content_cut,
  ),
  _PopularCategorySeed(
    key: 'hair_salon',
    name: 'Hair Salon',
    icon: Icons.spa_outlined,
  ),
  _PopularCategorySeed(
    key: 'mechanic',
    name: 'Mechanic',
    icon: Icons.build,
  ),
  _PopularCategorySeed(
    key: 'plumber',
    name: 'Plumber',
    icon: Icons.plumbing,
  ),
  _PopularCategorySeed(
    key: 'gaming',
    name: 'Gaming',
    icon: Icons.sports_esports,
  ),
  _PopularCategorySeed(
    key: 'cleaning',
    name: 'Cleaning',
    icon: Icons.cleaning_services,
  ),
];
