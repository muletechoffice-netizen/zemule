import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zemule/services/auth_service.dart';
import 'package:zemule/services/password_recovery_service.dart';
import 'package:zemule/services/supabase_service.dart';

class ResetPinScreen extends StatefulWidget {
  const ResetPinScreen({super.key});

  @override
  State<ResetPinScreen> createState() => _ResetPinScreenState();
}

class _ResetPinScreenState extends State<ResetPinScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  StreamSubscription<AuthState>? _authSubscription;

  bool _isSubmitting = false;
  bool _hasRecoverySession = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _hasRecoverySession = SupabaseService.instance.currentAuthUser != null;
    _authSubscription = SupabaseService.instance.authStateChanges.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasRecoverySession = state.session?.user != null ||
            SupabaseService.instance.currentAuthUser != null;
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  bool _isValidPin(String pin) => RegExp(r'^\d{6}$').hasMatch(pin);

  String _formatErrorMessage(Object error) {
    final message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length).trim();
    }
    return message;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (!_hasRecoverySession) {
      setState(() {
        _errorMessage =
            'Waiting for your secure reset session. Reopen the email link if this takes too long.';
      });
      return;
    }
    if (!_isValidPin(newPin)) {
      setState(() {
        _errorMessage = 'PIN must be exactly 6 digits';
      });
      return;
    }
    if (newPin != confirmPin) {
      setState(() {
        _errorMessage = 'PINs don\'t match';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _authService.completePasswordRecovery(newPin);
      PasswordRecoveryService.instance.clearPending();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN reset successfully. Please log in with your new PIN.'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _formatErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _goBackToLogin() async {
    PasswordRecoveryService.instance.clearPending();
    try {
      await _authService.signOut();
    } catch (_) {
      // Best-effort cleanup.
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Reset PIN'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Choose a new 6-digit PIN',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Use the secure link from your email to reset the PIN you use to log in.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _hasRecoverySession
                      ? colorScheme.primary.withValues(alpha: 0.08)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _hasRecoverySession ? Icons.verified_user : Icons.mark_email_read,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _hasRecoverySession
                            ? 'Secure reset session ready. You can set your new PIN now.'
                            : 'Waiting for the secure reset session from your email link.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _newPinController,
                enabled: !_isSubmitting && _hasRecoverySession,
                keyboardType: TextInputType.number,
                obscureText: true,
                textInputAction: TextInputAction.next,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'New 6-digit PIN',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPinController,
                enabled: !_isSubmitting && _hasRecoverySession,
                keyboardType: TextInputType.number,
                obscureText: true,
                textInputAction: TextInputAction.done,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'Confirm 6-digit PIN',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                onSubmitted: (_) {
                  if (!_isSubmitting) {
                    _submit();
                  }
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update PIN'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isSubmitting ? null : _goBackToLogin,
                child: const Text('Back to login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
