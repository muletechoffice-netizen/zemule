import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/admin_navigation_state.dart';
import 'business_management_screen.dart';
import 'category_management_screen.dart';
import 'dashboard_screen.dart';
import 'user_management_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  static const List<String> _titles = <String>[
    'Dashboard',
    'Business Approval',
    'User Management',
    'Category Management',
  ];

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<AdminNavigationState>();
    final body = _buildPage(nav.index);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final isWide = constraints.maxWidth >= 980;

        if (isWide) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Zemule Admin - ${_titles[nav.index]}'),
            ),
            body: Row(
              children: <Widget>[
                NavigationRail(
                  selectedIndex: nav.index,
                  onDestinationSelected: nav.select,
                  labelType: NavigationRailLabelType.all,
                  destinations: const <NavigationRailDestination>[
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.approval_outlined),
                      selectedIcon: Icon(Icons.approval),
                      label: Text('Businesses'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.group_outlined),
                      selectedIcon: Icon(Icons.group),
                      label: Text('Users'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.category_outlined),
                      selectedIcon: Icon(Icons.category),
                      label: Text('Categories'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Zemule Admin - ${_titles[nav.index]}'),
          ),
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: nav.index,
            onDestinationSelected: nav.select,
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.approval_outlined),
                selectedIcon: Icon(Icons.approval),
                label: 'Businesses',
              ),
              NavigationDestination(
                icon: Icon(Icons.group_outlined),
                selectedIcon: Icon(Icons.group),
                label: 'Users',
              ),
              NavigationDestination(
                icon: Icon(Icons.category_outlined),
                selectedIcon: Icon(Icons.category),
                label: 'Categories',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const BusinessManagementScreen();
      case 2:
        return const UserManagementScreen();
      case 3:
        return const CategoryManagementScreen();
      default:
        return const DashboardScreen();
    }
  }
}

