import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zemule/services/supabase_service.dart';

class PremiumPlansScreen extends StatefulWidget {
  const PremiumPlansScreen({super.key});

  @override
  State<PremiumPlansScreen> createState() => _PremiumPlansScreenState();
}

class _PremiumPlansScreenState extends State<PremiumPlansScreen> {
  static const List<_PremiumPlan> _plans = <_PremiumPlan>[
    _PremiumPlan(
      id: 'monthly',
      title: 'Monthly Premium',
      priceLabel: 'K50/month',
      amount: 50,
      buttonText: 'Subscribe',
      benefits: <String>[
        'Appear at top of search',
        'Premium badge',
        'Unlimited photos',
        'Detailed analytics',
        'Promote special offers',
      ],
    ),
    _PremiumPlan(
      id: 'yearly',
      title: 'Yearly Premium',
      priceLabel: 'K500/year',
      amount: 500,
      subtitle: 'Save 2 months',
      buttonText: 'Subscribe',
      benefits: <String>[
        'Everything in monthly plan',
        'Lower annual cost',
        'Priority customer support',
      ],
    ),
    _PremiumPlan(
      id: 'promoted',
      title: 'Promoted Listing',
      priceLabel: 'K30/week',
      amount: 30,
      subtitle: 'Appear in promoted section',
      buttonText: 'Pay',
      benefits: <String>[
        'Highlighted listing',
        'Extra visibility',
        'Weekly boost cycle',
      ],
    ),
  ];

  final SupabaseService _supabase = SupabaseService.instance;
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  bool _isPremium = false;
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    _loadCurrentPlan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premium Plans')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
              children: [
                _buildCurrentPlanCard(),
                const SizedBox(height: 14),
                ..._plans.map(
                  (plan) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildPlanCard(plan),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Supported Payment Methods',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const _PaymentTile(
                  label: 'Airtel Money',
                  icon: Icons.phone_android_outlined,
                ),
                const _PaymentTile(
                  label: 'MTN Money',
                  icon: Icons.wallet_outlined,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose your plan first, then enter the phone number and payment method to request payment.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                ),
              ],
            ),
    );
  }

  Widget _buildCurrentPlanCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Plan',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _isPremium ? Colors.amber.shade700 : Colors.blueGrey,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _isPremium ? 'PREMIUM' : 'FREE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            if (_isPremium && _expiryDate != null) ...[
              const SizedBox(height: 8),
              Text('Expiry: ${_formatDate(_expiryDate!)}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(_PremiumPlan plan) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${plan.priceLabel}  |  Pay K${plan.amount}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (plan.subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                plan.subtitle!,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 8),
            ...plan.benefits.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2, right: 8),
                      child: Icon(Icons.check_circle_outline, size: 16),
                    ),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isProcessingPayment
                    ? null
                    : () => _subscribe(plan.id),
                child: _isProcessingPayment
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(plan.buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadCurrentPlan() async {
    final uid = _supabase.currentUserId;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    final businesses = await _supabase.listBusinesses(ownerId: uid, limit: 1);

    if (businesses.isNotEmpty) {
      final data = businesses.first;
      _isPremium = data['is_premium'] as bool? ?? false;
      _expiryDate = _toDate(data['premium_expiry']);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _subscribe(String planId) async {
    final _PremiumPlan? selectedPlan = _findPlan(planId);
    if (selectedPlan == null) {
      return;
    }

    if (_supabase.currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in before making a payment.')),
      );
      return;
    }

    final paymentInput = await showDialog<_PaymentInput>(
      context: context,
      builder: (_) => _PaymentCheckoutDialog(plan: selectedPlan),
    );

    if (paymentInput == null || !mounted) {
      return;
    }

    setState(() => _isProcessingPayment = true);

    try {
      final result = await _supabase.processPayment(
        phoneNumber: paymentInput.phoneNumber,
        amount: selectedPlan.amount,
        paymentMethod: paymentInput.paymentMethod,
      );

      if (!mounted) {
        return;
      }

      final message = _extractMessage(result);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.toString().trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isNotEmpty
                ? message
                : 'Payment request failed. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  String _extractMessage(Map<String, dynamic> result) {
    final rawMessage = result['message']?.toString().trim();
    if (rawMessage != null && rawMessage.isNotEmpty) {
      return rawMessage;
    }
    return 'Payment request sent. Complete the prompt on your phone.';
  }

  _PremiumPlan? _findPlan(String planId) {
    for (final plan in _plans) {
      if (plan.id == planId) {
        return plan;
      }
    }
    return null;
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime? _toDate(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw)?.toLocal();
    return null;
  }
}

class _PremiumPlan {
  const _PremiumPlan({
    required this.id,
    required this.title,
    required this.priceLabel,
    required this.amount,
    required this.buttonText,
    required this.benefits,
    this.subtitle,
  });

  final String id;
  final String title;
  final String priceLabel;
  final int amount;
  final String buttonText;
  final List<String> benefits;
  final String? subtitle;
}

class _PaymentInput {
  const _PaymentInput({
    required this.phoneNumber,
    required this.paymentMethod,
  });

  final String phoneNumber;
  final String paymentMethod;
}

class _PaymentCheckoutDialog extends StatefulWidget {
  const _PaymentCheckoutDialog({required this.plan});

  final _PremiumPlan plan;

  @override
  State<_PaymentCheckoutDialog> createState() => _PaymentCheckoutDialogState();
}

class _PaymentCheckoutDialogState extends State<_PaymentCheckoutDialog> {
  final TextEditingController _phoneController = TextEditingController();
  String _paymentMethod = 'airtel';
  String? _errorText;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.plan.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Amount: K${widget.plan.amount}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Use the mobile money number that should receive the payment prompt.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 14),
            const Text(
              'Payment method',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            RadioListTile<String>(
              value: 'airtel',
              groupValue: _paymentMethod,
              contentPadding: EdgeInsets.zero,
              title: const Text('Airtel Money'),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _paymentMethod = value);
              },
            ),
            RadioListTile<String>(
              value: 'mtn',
              groupValue: _paymentMethod,
              contentPadding: EdgeInsets.zero,
              title: const Text('MTN Money'),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _paymentMethod = value);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
              ],
              decoration: InputDecoration(
                labelText: 'Phone number',
                hintText: '097XXXXXXX or +26097XXXXXXX',
                errorText: _errorText,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text('Pay K${widget.plan.amount}'),
        ),
      ],
    );
  }

  void _submit() {
    final phoneNumber = _phoneController.text.trim();
    if (!_isValidPhoneNumber(phoneNumber)) {
      setState(() {
        _errorText = 'Enter a valid Airtel or MTN phone number.';
      });
      return;
    }

    Navigator.of(context).pop(
      _PaymentInput(
        phoneNumber: phoneNumber,
        paymentMethod: _paymentMethod,
      ),
    );
  }

  bool _isValidPhoneNumber(String value) {
    final normalized = value.replaceAll(' ', '');
    final digitsOnly = normalized.replaceAll('+', '');
    return digitsOnly.length >= 9 && digitsOnly.length <= 12;
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
      ),
    );
  }
}
