import 'package:flutter/material.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppTypography.dart';

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SizedBox(height: 8),
          Text('Users', style: AppTypography.headlineMedium),
          SizedBox(height: 12),
          Expanded(
            child: Center(child: Text('Admin Users — manage users here')),
          ),
        ],
      ),
    );
  }
}
