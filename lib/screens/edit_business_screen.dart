import 'dart:io';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:zemule/models/business.dart';
import 'package:zemule/providers/business_provider.dart';
import 'package:zemule/services/supabase_service.dart';
import 'package:zemule/utils/opening_hours.dart';
import 'package:zemule/widgets/opening_hours_editor.dart';

class EditBusinessScreen extends StatefulWidget {
  const EditBusinessScreen({super.key});

  @override
  State<EditBusinessScreen> createState() => _EditBusinessScreenState();
}

class _EditBusinessScreenState extends State<EditBusinessScreen> {
  static const int _maxPhotoCount = 5;
  static const int _maxPhotoBytes = 5 * 1024 * 1024;

  final SupabaseService _supabase = SupabaseService.instance;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  int _currentStep = 0;
  bool _isSaving = false;
  bool _loaded = false;
  String? _businessId;
  int? _initialStepOverride;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();

  final List<Map<String, String>> _services = <Map<String, String>>[];
  late final LinkedHashMap<String, OpeningHoursDay> _hours =
      buildDefaultOpeningHoursEditorState();

  List<String> _existingPhotoUrls = <String>[];
  List<File> _newPhotos = <File>[];

  int get _totalPhotos => _existingPhotoUrls.length + _newPhotos.length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) {
      return;
    }
    _loaded = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      _businessId = args;
    } else if (args is Map) {
      final map = args.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final businessId = map['businessId']?.toString().trim() ?? '';
      _businessId = businessId.isEmpty ? null : businessId;
      final initialStep = map['initialStep'];
      if (initialStep is int) {
        _initialStepOverride = initialStep;
      } else if (initialStep is num) {
        _initialStepOverride = initialStep.toInt();
      } else if (initialStep is String) {
        _initialStepOverride = int.tryParse(initialStep);
      }
      if (_initialStepOverride != null) {
        _currentStep = _initialStepOverride!.clamp(0, 5);
      }
    }
    _loadBusiness();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _areaController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Business')),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepTapped: (value) => setState(() => _currentStep = value),
          onStepContinue: _onContinue,
          onStepCancel: _onCancel,
          controlsBuilder: (context, details) {
            return Row(
              children: [
                FilledButton(
                  onPressed: details.onStepContinue,
                  child: Text(_currentStep == 5 ? 'Review' : 'Next'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Back'),
                ),
              ],
            );
          },
          steps: [
            Step(
              title: const Text('Basic Info'),
              isActive: _currentStep >= 0,
              content: _buildBasicInfoStep(),
            ),
            Step(
              title: const Text('Contact'),
              isActive: _currentStep >= 1,
              content: _buildContactStep(),
            ),
            Step(
              title: const Text('Location'),
              isActive: _currentStep >= 2,
              content: _buildLocationStep(),
            ),
            Step(
              title: const Text('Photos'),
              isActive: _currentStep >= 3,
              content: _buildPhotosStep(),
            ),
            Step(
              title: const Text('Services'),
              isActive: _currentStep >= 4,
              content: _buildServicesStep(),
            ),
            Step(
              title: const Text('Hours'),
              isActive: _currentStep >= 5,
              content: _buildHoursStep(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: _isSaving ? null : _saveChanges,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Business name'),
          validator: (value) => (value?.trim().isEmpty ?? true) ? 'Required' : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _categoryController,
          decoration: const InputDecoration(labelText: 'Category'),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _descriptionController,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildContactStep() {
    return Column(
      children: [
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone'),
          validator: (value) => (value?.trim().isEmpty ?? true) ? 'Required' : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _whatsappController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'WhatsApp'),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
      ],
    );
  }

  Widget _buildLocationStep() {
    return Column(
      children: [
        TextFormField(
          controller: _addressController,
          decoration: const InputDecoration(labelText: 'Address'),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _areaController,
          decoration: const InputDecoration(labelText: 'Area'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _latitudeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Latitude'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _longitudeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Longitude'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade200,
          ),
          alignment: Alignment.center,
          child: const Text('Map pin preview'),
        ),
      ],
    );
  }

  Widget _buildPhotosStep() {
    final allItems = <_PhotoItem>[
      ..._existingPhotoUrls.map((url) => _PhotoItem(url: url)),
      ..._newPhotos.map((file) => _PhotoItem(file: file)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Uploaded: $_totalPhotos/$_maxPhotoCount'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: allItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: item.url != null
                      ? Image.network(
                          item.url!,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _photoPlaceholder(),
                        )
                      : Image.file(
                          item.file!,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                ),
                Positioned(
                  right: 2,
                  top: 2,
                  child: InkWell(
                    onTap: () => _deletePhotoAt(index),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black54,
                      ),
                      padding: const EdgeInsets.all(3),
                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _addPhotoFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Upload'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _reorderPhotos,
              icon: const Icon(Icons.swap_vert_outlined),
              label: const Text('Reorder'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServicesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_services.isEmpty)
          const Text('No services added')
        else
          ..._services.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Card(
              child: ListTile(
                title: Text(item['name'] ?? ''),
                subtitle: Text(item['price'] ?? ''),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      onPressed: () => _editService(index),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: () => _deleteService(index),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addService,
          icon: const Icon(Icons.add),
          label: const Text('Add service'),
        ),
      ],
    );
  }

  Widget _buildHoursStep() {
    return OpeningHoursEditor(
      hoursByDay: _hours,
      onChanged: () => setState(() {}),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      width: 90,
      height: 90,
      color: Colors.grey.shade200,
      child: const Icon(Icons.photo_outlined),
    );
  }

  Future<void> _loadBusiness() async {
    String? id = _businessId;
    if (id == null) {
      final provider = context.read<BusinessProvider>();
      if (provider.businesses.isEmpty) {
        await provider.fetchBusinesses();
      }
      if (provider.businesses.isNotEmpty) {
        id = provider.businesses.first.id;
      }
      _businessId = id;
    }

    if (id == null) {
      return;
    }

    final data = await _supabase.getBusinessById(id);
    if (data == null) {
      return;
    }

    final business = Business.fromMap(data);

    _nameController.text = business.name;
    _categoryController.text = business.subcategory;
    _descriptionController.text = business.description;
    _phoneController.text = business.phoneNumber;
    _whatsappController.text = business.whatsappNumber ?? '';
    _emailController.text = (data['email'] as String?) ?? '';
    _addressController.text = business.address;
    _areaController.text = business.area;
    _latitudeController.text = business.latitude.toString();
    _longitudeController.text = business.longitude.toString();
    _existingPhotoUrls = List<String>.from(business.photoUrls);

    final servicesRaw = (data['services'] as List?) ?? <dynamic>[];
    _services
      ..clear()
      ..addAll(servicesRaw.map((item) {
        if (item is Map<String, dynamic>) {
          return <String, String>{
            'id': item['id']?.toString() ?? '',
            'name': item['name']?.toString() ?? '',
            'price': item['price']?.toString() ?? '',
          };
        }
        if (item is Map) {
          return <String, String>{
            'id': item['id']?.toString() ?? '',
            'name': item['name']?.toString() ?? '',
            'price': item['price']?.toString() ?? '',
          };
        }
        return <String, String>{'id': '', 'name': '', 'price': ''};
      }).where((item) => (item['name'] ?? '').trim().isNotEmpty));

    final hoursRaw = data['opening_hours'] ?? data['openingHours'];
    final normalizedHours = normalizeOpeningHoursEditorState(hoursRaw);
    for (final entry in normalizedHours.entries) {
      _hours[entry.key] = entry.value;
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _onContinue() {
    if (_currentStep < 5) {
      setState(() => _currentStep += 1);
    }
  }

  void _onCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  Future<void> _addPhotoFromGallery() async {
    if (_totalPhotos >= _maxPhotoCount) {
      _showErrorSafe('You can upload up to $_maxPhotoCount photos only.');
      return;
    }

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 72,
        maxWidth: 1600,
      );
      if (!mounted || picked == null) {
        return;
      }

      final file = File(picked.path);
      final validationError = await _validatePhotoFile(file);
      if (!mounted) {
        return;
      }
      if (validationError != null) {
        _showErrorSafe(validationError);
        return;
      }
      setState(() {
        _newPhotos = <File>[..._newPhotos, file];
      });
    } on PlatformException {
      _showErrorSafe('Unable to access gallery. Check photos permission and try again.');
    } catch (_) {
      _showErrorSafe('Failed to select photo. Please try again.');
    }
  }

  void _deletePhotoAt(int index) {
    setState(() {
      if (index < _existingPhotoUrls.length) {
        _existingPhotoUrls = List<String>.from(_existingPhotoUrls)..removeAt(index);
      } else {
        final fileIndex = index - _existingPhotoUrls.length;
        _newPhotos = List<File>.from(_newPhotos)..removeAt(fileIndex);
      }
    });
  }

  void _reorderPhotos() {
    final combined = <_PhotoItem>[
      ..._existingPhotoUrls.map((url) => _PhotoItem(url: url)),
      ..._newPhotos.map((file) => _PhotoItem(file: file)),
    ];
    if (combined.length < 2) {
      return;
    }

    final rotated = <_PhotoItem>[...combined.skip(1), combined.first];
    setState(() {
      _existingPhotoUrls = rotated.where((item) => item.url != null).map((e) => e.url!).toList();
      _newPhotos = rotated.where((item) => item.file != null).map((e) => e.file!).toList();
    });
  }

  Future<void> _addService() async {
    final result = await _showServiceDialog();
    if (result == null) {
      return;
    }
    setState(() {
      _services.add(<String, String>{
        'id': '',
        'name': result.$1,
        'price': result.$2,
      });
    });
  }

  Future<void> _editService(int index) async {
    final current = _services[index];
    final result = await _showServiceDialog(
      name: current['name'],
      price: current['price'],
    );
    if (result == null) {
      return;
    }
    setState(() {
      _services[index] = <String, String>{
        'id': current['id'] ?? '',
        'name': result.$1,
        'price': result.$2,
      };
    });
  }

  void _deleteService(int index) {
    setState(() {
      _services.removeAt(index);
    });
  }

  Future<(String, String)?> _showServiceDialog({
    String? name,
    String? price,
  }) async {
    final nameController = TextEditingController(text: name ?? '');
    final priceController = TextEditingController(text: price ?? '');
    return showDialog<(String, String)>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(name == null ? 'Add Service' : 'Edit Service'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Service name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final serviceName = nameController.text.trim();
                final servicePrice = priceController.text.trim();
                if (serviceName.isEmpty) {
                  return;
                }
                Navigator.of(context).pop((serviceName, servicePrice));
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_businessId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No business selected to update')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<BusinessProvider>();
    final businessId = _businessId!;

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'category': _categoryController.text.trim(),
      'subcategory': _categoryController.text.trim(),
      'description': _descriptionController.text.trim(),
      'phoneNumber': _phoneController.text.trim(),
      'whatsappNumber': _whatsappController.text.trim(),
      'email': _emailController.text.trim(),
      'address': _addressController.text.trim(),
      'area': _areaController.text.trim(),
      'latitude': double.tryParse(_latitudeController.text.trim()) ?? 0,
      'longitude': double.tryParse(_longitudeController.text.trim()) ?? 0,
      'services': _services.map((service) {
        return <String, dynamic>{
          'id': (service['id'] ?? '').isEmpty
              ? '${DateTime.now().millisecondsSinceEpoch}'
              : service['id'],
          'name': (service['name'] ?? '').trim(),
          'price': (service['price'] ?? '').trim(),
        };
      }).toList(),
    };

    try {
      await provider.updateBusiness(businessId, payload);
      await provider.replaceBusinessPhotos(
        businessId,
        retainedPhotoUrls: _existingPhotoUrls,
        newPhotos: _newPhotos,
      );
      await provider.updateOpeningHours(
        businessId,
        <String, dynamic>{
          for (final entry in _hours.entries) entry.key: entry.value.toMap(),
        },
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business updated successfully')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update business')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
  void _showErrorSafe(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      debugPrint('EditBusinessScreen snack error: $message');
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _validatePhotoFile(File file) async {
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
  }
}

class _PhotoItem {
  const _PhotoItem({this.url, this.file});

  final String? url;
  final File? file;
}
