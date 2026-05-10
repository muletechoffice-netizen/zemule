import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zemule/providers/theme_provider.dart';
import 'package:zemule/providers/user_provider.dart';
import 'package:zemule/services/auth_service.dart';
import 'package:zemule/services/supabase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final SupabaseService _supabase = SupabaseService.instance;
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _privateProfile = false;
  bool _showActivityStatus = true;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader(title: 'Appearance'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Use system default'),
                  value: themeProvider.useSystemDefault,
                  onChanged: (value) {
                    if (value) {
                      themeProvider.setUseSystemDefault(true);
                    } else {
                      themeProvider.setThemeMode(false);
                    }
                  },
                ),
                SwitchListTile(
                  title: const Text('Dark mode'),
                  value: themeProvider.isDarkMode,
                  onChanged: themeProvider.useSystemDefault
                      ? null
                      : (value) => themeProvider.setThemeMode(value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const _SectionHeader(title: 'Notifications'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Push notifications'),
                  value: _pushNotifications,
                  onChanged: (v) => setState(() => _pushNotifications = v),
                ),
                SwitchListTile(
                  title: const Text('Email notifications'),
                  value: _emailNotifications,
                  onChanged: (v) => setState(() => _emailNotifications = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const _SectionHeader(title: 'Privacy'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Make profile private'),
                  value: _privateProfile,
                  onChanged: (v) => setState(() => _privateProfile = v),
                ),
                SwitchListTile(
                  title: const Text('Show activity status'),
                  value: _showActivityStatus,
                  onChanged: (v) => setState(() => _showActivityStatus = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const _SectionHeader(title: 'Account'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Delete account',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () => _confirmDeleteAccount(context),
                ),
                ListTile(
                  leading: const Icon(Icons.logout_outlined),
                  title: const Text('Log out'),
                  onTap: () async {
                    await _authService.signOut();
                    if (!context.mounted) {
                      return;
                    }
                    context.read<UserProvider>().clearUserData();
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (_) => false,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const _SectionHeader(title: 'About'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('App version'),
                  subtitle: const Text('1.0.0+1'),
                ),
                ListTile(
                  title: const Text('Terms of Service'),
                  onTap: () => Navigator.pushNamed(context, '/terms'),
                ),
                ListTile(
                  title: const Text('Privacy Policy'),
                  onTap: () => Navigator.pushNamed(context, '/privacy'),
                ),
                const ListTile(title: Text('Contact support')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account'),
        content: const Text('This action is permanent. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final user = _supabase.currentAuthUser;
    if (user == null) {
      return;
    }

    try {
      await _supabase.client.from('users').delete().eq('id', user.id);
      await _supabase.client.from('favorites').delete().eq('user_id', user.id);
      await _supabase.client.from('reviews').delete().eq('user_id', user.id);
      await _authService.signOut();
      if (!context.mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delete failed. Re-login may be required.'),
        ),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
