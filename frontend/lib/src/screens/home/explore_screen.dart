import 'package:flutter/material.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppColors.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppSpacing.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppTypography.dart';
import 'package:dhiraj_ayu_academy/src/widgets/common_widgets.dart';

/// Explore Screen
/// Dashboard/Home tab showing featured content and quick access
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  // Categories data
  static const List<Map<String, dynamic>> _categories = [
    {
      'icon': Icons.menu_book,
      'title': 'Subject',
      'color': AppColors.primaryGreen,
    },
    {
      'icon': Icons.library_books,
      'title': 'Samhita',
      'color': AppColors.accentTeal,
    },
  ];

  @override
  Widget build(BuildContext context) {
    // authService and user are accessed inside `ProfileHeader` when needed

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.backgroundWhite,
            elevation: 0,
            title: const ProfileHeader(),
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),
                // Categories Section
                const SectionHeader(title: 'Categories'),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: AppSpacing.screenPaddingHorizontal,
                  child: _buildCategoriesGrid(),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double itemWidth =
            (constraints.maxWidth - (2 * AppSpacing.md)) / 3;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: _categories.map((category) {
            return SizedBox(
              width: itemWidth,
              child: _buildCategoryCard(
                icon: category['icon'] as IconData,
                title: category['title'] as String,
                color: category['color'] as Color,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCategoryCard({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: AppSpacing.borderRadiusMD,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: AppSpacing.iconLG),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTypography.labelMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
