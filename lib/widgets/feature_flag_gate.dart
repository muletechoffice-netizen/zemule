import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zemule/providers/feature_flag_provider.dart';

class FeatureFlagGate extends StatelessWidget {
  const FeatureFlagGate({
    super.key,
    required this.flagName,
    required this.child,
    this.defaultValue = false,
    this.fallback,
  });

  final String flagName;
  final bool defaultValue;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final isEnabled = context.select<FeatureFlagProvider, bool>(
      (provider) => provider.isEnabled(flagName, fallback: defaultValue),
    );

    if (isEnabled) {
      return child;
    }

    return fallback ?? const SizedBox.shrink();
  }
}
