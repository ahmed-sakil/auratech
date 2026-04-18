import 'package:flutter/material.dart';

import 'widgets/admin_bottom_nav_bar.dart';
import 'widgets/admin_home_section.dart';
import 'widgets/admin_pending_requests_section.dart';
import 'widgets/admin_profile_section.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Admin Home',
      'Pending Requests',
      'Admin Profile',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          AdminHomeSection(),
          AdminPendingRequestsSection(),
          AdminProfileSection(),
        ],
      ),
      bottomNavigationBar: AdminBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}