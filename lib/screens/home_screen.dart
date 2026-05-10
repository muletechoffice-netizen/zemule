import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:zemule/models/business.dart';
import 'package:zemule/providers/business_provider.dart';
import 'package:zemule/screens/subcategory_screen.dart';
import 'package:zemule/services/location_service.dart';
import 'package:zemule/services/search_service.dart';
import 'package:zemule/widgets/business_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<String> _manualLocations = <String>[
    'Lusaka',
    'Kitwe',
    'Ndola',
    'Kabwe',
    'Livingstone',
    'Kabwata',
    'Matero',
    'East Park',
    'Lusaka City',
    'Woodlands',
    'Kabulonga',
    'Chilenje',
  ];

  static const List<String> _popularSuggestions = <String>[
    'Barber',
    'Hair Salon',
    'Plumber',
    'Mechanic',
    'Laundry',
    'Photographer',
  ];

  static const List<_MainCategory> _mainCategories = <_MainCategory>[
    _MainCategory(name: 'HOME SERVICES', icon: Icons.home_work_outlined),
    _MainCategory(name: 'AUTO SERVICES', icon: Icons.car_repair_outlined),
    _MainCategory(name: 'BEAUTY & CARE', icon: Icons.brush_outlined),
    _MainCategory(name: 'HEALTH & FITNESS', icon: Icons.fitness_center_outlined),
    _MainCategory(name: 'EVENTS & PHOTOGRAPHY', icon: Icons.camera_alt_outlined),
    _MainCategory(name: 'TECH SERVICES', icon: Icons.devices_other_outlined),
    _MainCategory(name: 'PROFESSIONAL SERVICES', icon: Icons.business_center_outlined),
    _MainCategory(name: 'ENTERTAINMENT', icon: Icons.theaters_outlined),
    _MainCategory(name: 'EDUCATION', icon: Icons.school_outlined),
  ];

  static const Map<String, List<String>> _subcategoryMapping =
      <String, List<String>>{
        'HOME SERVICES': <String>[
          'Electrician',
          'Plumber',
          'Painter',
          'Carpenter',
          'Locksmith',
          'Gardener',
          'Pool Cleaner',
        ],
        'AUTO SERVICES': <String>[
          'Mechanic',
          'Car Wash',
          'Towing',
          'Tire Shop',
          'Auto Electrician',
        ],
        'BEAUTY & CARE': <String>[
          'Hair Salon',
          'Barber',
          'Nail Salon',
          'Spa',
          'Makeup Artist',
          'Tailor',
          'Laundry',
        ],
        'HEALTH & FITNESS': <String>[
          'Gym',
          'Personal Trainer',
          'Doctor',
          'Pharmacy',
          'Dentist',
        ],
        'EVENTS & PHOTOGRAPHY': <String>[
          'Photographer',
          'Videographer',
          'DJ',
          'Event Planner',
          'Caterer',
        ],
        'TECH SERVICES': <String>[
          'Phone Repair',
          'Computer Repair',
          'Web Designer',
          'Graphic Designer',
        ],
        'PROFESSIONAL SERVICES': <String>[
          'Accountant',
          'Lawyer',
          'Real Estate Agent',
          'Cleaner',
        ],
        'ENTERTAINMENT': <String>[
          'Gaming Station',
          'Event Venue',
          'Karaoke Bar',
        ],
        'EDUCATION': <String>[
          'Tutor',
          'Music Teacher',
          'Computer Training',
        ],
      };

  bool _hasHandledInitialLocationPrompt = false;
  bool _isLoadingRecentSearches = true;
  List<String> _recentSearches = <String>[];
  String _nearbySort = 'closest';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _initializeHome();
    });
  }

  Future<void> _initializeHome() async {
    final provider = context.read<BusinessProvider>();
    await Future.wait<void>(<Future<void>>[
      provider.initialize(),
      _loadRecentSearches(),
    ]);
    await _handleInitialLocationPrompt(provider);
  }

  Future<void> _loadRecentSearches() async {
    try {
      final searchService = SearchService(
        locationService: context.read<LocationService>(),
      );
      final searches = await searchService.getRecentSearches();
      if (!mounted) {
        return;
      }
      setState(() {
        _recentSearches = searches.take(4).toList();
        _isLoadingRecentSearches = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _recentSearches = <String>[];
        _isLoadingRecentSearches = false;
      });
    }
  }

  Future<void> _handleInitialLocationPrompt(BusinessProvider provider) async {
    if (!mounted || _hasHandledInitialLocationPrompt) {
      return;
    }
    _hasHandledInitialLocationPrompt = true;

    final locationService = context.read<LocationService>();
    final permission = await locationService.checkPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      if (!provider.isUsingGps) {
        final success = await provider.useCurrentLocation();
        if (!mounted || success) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please enable GPS/location services to use nearby results.',
            ),
          ),
        );
        _showManualAreaPicker(provider);
      }
      return;
    }

    final allowLocation = await _showInitialLocationDialog();
    if (!mounted || allowLocation != true) {
      _showManualAreaPicker(provider);
      return;
    }

    final servicesEnabled = await locationService.isLocationServiceEnabled();
    if (!servicesEnabled) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enable GPS/location services to use nearby results.',
          ),
        ),
      );
      _showManualAreaPicker(provider);
      return;
    }

    final requestedPermission = await locationService.requestPermission();
    if (!mounted) {
      return;
    }

    if (requestedPermission == LocationPermission.always ||
        requestedPermission == LocationPermission.whileInUse) {
      await provider.useCurrentLocation();
      return;
    }

    _showManualAreaPicker(provider);
  }

  Future<bool?> _showInitialLocationDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Location Access'),
          content: const Text(
            'Zelume needs your location to show businesses near you. Allow location access?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );
  }

  void _showManualAreaPicker(BusinessProvider provider) {
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _showAreaSelector(context, provider, includeGpsOption: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessProvider>();
    final colors = Theme.of(context).colorScheme;
    final visibleBusinesses = _buildVisibleBusinesses(provider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        elevation: 0,
        toolbarHeight: 78,
        titleSpacing: 16,
        iconTheme: IconThemeData(color: colors.onPrimary),
        title: InkWell(
          onTap: () => _showAreaSelector(
            context,
            provider,
            includeGpsOption: true,
          ),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Zemule',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: colors.onPrimary.withValues(alpha: 0.92),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _headerLocationText(provider),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onPrimary.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: colors.onPrimary.withValues(alpha: 0.92),
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/profile'),
            icon: const Icon(Icons.person_outline),
            color: colors.onPrimary,
            tooltip: 'Profile',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.refresh();
          await _loadRecentSearches();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildSearchModule(context),
            const SizedBox(height: 18),
            _buildCategorySection(context),
            const SizedBox(height: 22),
            _buildNearYouSectionHeader(context, provider),
            const SizedBox(height: 12),
            _buildNearYouControls(context, provider),
            const SizedBox(height: 12),
            if (provider.isLoading)
              ...List<Widget>.generate(4, (_) => const _BusinessCardSkeleton())
            else if (visibleBusinesses.isEmpty)
              _buildEmptyState(context, provider)
            else
              ...visibleBusinesses.map(
                (business) => BusinessCard(
                  business: business,
                  distanceKm: provider.isUsingGps ? provider.distanceFor(business) : null,
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
        ),
      ),
    );
  }

  List<Business> _buildVisibleBusinesses(BusinessProvider provider) {
    final businesses = provider.filteredBusinesses
        .where((business) => business.status.trim().toLowerCase() == 'approved')
        .toList();

    switch (_nearbySort) {
      case 'rating':
        businesses.sort((a, b) {
          final ratingCompare = b.rating.compareTo(a.rating);
          if (ratingCompare != 0) {
            return ratingCompare;
          }
          return b.reviewCount.compareTo(a.reviewCount);
        });
        break;
      case 'popular':
        businesses.sort((a, b) {
          final reviewsCompare = b.reviewCount.compareTo(a.reviewCount);
          if (reviewsCompare != 0) {
            return reviewsCompare;
          }
          return b.rating.compareTo(a.rating);
        });
        break;
      case 'closest':
      default:
        if (provider.isUsingGps) {
          businesses.sort((a, b) {
            final distanceA = provider.distanceFor(a);
            final distanceB = provider.distanceFor(b);
            final distanceCompare = distanceA.compareTo(distanceB);
            if (distanceCompare != 0) {
              return distanceCompare;
            }
            return b.rating.compareTo(a.rating);
          });
        }
        break;
    }
    return businesses;
  }

  Widget _buildSearchModule(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shadowColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.24)
        : Colors.black.withValues(alpha: 0.05);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            colors.surface,
            colors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find trusted local services fast',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Search nearby professionals and message them instantly.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 14),
          _buildSearchBar(context),
          const SizedBox(height: 14),
          if (_isLoadingRecentSearches == false && _recentSearches.isNotEmpty) ...[
            _buildChipLabel('Recent searches'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches
                  .map(
                    (term) => _buildSuggestionChip(
                      context,
                      label: term,
                      icon: Icons.history,
                      onTap: () => _openSearch(term),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
          ],
          _buildChipLabel('Popular suggestions'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _popularSuggestions
                .map(
                  (term) => _buildSuggestionChip(
                    context,
                    label: term,
                    icon: Icons.trending_up_rounded,
                    onTap: () => _openSearch(term),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChipLabel(String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }

  Widget _buildSuggestionChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 16, color: colors.primary),
      backgroundColor: colors.primary.withValues(alpha: 0.08),
      side: BorderSide(color: colors.primary.withValues(alpha: 0.12)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shadowColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.22)
        : Colors.black.withValues(alpha: 0.06);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openSearch(),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: colors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search barbers, salons, plumbers...',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.north_east_rounded,
              size: 18,
              color: colors.primary.withValues(alpha: 0.85),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explore categories',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Browse the most requested services near you.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _mainCategories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.58,
          ),
          itemBuilder: (context, index) {
            final category = _mainCategories[index];
            return _CategoryCard(
              category: category,
              onTap: () => _navigateToSubcategories(context, category),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNearYouSectionHeader(
    BuildContext context,
    BusinessProvider provider,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Near you',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                provider.isUsingManualArea
                    ? 'Showing businesses in ${provider.selectedArea}.'
                    : provider.isUsingGps
                        ? 'Showing businesses around ${provider.locationLabel}.'
                        : 'Choose a location to see nearby businesses.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () => _showAreaSelector(
            context,
            provider,
            includeGpsOption: true,
          ),
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: const Text('Change'),
        ),
      ],
    );
  }

  Widget _buildNearYouControls(
    BuildContext context,
    BusinessProvider provider,
  ) {
    final radiusChips = BusinessProvider.nearbyRadiusOptionsKm
        .map(
          (radiusKm) => ChoiceChip(
            label: Text('${radiusKm.toStringAsFixed(0)} km'),
            selected: provider.selectedNearbyRadiusKm == radiusKm,
            onSelected: (_) => provider.setNearbyRadius(radiusKm),
          ),
        )
        .toList();

    final sortChips = <Widget>[
      ChoiceChip(
        label: const Text('Closest'),
        selected: _nearbySort == 'closest',
        onSelected: (_) => setState(() => _nearbySort = 'closest'),
      ),
      ChoiceChip(
        label: const Text('Top Rated'),
        selected: _nearbySort == 'rating',
        onSelected: (_) => setState(() => _nearbySort = 'rating'),
      ),
      ChoiceChip(
        label: const Text('Most Popular'),
        selected: _nearbySort == 'popular',
        onSelected: (_) => setState(() => _nearbySort = 'popular'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: radiusChips),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: sortChips),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    BusinessProvider provider,
  ) {
    final colors = Theme.of(context).colorScheme;
    final subtitle = provider.isUsingGps
        ? 'No businesses found nearby. Try increasing your distance.'
        : provider.isUsingManualArea
            ? 'No businesses found in this area yet. Try changing your location.'
            : 'Choose your current location or pick a city or area first.';

    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.travel_explore_outlined,
              size: 30,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No businesses found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: () => _showAreaSelector(
              context,
              provider,
              includeGpsOption: true,
            ),
            icon: const Icon(Icons.location_searching_rounded),
            label: const Text('Change location'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSearch([String? initialQuery]) async {
    await Navigator.of(
      context,
    ).pushNamed('/search', arguments: initialQuery?.trim().isEmpty == true ? null : initialQuery);
    if (!mounted) {
      return;
    }
    await _loadRecentSearches();
  }

  Future<void> _navigateToSubcategories(
    BuildContext context,
    _MainCategory category,
  ) async {
    final mainCategory = category.name;
    final subcategories = _subcategoryMapping[mainCategory] ?? const <String>[];
    await Navigator.pushNamed(
      context,
      '/subcategories',
      arguments: SubcategoryScreenArgs(
        mainCategory: mainCategory,
        subcategories: subcategories,
      ),
    );
    if (!context.mounted) {
      return;
    }
    context.read<BusinessProvider>().clearCategoryScope();
  }

  String _headerLocationText(BusinessProvider provider) {
    if (provider.isUsingGps) {
      return '${provider.locationLabel} • ${provider.selectedNearbyRadiusKm.toStringAsFixed(0)} km';
    }
    if (provider.isUsingManualArea) {
      return '${provider.selectedArea} • Manual area';
    }
    return 'Choose your location';
  }

  void _showAreaSelector(
    BuildContext context,
    BusinessProvider provider, {
    required bool includeGpsOption,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: includeGpsOption,
      enableDrag: includeGpsOption,
      showDragHandle: true,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose location',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Change your area and nearby distance without leaving the home screen.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                Text(
                  'Distance',
                  style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BusinessProvider.nearbyRadiusOptionsKm
                      .map(
                        (radiusKm) => ChoiceChip(
                          label: Text('${radiusKm.toStringAsFixed(0)} km'),
                          selected: provider.selectedNearbyRadiusKm == radiusKm,
                          onSelected: (_) async {
                            await provider.setNearbyRadius(radiusKm);
                            if (!sheetContext.mounted) {
                              return;
                            }
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                if (includeGpsOption) ...[
                  Material(
                    color: colors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      leading: const Icon(Icons.my_location_rounded),
                      title: const Text('Use my current location'),
                      subtitle: Text(
                        'Show businesses within ${provider.selectedNearbyRadiusKm.toStringAsFixed(0)} km',
                      ),
                      trailing: provider.isUsingGps ? const Icon(Icons.check) : null,
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        final success = await provider.useCurrentLocation();
                        if (!context.mounted || success) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Location permission is required to use nearby results.',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Popular areas',
                  style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: _manualLocations.map((area) {
                      final isSelected =
                          provider.isUsingManualArea && provider.selectedArea == area;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(area),
                        trailing: isSelected ? const Icon(Icons.check) : null,
                        onTap: () async {
                          await provider.selectArea(area);
                          if (!sheetContext.mounted) {
                            return;
                          }
                          Navigator.of(sheetContext).pop();
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BusinessCardSkeleton extends StatelessWidget {
  const _BusinessCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = colors.surfaceContainerHighest.withValues(alpha: 0.85);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 110,
              height: 118,
              decoration: BoxDecoration(
                color: placeholder,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 16, color: placeholder),
                  const SizedBox(height: 12),
                  Container(height: 12, width: 150, color: placeholder),
                  const SizedBox(height: 10),
                  Container(height: 12, width: 130, color: placeholder),
                  const SizedBox(height: 14),
                  Container(height: 40, width: double.infinity, color: placeholder),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MainCategory {
  const _MainCategory({required this.name, required this.icon});

  final String name;
  final IconData icon;
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.onTap,
  });

  final _MainCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shadowColor = theme.brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.22)
        : Colors.black.withValues(alpha: 0.05);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(category.icon, size: 22, color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
