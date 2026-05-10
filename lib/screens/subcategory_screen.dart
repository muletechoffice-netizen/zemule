import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zemule/providers/business_provider.dart';
import 'package:zemule/widgets/business_card.dart';

class SubcategoryScreenArgs {
  const SubcategoryScreenArgs({
    required this.mainCategory,
    required this.subcategories,
  });

  final String mainCategory;
  final List<String> subcategories;
}

class SubcategoryScreen extends StatefulWidget {
  const SubcategoryScreen({
    super.key,
    required this.mainCategory,
    required this.subcategories,
  });

  final String mainCategory;
  final List<String> subcategories;

  @override
  State<SubcategoryScreen> createState() => _SubcategoryScreenState();
}

class _SubcategoryScreenState extends State<SubcategoryScreen> {
  String? _selectedSubcategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<BusinessProvider>().setCategoryScope(widget.mainCategory);
    });
  }

  @override
  void dispose() {
    context.read<BusinessProvider>().clearCategoryScope();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessProvider>();
    final colors = Theme.of(context).colorScheme;
    final approvedBusinesses = provider.filteredBusinesses
        .where((business) => business.status.toLowerCase() == 'approved')
        .toList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(widget.mainCategory),
      ),
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              'Select a subcategory',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _buildSubcategoryChips(colors, provider),
            const SizedBox(height: 18),
            if (provider.isLoading)
              ...List<Widget>.generate(3, (_) => const _BusinessCardSkeleton())
            else if (approvedBusinesses.isEmpty)
              _buildEmptyState(context)
            else ...[
              Row(
                children: [
                  Text(
                    _selectedSubcategory == null
                        ? 'All ${widget.mainCategory}'
                        : _selectedSubcategory!,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    '${approvedBusinesses.length} found',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...approvedBusinesses.map(
                (business) => BusinessCard(
                  business: business,
                  distanceKm:
                      provider.isUsingGps ? provider.distanceFor(business) : null,
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
        ),
      ),
    );
  }

  Widget _buildSubcategoryChips(ColorScheme colors, BusinessProvider provider) {
    if (widget.subcategories.isEmpty) {
      return Text(
        'No subcategories configured yet.',
        style: TextStyle(color: Colors.grey.shade600),
      );
    }

    final chips = <Widget>[
      ChoiceChip(
        label: const Text('All'),
        selected: _selectedSubcategory == null,
        onSelected: (_) => _onSelectSubcategory(null, provider),
      ),
      ...widget.subcategories.map((subcategory) {
        final isSelected = _selectedSubcategory == subcategory;
        return ChoiceChip(
          label: Text(subcategory),
          selected: isSelected,
          selectedColor: colors.primaryContainer,
          labelStyle: TextStyle(
            color: isSelected ? colors.onPrimaryContainer : colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) => _onSelectSubcategory(subcategory, provider),
        );
      }),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: chips,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final hint = _selectedSubcategory == null
        ? 'No businesses found in this category for the current location filter.'
        : 'No businesses found for this subcategory.';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.layers_clear, size: 60, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(
            'Nothing to show',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _onSelectSubcategory(String? subcategory, BusinessProvider provider) {
    setState(() => _selectedSubcategory = subcategory);
    provider.filterByCategory(subcategory ?? 'All');
  }
}

class _BusinessCardSkeleton extends StatelessWidget {
  const _BusinessCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = colors.surface.withValues(alpha: 0.8);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 96,
              height: 96,
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
                  Container(height: 12, width: 140, color: placeholder),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
