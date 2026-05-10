import 'package:flutter/material.dart';
import 'package:zemule/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();
  bool _hasNavigated = false;

  void _navigateTo(String routeName) {
    if (_hasNavigated || !mounted) {
      return;
    }

    _hasNavigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: StreamBuilder<AppUser?>(
          stream: _authService.userChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.active) {
              _navigateTo(snapshot.data != null ? '/home' : '/login');
            }

            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Zemule',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
