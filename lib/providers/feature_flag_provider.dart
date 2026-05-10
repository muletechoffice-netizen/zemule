import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zemule/models/feature_flag.dart';
import 'package:zemule/services/supabase_service.dart';

class FeatureFlagProvider extends ChangeNotifier {
  FeatureFlagProvider({SupabaseService? supabase})
    : _supabase = supabase ?? SupabaseService.instance {
    _authSubscription = _supabase.authStateChanges.listen((_) {
      refresh(showLoader: false);
    });
    refresh();
  }

  final SupabaseService _supabase;
  StreamSubscription<AuthState>? _authSubscription;

  Map<String, FeatureFlag> _flags = <String, FeatureFlag>{};
  bool _isLoading = true;
  bool _hasLoaded = false;
  bool _isAdmin = false;
  String? _error;

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get isAdmin => _isAdmin;
  String? get error => _error;

  List<FeatureFlag> get flags {
    final names = <String>{
      ..._flags.keys,
      ...kFeatureFlagDefinitions.map((definition) => definition.flagName),
    }.toList()..sort();

    return names
        .map((flagName) => _flags[flagName] ?? _buildDefaultFlag(flagName))
        .toList(growable: false);
  }

  bool isEnabled(String flagName, {bool fallback = false}) {
    final definition = definitionFor(flagName);
    return _flags[flagName]?.isEnabled ?? definition?.defaultValue ?? fallback;
  }

  FeatureFlagDefinition? definitionFor(String flagName) {
    for (final definition in kFeatureFlagDefinitions) {
      if (definition.flagName == flagName) {
        return definition;
      }
    }
    return null;
  }

  Future<void> refresh({bool showLoader = true}) async {
    if (showLoader) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final rows = await _supabase.listFeatureFlags();
      final nextFlags = <String, FeatureFlag>{};
      for (final row in rows) {
        final flag = FeatureFlag.fromMap(row);
        if (flag.flagName.isNotEmpty) {
          nextFlags[flag.flagName] = flag;
        }
      }
      _flags = _mergeKnownFlags(nextFlags);
      _isAdmin = await _supabase.isCurrentUserAdmin();
      _error = null;
    } catch (_) {
      _flags = _mergeKnownFlags(_flags);
      _isAdmin = false;
      _error = 'Failed to load feature flags.';
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  Future<void> setFlagEnabled(String flagName, bool isEnabled) async {
    if (!_isAdmin) {
      throw const FormatException('Only admins can update feature flags.');
    }

    _flags = <String, FeatureFlag>{
      ..._flags,
      flagName: (_flags[flagName] ?? _buildDefaultFlag(flagName)).copyWith(
        isEnabled: isEnabled,
        updatedAt: DateTime.now(),
      ),
    };
    notifyListeners();

    try {
      await _supabase.upsertFeatureFlag(
        flagName: flagName,
        isEnabled: isEnabled,
      );
      await refresh(showLoader: false);
    } catch (_) {
      await refresh(showLoader: false);
      rethrow;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Map<String, FeatureFlag> _mergeKnownFlags(Map<String, FeatureFlag> source) {
    final merged = <String, FeatureFlag>{...source};
    for (final definition in kFeatureFlagDefinitions) {
      merged.putIfAbsent(
        definition.flagName,
        () => FeatureFlag(
          flagName: definition.flagName,
          isEnabled: definition.defaultValue,
        ),
      );
    }
    return merged;
  }

  FeatureFlag _buildDefaultFlag(String flagName) {
    final definition = definitionFor(flagName);
    return FeatureFlag(
      flagName: flagName,
      isEnabled: definition?.defaultValue ?? false,
    );
  }
}
