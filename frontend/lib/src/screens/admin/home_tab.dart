import 'package:dhiraj_ayu_academy/src/widgets/common_widgets.dart';
import 'package:flutter/material.dart';

/// Simple admin home tab
class AdminHomeTab extends StatelessWidget {
  const AdminHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top bar: ProfileHeader (like user home)
        const Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
          child: ProfileHeader(),
        ),
        // Home tab content only, no course/media widgets or back button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Text(
            'Welcome to the Admin Dashboard!',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        // Add more admin home widgets here as needed
      ],
    );
  }
}
