import 'package:flutter/material.dart';
import '../constants/AppColors.dart';
import '../constants/AppSpacing.dart';
import '../constants/AppTypography.dart';

/// Course Card Widget
/// Displays course information in a card format
class CourseCard extends StatelessWidget {
  final String title;
  final String description;
  final String? thumbnailUrl;
  final bool isPaid;
  final int? price;
  final VoidCallback? onTap;
  final bool isEnrolled;

  // workerToken removed — thumbnails are public now
  const CourseCard({
    super.key,
    required this.title,
    required this.description,
    this.thumbnailUrl,
    required this.isPaid,
    this.price,
    this.onTap,
    this.isEnrolled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppSpacing.elevationSM,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusMD,
        child: SizedBox(
          height: 96,
          child: Row(
            children: [
              // Left image
              Container(
                width: 112,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(AppSpacing.radiusMD),
                  ),
                ),
                child: thumbnailUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(AppSpacing.radiusMD),
                        ),
                        child: Image.network(
                          thumbnailUrl!,
                          fit: BoxFit.cover,
                          width: 112,
                          height: 96,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholder();
                          },
                        ),
                      )
                    : _buildPlaceholder(),
              ),

              // Right content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: AppTypography.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Price only (no discount shown)
                      if (isPaid && price != null)
                        Text(
                          '₹ ${price!.toString()}',
                          style: AppTypography.titleLarge.copyWith(
                            color: AppColors.primaryGreen,
                            fontWeight: AppTypography.extraBold,
                          ),
                        )
                      else
                        Text(
                          'FREE',
                          style: AppTypography.titleLarge.copyWith(
                            color: AppColors.success,
                            fontWeight: AppTypography.extraBold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceLight,
      child: const Center(
        child: Icon(
          Icons.school,
          size: AppSpacing.iconXL,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

/// Simple Card Widget
/// Generic card component for various content
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final double? elevation;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: elevation ?? AppSpacing.elevationSM,
      color: color,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusMD,
        child: Padding(
          padding: padding ?? AppSpacing.cardPaddingAll,
          child: child,
        ),
      ),
    );
  }
}

/// Info Card Widget
/// Card for displaying key information with icon
class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final VoidCallback? onTap;

  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.primaryGreen).withValues(
                alpha: 0.1,
              ),
              borderRadius: AppSpacing.borderRadiusMD,
            ),
            child: Icon(
              icon,
              color: iconColor ?? AppColors.primaryGreen,
              size: AppSpacing.iconLG,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
