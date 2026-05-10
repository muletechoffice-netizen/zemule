import 'package:flutter/material.dart';

import '../screens/admin_home_screen.dart';

class ZemuleAdminApp extends StatelessWidget {
  const ZemuleAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Zemule Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        scaffoldBackgroundColor: const Color(0xFFF6F8FA),
        useMaterial3: true,
      ),
      home: const AdminHomeScreen(),
    );
  }
}

