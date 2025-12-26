import 'package:flutter/material.dart';
import '../../constants/AppColors.dart';
import 'home_tab.dart';
import 'courses.dart';
import 'users_controller.dart';
import 'profile.dart';

/// Admin Home Screen
/// Bottom navigation with admin tabs: Courses, Media, Users
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;

  final List<Widget?> _screens = [const AdminHomeTab(), null, null, null];

  Widget _createScreen(int index) {
    switch (index) {
      case 0:
        return const AdminHomeTab();
      case 1:
        return const AdminCoursesScreen();
      case 2:
        return const AdminUsersScreen();
      case 3:
        return const AdminProfileScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      if (_screens[index] == null) {
        _screens[index] = _createScreen(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ProfileHeader moved to AdminHomeTab only
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens
                    .map((w) => w ?? const SizedBox.shrink())
                    .toList(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.backgroundLight,
          selectedItemColor: AppColors.primaryGreen,
          unselectedItemColor: AppColors.textSecondary,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school_outlined),
              activeIcon: Icon(Icons.school),
              label: 'Courses',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Users',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
