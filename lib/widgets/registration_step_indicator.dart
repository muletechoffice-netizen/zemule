import 'package:flutter/material.dart';

class RegistrationStepIndicator extends StatelessWidget {
  const RegistrationStepIndicator({
    super.key,
    required this.currentStep,
    required this.onStepTap,
  });

  final int currentStep;
  final ValueChanged<int> onStepTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final completed = index < currentStep;
          final current = index == currentStep;
          final canTap = completed;
          final backgroundColor = completed || current
              ? colorScheme.primary.withOpacity(0.12)
              : colorScheme.surface;
          final foregroundColor = completed || current
              ? colorScheme.primary
              : colorScheme.onSurface;

          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: canTap ? () => onStepTap(index) : null,
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: current ? colorScheme.primary : colorScheme.outlineVariant),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    completed ? Icons.check_circle : Icons.circle_outlined,
                    size: 16,
                    color: foregroundColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Step ${index + 1}',
                    style: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
