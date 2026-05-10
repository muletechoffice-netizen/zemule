import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:zemule/providers/user_provider.dart';
import 'package:zemule/services/auth_service.dart';
import 'package:zemule/utils/colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final _loginEmailController = TextEditingController();
  final _loginPinController = TextEditingController();
  final _signupNameController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupPinController = TextEditingController();
  final _signupConfirmPinController = TextEditingController();

  late final TabController _tabController;

  bool _isLoginLoading = false;
  bool _isSignUpLoading = false;
  bool _agreeToTerms = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        return;
      }
      setState(() {
        _errorMessage = null;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPinController.dispose();
    _signupNameController.dispose();
    _signupEmailController.dispose();
    _signupPinController.dispose();
    _signupConfirmPinController.dispose();
    super.dispose();
  }

  bool get _isLoading => _isLoginLoading || _isSignUpLoading;

  bool _isValidPin(String pin) => RegExp(r'^\d{6}$').hasMatch(pin);
  bool _isValidEmail(String email) =>
      RegExp(r"^[\w.!#%&'*+/=?`{|}~-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")
          .hasMatch(email.trim());

  String _formatErrorMessage(Object error) {
    final message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length).trim();
    }
    return message;
  }

  Future<void> _navigateToHome() async {
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    });
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    final email = _loginEmailController.text.trim();
    final pin = _loginPinController.text.trim();

    if (!_isValidEmail(email) || !_isValidPin(pin)) {
      setState(() {
        _errorMessage = 'Enter a valid email and 6-digit PIN';
      });
      return;
    }

    setState(() {
      _isLoginLoading = true;
      _errorMessage = null;
    });

    final userProvider = context.read<UserProvider>();

    try {
      final userCredential = await _authService.signInWithEmailPin(email, pin);
      final authUser = userCredential.user ?? _authService.currentUser;
      if (authUser == null) {
        throw Exception('Unable to complete login. Please try again.');
      }

      await userProvider.updateLastLogin(
        uid: authUser.uid,
        name: authUser.displayName,
      );
      await userProvider.loadUserProfile(authUser.uid);
      await _navigateToHome();
    } catch (error) {
      final existingUser = _authService.currentUser;
      if (existingUser != null) {
        try {
          await userProvider.loadUserProfile(existingUser.uid);
        } catch (_) {
          // Ignore recovery load failures; session is already valid.
        }
        await _navigateToHome();
        return;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _formatErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoginLoading = false;
        });
      }
    }
  }

  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();
    final name = _signupNameController.text.trim();
    final email = _signupEmailController.text.trim();
    final pin = _signupPinController.text.trim();
    final confirmPin = _signupConfirmPinController.text.trim();

    if (name.isEmpty || !_isValidEmail(email)) {
      setState(() {
        _errorMessage = 'Enter your full name and a valid email';
      });
      return;
    }
    if (!_isValidPin(pin)) {
      setState(() {
        _errorMessage = 'PIN must be exactly 6 digits';
      });
      return;
    }
    if (pin != confirmPin) {
      setState(() {
        _errorMessage = 'PINs don\'t match';
      });
      return;
    }
    if (!_agreeToTerms) {
      setState(() {
        _errorMessage = 'Please agree to the Terms and Privacy Policy';
      });
      return;
    }

    setState(() {
      _isSignUpLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential =
          await _authService.signUpWithEmailPin(name: name, email: email, pin: pin);
      final authUser = userCredential.user;
      if (authUser == null) {
        throw Exception('Account creation failed. Try again.');
      }

      await _navigateToHome();
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
          _isSignUpLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showForgotPinDialog() async {
    final emailController = TextEditingController(
      text: _loginEmailController.text.trim(),
    );
    String? errorMessage;
    bool isSending = false;

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> sendOtp() async {
              final email = emailController.text.trim();
              if (!_isValidEmail(email)) {
                setDialogState(() {
                  errorMessage = 'Enter a valid email address';
                });
                return;
              }

              setDialogState(() {
                isSending = true;
                errorMessage = null;
              });

              try {
                await _authService.sendPasswordReset(email);
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop(email);
              } catch (error) {
                if (!dialogContext.mounted) {
                  return;
                }
                setDialogState(() {
                  errorMessage = _formatErrorMessage(error);
                });
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    isSending = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text('Forgot PIN?'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter your email address and we\'ll send you a secure reset link.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      enabled: !isSending,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        hintText: 'you@example.com',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) {
                        if (!isSending) {
                          sendOtp();
                        }
                      },
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSending ? null : sendOtp,
                  child: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send Reset Link'),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();

    if (!mounted || email == null || email.isEmpty) {
      return;
    }

    _loginEmailController.text = email;
    _showSnackBar(
      'Reset link sent. Open the email on this device to choose a new PIN.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: Navigator.canPop(context)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Welcome to Zemule',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: colorScheme.surface,
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(text: 'Login'),
                    Tab(text: 'Sign Up'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.red.withValues(alpha: 0.2)
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.red.shade200
                          : Colors.red.shade800,
                    ),
                  ),
                ),
              if (_errorMessage != null) const SizedBox(height: 10),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildLoginTab(), _buildSignUpTab()],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () {
                          Navigator.pushNamed(
                            context,
                            '/business-registration',
                          );
                        },
                  child: Text(
                    'Own a business? List it for free',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginTab() {
    return ListView(
      children: [
        TextField(
          controller: _loginEmailController,
          enabled: !_isLoading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email address',
            hintText: 'you@example.com',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _loginPinController,
          enabled: !_isLoading,
          keyboardType: TextInputType.number,
          obscureText: true,
          textInputAction: TextInputAction.done,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(
            labelText: '6-digit PIN',
            border: OutlineInputBorder(),
            counterText: '',
          ),
          onSubmitted: (_) {
            if (!_isLoading) {
              _login();
            }
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isLoading ? null : _showForgotPinDialog,
            child: const Text('Forgot PIN?'),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _login,
            child: _isLoginLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Login'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _isLoading ? null : () => _tabController.animateTo(1),
            child: const Text('Don\'t have an account? Sign Up'),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpTab() {
    return ListView(
      children: [
        TextField(
          controller: _signupNameController,
          enabled: !_isLoading,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _signupEmailController,
          enabled: !_isLoading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email address',
            hintText: 'you@example.com',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _signupPinController,
          enabled: !_isLoading,
          keyboardType: TextInputType.number,
          obscureText: true,
          textInputAction: TextInputAction.next,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(
            labelText: 'Create 6-digit PIN',
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _signupConfirmPinController,
          enabled: !_isLoading,
          keyboardType: TextInputType.number,
          obscureText: true,
          textInputAction: TextInputAction.next,
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
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _agreeToTerms,
              onChanged: _isLoading
                  ? null
                  : (value) {
                      setState(() {
                        _agreeToTerms = value ?? false;
                      });
                    },
            ),
            Expanded(child: _buildAgreementText()),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _signUp,
            child: _isSignUpLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign Up'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _isLoading ? null : () => _tabController.animateTo(0),
            child: const Text('Already have an account? Login'),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'By continuing, you agree to our Terms and Privacy Policy',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textDark
                : AppColors.textLight,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAgreementText() {
    final linkStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        children: [
          const Text('I agree to the'),
          GestureDetector(
            onTap: _isLoading ? null : () => Navigator.pushNamed(context, '/terms'),
            child: Text('Terms of Service', style: linkStyle),
          ),
          const Text('and'),
          GestureDetector(
            onTap: _isLoading ? null : () => Navigator.pushNamed(context, '/privacy'),
            child: Text('Privacy Policy', style: linkStyle),
          ),
        ],
      ),
    );
  }
}
