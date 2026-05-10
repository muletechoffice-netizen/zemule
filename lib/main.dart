import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zemule/providers/business_detail_provider.dart';
import 'package:zemule/providers/business_registration_provider.dart';
import 'package:zemule/providers/business_provider.dart';
import 'package:zemule/providers/feature_flag_provider.dart';
import 'package:zemule/providers/review_provider.dart';
import 'package:zemule/providers/search_provider.dart';
import 'package:zemule/providers/theme_provider.dart';
import 'package:zemule/providers/user_provider.dart';
import 'package:zemule/screens/business_dashboard_screen.dart';
import 'package:zemule/screens/business_detail_screen.dart';
import 'package:zemule/screens/business_registration_screen.dart';
import 'package:zemule/screens/edit_business_screen.dart';
import 'package:zemule/screens/edit_profile_screen.dart';
import 'package:zemule/screens/home_screen.dart';
import 'package:zemule/screens/login_screen.dart';
import 'package:zemule/screens/my_favorites_screen.dart';
import 'package:zemule/screens/my_reviews_screen.dart';
import 'package:zemule/screens/premium_plans_screen.dart';
import 'package:zemule/screens/profile_screen.dart';
import 'package:zemule/screens/privacy_policy_screen.dart';
import 'package:zemule/screens/reset_pin_screen.dart';
import 'package:zemule/screens/search_screen.dart';
import 'package:zemule/screens/settings_screen.dart';
import 'package:zemule/screens/splash_screen.dart';
import 'package:zemule/screens/subcategory_screen.dart';
import 'package:zemule/screens/terms_screen.dart';
import 'package:zemule/screens/write_review_screen.dart';
import 'package:zemule/services/location_service.dart';
import 'package:zemule/services/password_recovery_service.dart';
import 'package:zemule/services/search_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zemule/utils/colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zshiwjywiajevjtfrtsi.supabase.co',
    anonKey: 'sb_publishable_yS9BLEEyXPblsFRCepf42Q_jrZwY5lo',
  );
  await PasswordRecoveryService.instance.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => FeatureFlagProvider()),
        Provider(create: (_) => LocationService()),
        ChangeNotifierProvider(
          create: (context) => BusinessProvider(
            locationService: context.read<LocationService>(),
          ),
        ),
      ],
      child: const ZemuleApp(),
    ),
  );
}

class ZemuleApp extends StatefulWidget {
  const ZemuleApp({super.key});

  @override
  State<ZemuleApp> createState() => _ZemuleAppState();
}

class _ZemuleAppState extends State<ZemuleApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    PasswordRecoveryService.instance.addListener(_handleRecoveryPendingChanged);
  }

  @override
  void dispose() {
    PasswordRecoveryService.instance.removeListener(_handleRecoveryPendingChanged);
    super.dispose();
  }

  void _handleRecoveryPendingChanged() {
    if (!PasswordRecoveryService.instance.isRecoveryPending) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = _navigatorKey.currentState;
      if (navigator == null) {
        return;
      }
      navigator.pushNamedAndRemoveUntil('/reset-pin', (_) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Zemule',
      initialRoute: PasswordRecoveryService.instance.isRecoveryPending
          ? '/reset-pin'
          : '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/reset-pin': (_) => const ResetPinScreen(),
        '/home': (_) => const HomeScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/edit-profile': (_) => const EditProfileScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/my-reviews': (_) => const MyReviewsScreen(),
        '/my-favorites': (_) => const MyFavoritesScreen(),
        '/business-dashboard': (_) => const BusinessDashboardScreen(),
        '/business-registration': (_) => ChangeNotifierProvider(
          create: (_) => BusinessRegistrationProvider(),
          child: const BusinessRegistrationScreen(),
        ),
        '/edit-business': (_) => const EditBusinessScreen(),
        '/premium-plans': (_) => const PremiumPlansScreen(),
        '/terms': (_) => const TermsScreen(),
        '/privacy': (_) => const PrivacyPolicyScreen(),
        '/search': (context) => ChangeNotifierProvider(
          create: (_) => SearchProvider(
            searchService: SearchService(
              locationService: context.read<LocationService>(),
            ),
          ),
          child: const SearchScreen(),
        ),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/business-detail') {
          final args = settings.arguments;
          if (args is String && args.isNotEmpty) {
            return MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider(
                create: (_) => BusinessDetailProvider(businessId: args),
                child: BusinessDetailScreen(businessId: args),
              ),
            );
          }
          return MaterialPageRoute(builder: (_) => const HomeScreen());
        }
        if (settings.name == '/subcategories') {
          final args = settings.arguments;
          if (args is SubcategoryScreenArgs) {
            return MaterialPageRoute(
              builder: (_) => SubcategoryScreen(
                mainCategory: args.mainCategory,
                subcategories: args.subcategories,
              ),
            );
          }
          return MaterialPageRoute(builder: (_) => const HomeScreen());
        }
        if (settings.name == '/write-review') {
          final args = settings.arguments;
          if (args is String && args.isNotEmpty) {
            return MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider(
                create: (_) => ReviewProvider(),
                child: WriteReviewScreen(businessId: args),
              ),
            );
          }
          return MaterialPageRoute(builder: (_) => const HomeScreen());
        }
        return null;
      },
      themeMode: themeProvider.themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = isDark
        ? const ColorScheme.dark(
            primary: AppColors.primaryDark,
            secondary: AppColors.secondaryDark,
            tertiary: AppColors.accentDark,
            surface: AppColors.surfaceDark,
            onSurface: AppColors.textDark,
            onPrimary: Color(0xFF081120),
            onSecondary: Color(0xFF081120),
          ).copyWith(
            surfaceContainerHighest: AppColors.surfaceAltDark,
            outlineVariant: AppColors.borderDark,
          )
        : const ColorScheme.light(
            primary: AppColors.primaryLight,
            secondary: AppColors.secondaryLight,
            surface: AppColors.surfaceLight,
            onSurface: AppColors.textLight,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
          ).copyWith(
            surfaceContainerHighest: AppColors.surfaceAltLight,
            outlineVariant: AppColors.borderLight,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: isDark ? Colors.white : Colors.white,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.surfaceAltDark : AppColors.textLight,
        contentTextStyle: TextStyle(
          color: isDark ? AppColors.textDark : Colors.white,
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: scheme.onSurface),
        bodyMedium: TextStyle(color: scheme.onSurface),
        bodySmall: TextStyle(
          color: isDark ? AppColors.mutedTextDark : AppColors.mutedTextLight,
        ),
      ),
    );
  }
}
