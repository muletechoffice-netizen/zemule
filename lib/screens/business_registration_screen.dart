import 'dart:collection';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:provider/provider.dart';
import 'package:zemule/providers/business_registration_provider.dart';
import 'package:zemule/utils/opening_hours.dart';
import 'package:zemule/widgets/opening_hours_editor.dart';
import 'package:zemule/widgets/registration_step_indicator.dart';

class BusinessRegistrationScreen extends StatefulWidget {
  const BusinessRegistrationScreen({super.key});

  @override
  State<BusinessRegistrationScreen> createState() => _BusinessRegistrationScreenState();
}

class _BusinessRegistrationScreenState extends State<BusinessRegistrationScreen> {
  static const int _maxPhotoCount = 5;
  static const int _maxPhotoBytes = 5 * 1024 * 1024;

  final ImagePicker _imagePicker = ImagePicker();
  final GlobalKey<FormState> _step4FormKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _yearEstablishedController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _whatsAppController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _addressSearchController = TextEditingController();
  final TextEditingController _manualAddressController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();

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

  static const Map<String, List<String>> _subcategoryMapping = <String, List<String>>{
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

  final List<String> _addressHintSuggestions = <String>[
    'Kabwata, Lusaka',
    'Matero, Lusaka',
    'Woodlands, Lusaka',
    'Kabulonga, Lusaka',
    'East Park Mall, Lusaka',
    'Lusaka City Market',
    'Chilenje, Lusaka',
  ];

  final List<_ServiceInput> _services = <_ServiceInput>[_ServiceInput()];

  late final LinkedHashMap<String, OpeningHoursDay> _openingHours =
      buildDefaultOpeningHoursEditorState();

  String? _selectedMainCategory;
  String? _selectedSubcategory;
  bool _agreeTerms = false;
  String _autoDetectedArea = '';
  String _autoDetectedAddress = '';
  String _autoDetectedCity = '';
  latlong2.LatLng _selectedPin = const latlong2.LatLng(-15.3875, 28.3228);
  final MapController _mapController = MapController();
  bool _isSearchingAddress = false;
  bool _isPickingPhoto = false;
  bool _hasConfirmedLocationPin = false;
  String? _step4RuntimeError;
  int _step4BoundaryRevision = 0;

  List<File> _photos = <File>[];
  List<String> _addressSuggestions = <String>[];

  @override
  void initState() {
    try {
      super.initState();
      _phoneController.text = '';
      _addressSearchController.addListener(_onAddressSearchChange);
    } catch (error, stackTrace) {
      _logRegistrationError(
        'initState',
        error,
        stackTrace,
        details: 'Failed to initialize registration screen state.',
      );
      rethrow;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _yearEstablishedController.dispose();
    _phoneController.dispose();
    _whatsAppController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _addressSearchController
      ..removeListener(_onAddressSearchChange)
      ..dispose();
    _manualAddressController.dispose();
    _areaController.dispose();
    for (final service in _services) {
      service.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Consumer<BusinessRegistrationProvider>(
        builder: (context, provider, _) {
          final baseTheme = Theme.of(context);
          final isDark = baseTheme.brightness == Brightness.dark;
          final registrationTheme = baseTheme.copyWith(
            colorScheme: baseTheme.colorScheme.copyWith(
              primary: const Color(0xFF1F4B99),
              secondary: isDark ? const Color(0xFF94A3B8) : const Color(0xFF4B5563),
              surface: isDark ? const Color(0xFF172033) : Colors.white,
              surfaceContainerHighest:
                  isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
              outlineVariant:
                  isDark ? const Color(0xFF334155) : Colors.grey.shade300,
              onPrimary: Colors.white,
              onSurface: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
            ),
            scaffoldBackgroundColor:
                isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
            textTheme: baseTheme.textTheme.apply(
              fontFamily: 'Roboto',
              bodyColor: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
              displayColor:
                  isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
            ),
            appBarTheme: baseTheme.appBarTheme.copyWith(
              backgroundColor: isDark ? const Color(0xFF172033) : Colors.white,
              foregroundColor:
                  isDark ? const Color(0xFFE5E7EB) : const Color(0xFF0F172A),
              elevation: 0,
              centerTitle: true,
            ),
            cardTheme: baseTheme.cardTheme.copyWith(
              color: isDark ? const Color(0xFF172033) : Colors.white,
              elevation: 1,
              shadowColor: Colors.black.withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          return Theme(
            data: registrationTheme,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Business Registration'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (provider.currentStep > 0) {
                      provider.goToPreviousStep();
                      return;
                    }
                    Navigator.of(context).maybePop();
                  },
                ),
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (provider.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(minHeight: 4),
                    ),
                  RegistrationStepIndicator(
                    currentStep: provider.currentStep,
                    onStepTap: (step) => provider.jumpToStep(step),
                  ),
                  const SizedBox(height: 16),
                  _buildStepTitle(provider.currentStep),
                  const SizedBox(height: 12),
                  _buildCurrentStep(provider.currentStep),
                  const SizedBox(height: 20),
                  if (provider.currentStep < BusinessRegistrationProvider.lastStepIndex)
                    Row(
                      children: [
                        if (provider.currentStep > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: provider.goToPreviousStep,
                              child: const Text('Back'),
                            ),
                          ),
                        if (provider.currentStep > 0) const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: provider.isLoading ? null : _continueToNextStep,
                            child: const Text('Continue'),
                          ),
                        ),
                      ],
                    )
                  else
                    FilledButton(
                      onPressed: provider.isLoading ? null : _submitForReview,
                      child: provider.isLoading
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Submitting...'),
                                  SizedBox(height: 6),
                                  SizedBox(height: 4, child: LinearProgressIndicator(minHeight: 4)),
                                ],
                              ),
                            )
                          : const Text('Submit for Review'),
                    ),
                ],
              ),
            ),
          );
        },
      );
    } catch (error, stackTrace) {
      debugPrint('BusinessRegistrationScreen build error: $error');
      debugPrint('BusinessRegistrationScreen build stackTrace: $stackTrace');
      return Scaffold(
        appBar: AppBar(title: const Text('Business Registration')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Something went wrong while rendering this screen.'),
          ),
        ),
      );
    }
  }

  Widget _buildStepTitle(int step) {
    const titles = <String>[
      'Select your business category',
      'Basic Information',
      'Contact Information',
      'Location',
      'Add photos of your business',
      'Add your services',
      'Review & Submit',
    ];
    return Text(
      titles[step],
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _buildCurrentStep(int step) {
    switch (step) {
      case 0:
        return _buildStepBusinessType();
      case 1:
        return _buildStepBasicInfo();
      case 2:
        return _buildStepContactInfo();
      case 3:
        return _buildStepLocation();
      case 4:
        return _buildStepPhotos();
      case 5:
        return _buildStepServices();
      case 6:
        return _buildStepReview();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStepBusinessType() {
    final colors = Theme.of(context).colorScheme;
    final subcategories = _selectedMainCategory == null
        ? const <String>[]
        : (_subcategoryMapping[_selectedMainCategory!] ?? const <String>[]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 1: Select main category',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          itemCount: _mainCategories.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (context, index) {
            final category = _mainCategories[index];
            final selected = _selectedMainCategory == category.name;
            final background =
                selected ? colors.primary.withValues(alpha: 0.08) : Colors.white;
            final borderColor = selected ? colors.primary : colors.outlineVariant;
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                setState(() {
                  _selectedMainCategory = category.name;
                  // Reset subcategory when main changes
                  _selectedSubcategory = null;
                });
              },
              child: Ink(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: background,
                  border: Border.all(color: borderColor),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      category.icon,
                      size: 28,
                      color: selected ? colors.primary : Colors.blueGrey.shade600,
                    ),
                    Text(
                      category.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.onSurface,
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Step 2: Select subcategory',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (_selectedMainCategory == null)
          Text(
            'Choose a main category first.',
            style: TextStyle(color: Colors.grey.shade600),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: subcategories.map((subcategory) {
              final selected = _selectedSubcategory == subcategory;
              return ChoiceChip(
                label: Text(subcategory),
                selected: selected,
                selectedColor: colors.primary.withValues(alpha: 0.14),
                side: BorderSide(color: selected ? colors.primary : colors.outlineVariant),
                labelStyle: TextStyle(
                  color: selected ? colors.primary : colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() => _selectedSubcategory = subcategory),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildStepBasicInfo() {
    return Column(
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Business name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _descriptionController,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Business description (optional, max 200 words)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text('${_wordCount(_descriptionController.text)}/200 words'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _yearEstablishedController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Year established (optional)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildStepContactInfo() {
    return Column(
      children: [
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _whatsAppController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp number (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => setState(() => _whatsAppController.text = _phoneController.text.trim()),
              child: const Text('Same'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _websiteController,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Website (optional)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildStepLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _addressSearchController,
          decoration: InputDecoration(
            labelText: 'Search for your business address',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: _isSearchingAddress ? null : _searchAndPinAddress,
            ),
          ),
          onSubmitted: (_) => _searchAndPinAddress(),
        ),
        if (_isSearchingAddress)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 4),
          ),
        if (_addressSuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: _addressSuggestions.map((suggestion) {
                return ListTile(
                  dense: true,
                  title: Text(suggestion),
                  onTap: () {
                    _addressSearchController.text = suggestion;
                    _searchAndPinAddress();
                  },
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: 240,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _selectedPin,
                  initialZoom: 14,
                  onTap: (_, position) => _setPinAndDetectArea(position),
                  onLongPress: (_, position) => _setPinAndDetectArea(position),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.zemule.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedPin,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 38,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _autoDetectedArea.isEmpty
              ? 'Area auto-detected: Not detected yet'
              : 'Area auto-detected: $_autoDetectedArea',
        ),
        const SizedBox(height: 6),
        Text(
          _autoDetectedCity.isEmpty
              ? 'City auto-detected: Not detected yet'
              : 'City auto-detected: $_autoDetectedCity',
        ),
        const SizedBox(height: 6),
        Text(
          _hasConfirmedLocationPin
              ? 'Location pin confirmed.'
              : 'Search for the address or tap the map to confirm the exact business location.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _areaController,
          decoration: const InputDecoration(
            labelText: 'Area',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _manualAddressController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Manual address input fallback',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildStepPhotos() {
    return _StepErrorBoundary(
      key: ValueKey(_step4BoundaryRevision),
      scope: 'BusinessRegistration/Step4',
      onError: (error, stackTrace) {
        _logRegistrationError(
          'step4_build',
          error,
          stackTrace,
          details: 'Step 4 crashed while rendering.',
        );
      },
      fallback: _buildStep4FailureFallback(),
      childBuilder: (context) => _buildStepPhotosContent(),
    );
  }

  Widget _buildStepPhotosContent() {
    final provider = context.watch<BusinessRegistrationProvider>();
    final safeBusinessName = provider.registrationData['name']?.toString().trim().isNotEmpty == true
        ? provider.registrationData['name'].toString().trim()
        : 'Unnamed business';
    final safeMain = provider.registrationData['mainCategory']?.toString().trim().isNotEmpty == true
        ? provider.registrationData['mainCategory'].toString().trim()
        : (_selectedMainCategory ?? '');
    final safeSub = provider.registrationData['subcategory']?.toString().trim().isNotEmpty == true
        ? provider.registrationData['subcategory'].toString().trim()
        : (_selectedSubcategory ?? '');
    String safeCategory = [
      if (safeMain.isNotEmpty) safeMain,
      if (safeSub.isNotEmpty) safeSub,
    ].join(' • ');
    if (safeCategory.isEmpty) {
      safeCategory = 'No category selected';
    }
    final safeAddress = provider.registrationData['address']?.toString().trim().isNotEmpty == true
        ? provider.registrationData['address'].toString().trim()
        : 'No address yet';

    return Form(
      key: _step4FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Uploaded: ${_photos.length}/$_maxPhotoCount'),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                'Business: $safeBusinessName\nCategory: $safeCategory\nAddress: $safeAddress',
              ),
            ),
          ),
          if (_step4RuntimeError != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Text(
                _step4RuntimeError!,
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      (_photos.length >= _maxPhotoCount || _isPickingPhoto) ? null : _pickPhotoFromCamera,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      (_photos.length >= _maxPhotoCount || _isPickingPhoto) ? null : _pickPhotosFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          if (_isPickingPhoto) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 10),
          if (_photos.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Add at least 1 photo. First photo becomes cover image.'),
            )
          else
            SizedBox(
              height: 280,
              child: ReorderableListView.builder(
                itemCount: _photos.length,
                onReorder: _reorderPhotos,
                itemBuilder: (context, index) {
                  final file = _photos[index];
                  return Card(
                    key: ValueKey('${file.path}_$index'),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          file,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          cacheWidth: 300,
                          filterQuality: FilterQuality.low,
                          errorBuilder: (_, error, stackTrace) {
                            _logRegistrationError(
                              'step4_image_preview',
                              error,
                              stackTrace ?? StackTrace.current,
                              details: 'Failed to render image preview for ${file.path}',
                            );
                            return const SizedBox(
                              width: 52,
                              height: 52,
                              child: ColoredBox(color: Colors.black12),
                            );
                          },
                        ),
                      ),
                      title: Text(index == 0 ? 'Cover image' : 'Photo ${index + 1}'),
                      subtitle: const Text('Drag to reorder'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          if (index < 0 || index >= _photos.length) {
                            return;
                          }
                          setState(() => _photos.removeAt(index));
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep4FailureFallback() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
        color: Colors.red.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 4 failed to load.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text('Try re-opening this step. If it persists, clear problematic photos and retry.'),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _step4RuntimeError = null;
                _step4BoundaryRevision += 1;
              });
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepServices() {
    return Column(
      children: [
        ..._services.asMap().entries.map((entry) {
          final index = entry.key;
          final service = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  TextField(
                    controller: service.nameController,
                    decoration: InputDecoration(
                      labelText: 'Service name ${index + 1}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: service.priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Price (K)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_services.length > 1)
                        IconButton(
                          onPressed: () => _removeService(index),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _addService,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ),
      ],
    );
  }

  Widget _buildStepReview() {
    final services = _services
        .map((item) => <String, String>{
              'name': item.nameController.text.trim(),
              'price': item.priceController.text.trim(),
            })
        .where((item) => item['name']!.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _reviewSection(
          title: 'Business Type',
          onEdit: () => context.read<BusinessRegistrationProvider>().jumpToStep(0),
          child: Text(
            [
              _selectedMainCategory ?? 'Main category not selected',
              _selectedSubcategory ?? 'Subcategory not selected',
            ].join(' • '),
          ),
        ),
        _reviewSection(
          title: 'Basic Info',
          onEdit: () => context.read<BusinessRegistrationProvider>().jumpToStep(1),
          child: Text(
            'Name: ${_nameController.text.trim()}\n'
            'Description: ${_descriptionController.text.trim().isEmpty ? '-' : _descriptionController.text.trim()}\n'
            'Year: ${_yearEstablishedController.text.trim().isEmpty ? '-' : _yearEstablishedController.text.trim()}',
          ),
        ),
        _reviewSection(
          title: 'Contact Info',
          onEdit: () => context.read<BusinessRegistrationProvider>().jumpToStep(2),
          child: Text(
            'Phone: ${_phoneController.text.trim()}\n'
            'WhatsApp: ${_whatsAppController.text.trim().isEmpty ? '-' : _whatsAppController.text.trim()}\n'
            'Email: ${_emailController.text.trim().isEmpty ? '-' : _emailController.text.trim()}\n'
            'Website: ${_websiteController.text.trim().isEmpty ? '-' : _websiteController.text.trim()}',
          ),
        ),
        _reviewSection(
          title: 'Location',
          onEdit: () => context.read<BusinessRegistrationProvider>().jumpToStep(3),
          child: Text(
            'Address: ${_manualAddressController.text.trim().isEmpty ? _addressSearchController.text.trim() : _manualAddressController.text.trim()}\n'
            'Area: ${_areaController.text.trim()}\n'
            'City: ${_autoDetectedCity.isEmpty ? '-' : _autoDetectedCity}\n'
            'Lat/Lng: ${_selectedPin.latitude.toStringAsFixed(6)}, ${_selectedPin.longitude.toStringAsFixed(6)}',
          ),
        ),
        _reviewSection(
          title: 'Photos',
          onEdit: () => context.read<BusinessRegistrationProvider>().jumpToStep(4),
          child: Text('${_photos.length} photo(s) added'),
        ),
        _reviewSection(
          title: 'Services & Prices',
          onEdit: () => context.read<BusinessRegistrationProvider>().jumpToStep(5),
          child: Text(
            services.isEmpty
                ? 'No services'
                : services.map((service) => '${service['name']} - K${service['price']}').join('\n'),
          ),
        ),
        _buildOpeningHoursEditor(),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _agreeTerms,
          onChanged: (value) => setState(() => _agreeTerms = value ?? false),
          title: const Text('I agree to the terms'),
        ),
      ],
    );
  }

  Widget _reviewSection({
    required String title,
    required Widget child,
    required VoidCallback onEdit,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                TextButton(onPressed: onEdit, child: const Text('Edit')),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildOpeningHoursEditor() {
    return OpeningHoursEditor(
      hoursByDay: _openingHours,
      onChanged: () => setState(() {}),
    );
  }

  Future<void> _continueToNextStep() async {
    final provider = context.read<BusinessRegistrationProvider>();
    final step = provider.currentStep;

    try {
      _saveStepData(step);
      provider.validateStep(step);
      provider.goToNextStep();
    } on FormatException catch (error) {
      _showErrorSafe(error.message);
    } catch (error, stackTrace) {
      _logRegistrationError('continue_to_next_step', error, stackTrace);
      _showErrorSafe('Something went wrong. Please try again.');
    }
  }

  Future<bool> _validateBeforeSubmit() async {
    for (int step = 0; step <= BusinessRegistrationProvider.lastStepIndex; step++) {
      _saveStepData(step);
    }
    final provider = context.read<BusinessRegistrationProvider>();
    final issues = provider.collectValidationIssues();
    if (issues.isEmpty) {
      return true;
    }

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Missing or invalid details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...issues.map(
              (issue) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(issue)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close & Fix'),
              ),
            ),
          ],
        ),
      ),
    );
    return false;
  }

  Future<void> _submitForReview() async {
    final provider = context.read<BusinessRegistrationProvider>();

    try {
      final isValid = await _validateBeforeSubmit();
      if (!isValid) {
        return;
      }
      await provider.submitBusiness();
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Submitted'),
          content: const Text('Your business is pending approval'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/business-dashboard', (route) => false);
    } on FormatException catch (error) {
      _showErrorSafe(error.message);
    } catch (error, stackTrace) {
      _logRegistrationError('submit_for_review', error, stackTrace);
      final raw = error.toString();
      final message = raw.startsWith('Exception: ') ? raw.substring(11).trim() : 'Failed to submit. Please try again.';
      _showErrorSafe(message.isEmpty ? 'Failed to submit. Please try again.' : message);
    }
  }

  void _saveStepData(int step) {
    final provider = context.read<BusinessRegistrationProvider>();
    switch (step) {
      case 0:
        provider.updateStepData(step, <String, dynamic>{
          'mainCategory': _selectedMainCategory?.trim() ?? '',
          'subcategory': _selectedSubcategory?.trim() ?? '',
          // Legacy field for compatibility
          'category': _selectedSubcategory?.trim() ?? '',
        });
        break;
      case 1:
        provider.updateStepData(step, <String, dynamic>{
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'yearEstablished': int.tryParse(_yearEstablishedController.text.trim()),
        });
        break;
      case 2:
        provider.updateStepData(step, <String, dynamic>{
          'phoneNumber': _phoneController.text.trim(),
          'whatsappNumber': _whatsAppController.text.trim(),
          'email': _emailController.text.trim(),
          'website': _websiteController.text.trim(),
        });
        break;
      case 3:
        provider.updateStepData(step, <String, dynamic>{
          'address': _manualAddressController.text.trim().isNotEmpty
              ? _manualAddressController.text.trim()
              : _addressSearchController.text.trim(),
          'area': _areaController.text.trim(),
          'city': _autoDetectedCity.trim(),
          'latitude': _hasConfirmedLocationPin ? _selectedPin.latitude : null,
          'longitude': _hasConfirmedLocationPin ? _selectedPin.longitude : null,
        });
        break;
      case 4:
        provider.setUploadedPhotos(_photos);
        break;
      case 5:
        final services = _services
            .map((item) => <String, dynamic>{
                  'name': item.nameController.text.trim(),
                  'price': item.priceController.text.trim(),
                })
            .where((item) => (item['name'] as String).isNotEmpty)
            .toList();
        provider.updateStepData(step, <String, dynamic>{'services': services});
        break;
      case 6:
        provider.updateStepData(step, <String, dynamic>{
          'agreedToTerms': _agreeTerms,
          'openingHours': _openingHours.map((day, value) => MapEntry(day, value.toMap())),
        });
        break;
    }
  }

  Future<void> _searchAndPinAddress() async {
    final query = _addressSearchController.text.trim();
    if (query.isEmpty) {
      return;
    }

    setState(() => _isSearchingAddress = true);

    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) {
        _showErrorSafe('Address not found. You can still pin manually.');
        return;
      }
      final location = locations.first;
      final latLng = latlong2.LatLng(location.latitude, location.longitude);
      await _setPinAndDetectArea(latLng);
      _mapController.move(latLng, 16);
    } catch (_) {
      _showErrorSafe('Address search failed. Try another address or use manual pin.');
    } finally {
      if (mounted) {
        setState(() => _isSearchingAddress = false);
      }
    }
  }

  Future<void> _setPinAndDetectArea(latlong2.LatLng position) async {
    final previousAutoDetectedArea = _autoDetectedArea;
    final previousAutoDetectedAddress = _autoDetectedAddress;
    setState(() {
      _selectedPin = position;
      _hasConfirmedLocationPin = true;
    });
    try {
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isEmpty) {
        setState(() {
          _autoDetectedArea = '';
          _autoDetectedCity = '';
          _autoDetectedAddress = '';
          if (_areaController.text.trim() == previousAutoDetectedArea) {
            _areaController.clear();
          }
          if (_manualAddressController.text.trim() ==
              previousAutoDetectedAddress) {
            _manualAddressController.clear();
          }
        });
        return;
      }

      final place = placemarks.first;
      final area = place.subLocality?.trim().isNotEmpty == true
          ? place.subLocality!.trim()
          : (place.locality?.trim() ?? '');
      final city = place.locality?.trim().isNotEmpty == true
          ? place.locality!.trim()
          : place.subAdministrativeArea?.trim().isNotEmpty == true
              ? place.subAdministrativeArea!.trim()
              : place.administrativeArea?.trim().isNotEmpty == true
                  ? place.administrativeArea!.trim()
                  : area;
      final streetAddress = <String>[
        if ((place.street ?? '').trim().isNotEmpty) place.street!.trim(),
        if ((place.subLocality ?? '').trim().isNotEmpty) place.subLocality!.trim(),
        if ((place.locality ?? '').trim().isNotEmpty) place.locality!.trim(),
      ].join(', ');

      setState(() {
        _autoDetectedArea = area;
        _autoDetectedCity = city;
        if (area.isNotEmpty &&
            (_areaController.text.trim().isEmpty ||
                _areaController.text.trim() == previousAutoDetectedArea)) {
          _areaController.text = area;
        }
        _autoDetectedAddress = streetAddress;
        if (streetAddress.isNotEmpty &&
            (_manualAddressController.text.trim().isEmpty ||
                _manualAddressController.text.trim() ==
                    previousAutoDetectedAddress)) {
          _manualAddressController.text = streetAddress;
        }
      });
    } catch (_) {}
  }

  Future<void> _pickPhotoFromCamera() async {
    if (_photos.length >= _maxPhotoCount || _isPickingPhoto) {
      if (_photos.length >= _maxPhotoCount) {
        final message = 'You can upload up to $_maxPhotoCount photos only.';
        setState(() => _step4RuntimeError = message);
        _showErrorSafe(message);
      }
      return;
    }
    setState(() {
      _isPickingPhoto = true;
      _step4RuntimeError = null;
    });
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 72,
        maxWidth: 1600,
      );
      if (!mounted || picked == null) {
        return;
      }

      final file = File(picked.path);
      final validationError = await _validateStep4Photo(file);
      if (!mounted) {
        return;
      }
      if (validationError != null) {
        setState(() => _step4RuntimeError = validationError);
        _showErrorSafe(validationError);
        return;
      }

      setState(() => _photos = <File>[..._photos, file]);
    } on PlatformException catch (error, stackTrace) {
      _logRegistrationError(
        'step4_pick_camera_platform',
        error,
        stackTrace,
        details: 'Camera permission denied or unavailable.',
      );
      if (!mounted) {
        return;
      }
      const message = 'Unable to access camera. Check camera permission and try again.';
      setState(() => _step4RuntimeError = message);
      _showErrorSafe(message);
    } catch (error, stackTrace) {
      _logRegistrationError('step4_pick_camera', error, stackTrace);
      if (!mounted) {
        return;
      }
      const message = 'Failed to capture photo. Please try again.';
      setState(() => _step4RuntimeError = message);
      _showErrorSafe(message);
    } finally {
      if (mounted) {
        setState(() => _isPickingPhoto = false);
      }
    }
  }

  Future<void> _pickPhotosFromGallery() async {
    final remaining = _maxPhotoCount - _photos.length;
    if (remaining <= 0 || _isPickingPhoto) {
      if (remaining <= 0) {
        final message = 'You can upload up to $_maxPhotoCount photos only.';
        setState(() => _step4RuntimeError = message);
        _showErrorSafe(message);
      }
      return;
    }
    setState(() {
      _isPickingPhoto = true;
      _step4RuntimeError = null;
    });
    try {
      final picked = await _imagePicker.pickMultiImage(imageQuality: 72, maxWidth: 1600);
      if (!mounted || picked.isEmpty) {
        return;
      }
      if (picked.length > remaining) {
        final message = 'You can upload up to $_maxPhotoCount photos only.';
        setState(() => _step4RuntimeError = message);
        _showErrorSafe(message);
      }

      final files = <File>[];
      for (final xFile in picked.take(remaining)) {
        final file = File(xFile.path);
        final validationError = await _validateStep4Photo(file);
        if (validationError != null) {
          _logRegistrationError(
            'step4_pick_gallery_validation',
            Exception(validationError),
            StackTrace.current,
            details: 'Skipped invalid gallery image: ${xFile.path}',
          );
          continue;
        }
        files.add(file);
      }

      if (!mounted) {
        return;
      }
      if (files.isEmpty) {
        const message = 'No valid photos selected. Each photo must be under 5MB.';
        setState(() => _step4RuntimeError = message);
        _showErrorSafe(message);
        return;
      }
      setState(() => _photos = <File>[..._photos, ...files]);
    } on PlatformException catch (error, stackTrace) {
      _logRegistrationError(
        'step4_pick_gallery_platform',
        error,
        stackTrace,
        details: 'Gallery permission denied or unavailable.',
      );
      if (!mounted) {
        return;
      }
      const message = 'Unable to access gallery. Check photos permission and try again.';
      setState(() => _step4RuntimeError = message);
      _showErrorSafe(message);
    } catch (error, stackTrace) {
      _logRegistrationError('step4_pick_gallery', error, stackTrace);
      if (!mounted) {
        return;
      }
      const message = 'Failed to select photos. Please try again.';
      setState(() => _step4RuntimeError = message);
      _showErrorSafe(message);
    } finally {
      if (mounted) {
        setState(() => _isPickingPhoto = false);
      }
    }
  }

  void _reorderPhotos(int oldIndex, int newIndex) {
    setState(() {
      final list = List<File>.from(_photos);
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      _photos = list;
    });
  }

  void _addService() {
    setState(() => _services.add(_ServiceInput()));
  }

  void _removeService(int index) {
    final service = _services[index];
    service.dispose();
    setState(() => _services.removeAt(index));
  }

  int _wordCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    return trimmed.split(RegExp(r'\s+')).length;
  }

  void _onAddressSearchChange() {
    final query = _addressSearchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _addressSuggestions = <String>[];
      } else {
        _addressSuggestions = _addressHintSuggestions
            .where((item) => item.toLowerCase().contains(query))
            .take(4)
            .toList();
      }
    });
  }

  void _showErrorSafe(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      debugPrint('BusinessRegistrationScreen snack error: $message');
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _validateStep4Photo(File file) async {
    try {
      final exists = await file.exists();
      if (!exists) {
        return 'Selected photo is unavailable. Please choose another file.';
      }
      final lengthBytes = await file.length();
      if (lengthBytes <= 0) {
        return 'Selected photo is empty. Please choose another file.';
      }
      if (lengthBytes > _maxPhotoBytes) {
        return 'Photo is too large (${(lengthBytes / (1024 * 1024)).toStringAsFixed(1)}MB). Max size is 5MB.';
      }
      return null;
    } catch (error, stackTrace) {
      _logRegistrationError('step4_file_validation', error, stackTrace);
      return 'Failed to validate selected photo.';
    }
  }

  void _logRegistrationError(
    String scope,
    Object error,
    StackTrace stackTrace, {
    String? details,
  }) {
    final message = details == null ? '$scope -> $error' : '$scope -> $details | $error';
    debugPrint('BusinessRegistrationError: $message');
    debugPrint('BusinessRegistrationErrorStack: $stackTrace');
    developer.log(
      message,
      name: 'BusinessRegistrationScreen',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

class _StepErrorBoundary extends StatefulWidget {
  const _StepErrorBoundary({
    super.key,
    required this.scope,
    required this.childBuilder,
    required this.fallback,
    this.onError,
  });

  final String scope;
  final WidgetBuilder childBuilder;
  final Widget fallback;
  final void Function(Object error, StackTrace stackTrace)? onError;

  @override
  State<_StepErrorBoundary> createState() => _StepErrorBoundaryState();
}

class _StepErrorBoundaryState extends State<_StepErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.fallback;
    }

    try {
      return widget.childBuilder(context);
    } catch (error, stackTrace) {
      _error = error;
      _stackTrace = stackTrace;
      widget.onError?.call(error, stackTrace);
      debugPrint('StepErrorBoundary(${widget.scope}) error: $error');
      debugPrint('StepErrorBoundary(${widget.scope}) stackTrace: $_stackTrace');
      return widget.fallback;
    }
  }
}

class _ServiceInput {
  _ServiceInput({
    String name = '',
    String price = '',
  })  : nameController = TextEditingController(text: name),
        priceController = TextEditingController(text: price);

  final TextEditingController nameController;
  final TextEditingController priceController;

  void dispose() {
    nameController.dispose();
    priceController.dispose();
  }
}

class _MainCategory {
  const _MainCategory({required this.name, required this.icon});

  final String name;
  final IconData icon;
}
