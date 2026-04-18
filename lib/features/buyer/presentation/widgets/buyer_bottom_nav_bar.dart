import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';

class BuyerBottomNavBar extends StatelessWidget {
  final String currentRoute;

  const BuyerBottomNavBar({
    super.key,
    required this.currentRoute,
  });

  int _selectedIndex() {
    switch (currentRoute) {
      case AppRoutes.buyerHome:
        return 0;
      case AppRoutes.buyerCart:
        return 1;
      case AppRoutes.buyerProfile:
        return 2;
      default:
        return 0;
    }
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.buyerHome);
        break;
      case 1:
        context.go(AppRoutes.buyerCart);
        break;
      case 2:
        context.go(AppRoutes.buyerProfile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: _selectedIndex(),
      onDestinationSelected: (index) => _onTap(context, index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.shopping_cart_outlined),
          selectedIcon: Icon(Icons.shopping_cart),
          label: 'Cart',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}