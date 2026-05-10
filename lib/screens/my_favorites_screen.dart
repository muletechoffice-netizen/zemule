import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zemule/providers/user_provider.dart';
import 'package:zemule/services/auth_service.dart';
import 'package:zemule/widgets/business_card.dart';

class MyFavoritesScreen extends StatefulWidget {
  const MyFavoritesScreen({super.key});

  @override
  State<MyFavoritesScreen> createState() => _MyFavoritesScreenState();
}

class _MyFavoritesScreenState extends State<MyFavoritesScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = _authService.currentUser;
      if (user == null || !mounted) {
        return;
      }
      context.read<UserProvider>().loadMyFavorites(user.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('My Favorites')),
      body: RefreshIndicator(
        onRefresh: () async {
          final user = _authService.currentUser;
          if (user == null) {
            return;
          }
          await context.read<UserProvider>().loadMyFavorites(user.uid);
        },
        child: provider.myFavorites.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('No favorites yet')),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: provider.myFavorites.length,
                itemBuilder: (_, index) {
                  final business = provider.myFavorites[index];
                  return Column(
                    children: [
                      BusinessCard(
                        business: business,
                        distanceKm: null,
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/business-detail',
                          arguments: business.id,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => provider.removeFavorite(business.id),
                          icon: const Icon(Icons.favorite, color: Colors.red),
                          label: const Text('Remove from favorites'),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
