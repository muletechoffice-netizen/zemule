import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:zemule/services/supabase_service.dart';
import 'package:zemule/utils/opening_hours.dart';

class BusinessRegistrationProvider extends ChangeNotifier {
  BusinessRegistrationProvider({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  static const int totalSteps = 7;
  static const int lastStepIndex = totalSteps - 1;
  static const int _maxUploadPhotoBytes = 10 * 1024 * 1024;
  static const Duration submissionTimeout = Duration(seconds: 30);

  final SupabaseService _supabase;

  Map<String, dynamic> registrationData = <String, dynamic>{};
  int currentStep = 0;
  bool isLoading = false;
  List<File> uploadedPhotos = <File>[];

  void updateStepData(int step, Map<String, dynamic> data) {
    registrationData = <String, dynamic>{...registrationData, ...data};
    notifyListeners();
  }

  void setUploadedPhotos(List<File> photos) {
    uploadedPhotos = photos;
    notifyListeners();
  }

  void jumpToStep(int step) {
    if (step < 0 || step > lastStepIndex) return;
    currentStep = step;
    notifyListeners();
  }

  void goToNextStep() {
    if (currentStep < lastStepIndex) {
      currentStep += 1;
      notifyListeners();
    }
  }

  void goToPreviousStep() {
    if (currentStep > 0) {
      currentStep -= 1;
      notifyListeners();
    }
  }

  Future<void> submitBusiness() async {
    // Guard against multiple rapid submissions
    if (isLoading) return;
    isLoading = true;
    notifyListeners();
    try {
      await _runWithTimeout(_performSubmission());
    } on TimeoutException {
      throw const FormatException(
        'Saving is taking too long (over 30 seconds). Please check your connection and try again.',
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _performSubmission() async {
    final uid = _supabase.currentUserId;
    if (uid == null) {
      throw const FormatException('You must be logged in before submitting your business.');
    }

    _validateRequiredSubmissionFields();
    for (int step = 0; step <= lastStepIndex; step++) {
      validateStep(step);
    }

    final latitude = (registrationData['latitude'] as num?)?.toDouble();
    final longitude = (registrationData['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      throw const FormatException('Drop the map pin to confirm your business location.');
    }

    final business = await _supabase.createBusiness(<String, dynamic>{
      'owner_id': uid,
      'name': (registrationData['name'] ?? '').toString().trim(),
      'main_category': (registrationData['mainCategory'] ?? '').toString().trim(),
      'subcategory': (registrationData['subcategory'] ?? '').toString().trim(),
      // Legacy column until removed
      'category': (registrationData['subcategory'] ?? '').toString().trim(),
      'description': (registrationData['description'] ?? '').toString().trim(),
      'phone': (registrationData['phoneNumber'] ?? '').toString().trim(),
      'whatsapp': (registrationData['whatsappNumber'] ?? '').toString().trim(),
      'email': (registrationData['email'] ?? '').toString().trim(),
      'website': (registrationData['website'] ?? '').toString().trim(),
      'address': (registrationData['address'] ?? '').toString().trim(),
      'area': (registrationData['area'] ?? '').toString().trim(),
      'city': (registrationData['city'] ?? '').toString().trim(),
      'latitude': latitude,
      'longitude': longitude,
      'services': registrationData['services'] ?? <dynamic>[],
      'opening_hours': registrationData['openingHours'] ??
          buildDefaultOpeningHoursPayload(),
      'rating': 0,
      'review_count': 0,
      'status': 'pending',
      'is_premium': false,
    });

    final businessId = business['id']?.toString() ?? '';
    if (businessId.isEmpty) {
      throw const FormatException('Something went wrong. Please try again');
    }
    final photoUrls = await uploadPhotos(businessId);
    if (photoUrls.isNotEmpty) {
      await _supabase.updateBusiness(businessId, <String, dynamic>{'photos': photoUrls});
    }
  }

  Future<List<String>> uploadPhotos(String businessId) async {
    if (uploadedPhotos.isEmpty) return <String>[];

    final urls = <String>[];
    for (int i = 0; i < uploadedPhotos.length; i++) {
      final file = uploadedPhotos[i];
      if (!await file.exists()) {
        throw const FormatException('Something went wrong. Please try again');
      }
      final bytes = await file.length();
      if (bytes <= 0 || bytes > _maxUploadPhotoBytes) {
        throw const FormatException('Upload failed. Please try again with a smaller image');
      }
      final path = '$businessId/photos/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final publicUrl = await _supabase.uploadFile(
        bucket: 'businesses',
        path: path,
        file: file,
      );
      urls.add(publicUrl);
    }
    return urls;
  }

  List<String> collectValidationIssues() {
    final issues = <String>[];
    String read(String key) => (registrationData[key] ?? '').toString().trim();

    if (read('mainCategory').isEmpty) {
      issues.add('Select a main category.');
    }
    if (read('subcategory').isEmpty) {
      issues.add('Select a subcategory.');
    }
    if (read('name').isEmpty) {
      issues.add('Add your business name.');
    }
    final description = read('description');
    if (description.isNotEmpty && description.split(RegExp(r'\s+')).length > 200) {
      issues.add('Business description must be 200 words or less.');
    }
    final phoneNumber = read('phoneNumber');
    if (phoneNumber.isNotEmpty && !RegExp(r'^[0-9+(). -]{6,}$').hasMatch(phoneNumber)) {
      issues.add('Phone number format looks invalid.');
    }
    final email = read('email');
    if (email.isNotEmpty && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      issues.add('Email address format is invalid.');
    }
    if (read('address').isEmpty) {
      issues.add('Add your business address.');
    }
    if (read('area').isEmpty) {
      issues.add('Confirm your business area.');
    }
    if (read('city').isEmpty) {
      issues.add('Confirm your business city.');
    }
    if (registrationData['latitude'] == null || registrationData['longitude'] == null) {
      issues.add('Pin your location on the map.');
    }
    if (uploadedPhotos.isEmpty) {
      issues.add('Upload at least one business photo.');
    }
    final services = registrationData['services'];
    if (services is! List || services.isEmpty) {
      issues.add('List at least one service you offer.');
    }
    final openingHours = registrationData['openingHours'];
    if (openingHours is! Map || openingHours.isEmpty) {
      issues.add('Add your working hours for all days.');
    } else {
      final missing = <String>[];
      openingHours.forEach((day, value) {
        final label = _openingLabel(value);
        if (label == null || label.isEmpty) {
          missing.add(day.toString());
        }
      });
      if (missing.isNotEmpty) {
        issues.add('Add working hours for: ${missing.join(', ')}.');
      }
    }
    if (registrationData['agreedToTerms'] != true) {
      issues.add('Accept the terms to continue.');
    }

    return issues;
  }

  void _validateRequiredSubmissionFields() {
    final requiredStringFields = <String, String>{
      'mainCategory': 'Choose a main category to continue.',
      'subcategory': 'Choose a subcategory to continue.',
      'name': 'Enter your business name to continue.',
      'address': 'Enter your business address to continue.',
      'area': 'Confirm your business area before submitting.',
      'city': 'Confirm your business city before submitting.',
    };
    for (final entry in requiredStringFields.entries) {
      final value = registrationData[entry.key];
      if (value == null || value.toString().trim().isEmpty) {
        throw FormatException(entry.value);
      }
    }

    final services = registrationData['services'];
    if (services is! List || services.isEmpty) {
      throw const FormatException('Add at least one service before submitting.');
    }

    final openingHours = registrationData['openingHours'];
    if (openingHours is Map && openingHours.isNotEmpty) {
      final normalized = normalizeOpeningHoursPayload(openingHours);
      registrationData = <String, dynamic>{
        ...registrationData,
        'openingHours': normalized,
      };
    } else {
      registrationData = <String, dynamic>{
        ...registrationData,
        'openingHours': buildDefaultOpeningHoursPayload(),
      };
    }

    if (registrationData['latitude'] == null || registrationData['longitude'] == null) {
      throw const FormatException('Drop the map pin to confirm your business location.');
    }
    if (registrationData['agreedToTerms'] != true) {
      throw const FormatException('Please accept the terms before submitting.');
    }
  }

  void validateStep(int step) {
    switch (step) {
      case 0:
        final main = registrationData['mainCategory']?.toString().trim() ?? '';
        final sub = registrationData['subcategory']?.toString().trim() ?? '';
        if (main.isEmpty) {
          throw const FormatException('Choose a main category to continue.');
        }
        if (sub.isEmpty) {
          throw const FormatException('Choose a subcategory to continue.');
        }
        break;
      case 1:
        final name = registrationData['name']?.toString().trim() ?? '';
        final description = registrationData['description']?.toString().trim() ?? '';
        if (name.isEmpty) throw const FormatException('Enter your business name to continue.');
        if (description.isNotEmpty && description.split(RegExp(r'\s+')).length > 200) {
          throw const FormatException('Business description must be 200 words or less.');
        }
        break;
      case 2:
        final phoneNumber = registrationData['phoneNumber']?.toString().trim() ?? '';
        final email = registrationData['email']?.toString().trim() ?? '';
        if (phoneNumber.isNotEmpty &&
            !RegExp(r'^[0-9+(). -]{6,}$').hasMatch(phoneNumber)) {
          throw const FormatException('Enter a valid phone number or leave it blank.');
        }
        if (email.isNotEmpty && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
          throw const FormatException('Enter a valid email address, or leave it empty.');
        }
        break;
      case 3:
        final address = registrationData['address']?.toString().trim() ?? '';
        final area = registrationData['area']?.toString().trim() ?? '';
        final city = registrationData['city']?.toString().trim() ?? '';
        if (address.isEmpty) throw const FormatException('Enter your business address to continue.');
        if (area.isEmpty) throw const FormatException('Confirm your business area to continue.');
        if (city.isEmpty) throw const FormatException('Confirm your business city to continue.');
        if (registrationData['latitude'] == null || registrationData['longitude'] == null) {
          throw const FormatException('Drop the map pin to confirm your business location.');
        }
        break;
      case 4:
        if (uploadedPhotos.isEmpty) {
          throw const FormatException('Upload at least 1 photo of your business.');
        }
        break;
      case 5:
        final services = (registrationData['services'] as List<dynamic>?) ?? <dynamic>[];
        if (services.isEmpty) {
          throw const FormatException('Add at least one service before continuing.');
        }
        break;
      case 6:
        final agreed = registrationData['agreedToTerms'] == true;
        if (!agreed) throw const FormatException('Please accept the terms before submitting.');
        final hours = registrationData['openingHours'];
        if (hours is! Map || hours.isEmpty) {
          throw const FormatException('Please add your working hours.');
        }
        break;
      default:
        return;
    }
  }

  Future<T> _runWithTimeout<T>(Future<T> future) {
    return future.timeout(submissionTimeout);
  }

  String? _openingLabel(dynamic value) {
    return openingHoursLabel(value);
  }
}
