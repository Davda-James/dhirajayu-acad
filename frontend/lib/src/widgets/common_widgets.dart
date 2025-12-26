import 'package:flutter/material.dart';
import '../constants/AppColors.dart';
import '../constants/AppSpacing.dart';
import '../constants/AppTypography.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

/// Loading Indicator Widget
/// Circular progress indicator with app styling
class LoadingIndicator extends StatelessWidget {
  final double? size;
  final Color? color;

  const LoadingIndicator({super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size ?? 40,
        height: size ?? 40,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            color ?? AppColors.primaryGreen,
          ),
          strokeWidth: 3,
        ),
      ),
    );
  }
}

/// Empty State Widget
/// Shows empty state with icon and message
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: AppSpacing.paddingMD,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppColors.textTertiary),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (actionText != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(onPressed: onAction, child: Text(actionText!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Error State Widget
/// Shows error state with retry option
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool isLoading;
  final Color? buttonColor;

  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.buttonColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: AppSpacing.paddingMD,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Oops! Something went wrong',
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.md),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor ?? AppColors.primaryGreen,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Section Header Widget
/// Header for sections with optional action
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onActionPressed;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTypography.headlineSmall),
          if (actionText != null && onActionPressed != null)
            TextButton(onPressed: onActionPressed, child: Text(actionText!)),
        ],
      ),
    );
  }
}

/// Divider with Text Widget
/// Horizontal divider with centered text
class DividerWithText extends StatelessWidget {
  final String text;

  const DividerWithText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.divider)),
      ],
    );
  }
}

/// PullToRefresh
/// Reusable wrapper for pull-to-refresh behaviour across screens
class PullToRefresh extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color? color;

  const PullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color ?? AppColors.primaryGreen,
      child: child,
    );
  }
}

/// Badge Widget
/// Small badge for notifications or counts
class Badge extends StatelessWidget {
  final String text;
  final Color? backgroundColor;
  final Color? textColor;

  const Badge({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.error,
        borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
      ),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      child: Center(
        child: Text(
          text,
          style: AppTypography.labelSmall.copyWith(
            color: textColor ?? AppColors.textOnPrimary,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

/// Shimmer Loading Widget
/// Placeholder for loading content
class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: borderRadius ?? AppSpacing.borderRadiusSM,
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.borderLight),
        ),
      ),
    );
  }
}

/// Profile Header
/// Shows avatar, "Welcome back," and user's first name with optional notification action
class ProfileHeader extends StatefulWidget {
  final VoidCallback? onNotificationPressed;

  const ProfileHeader({super.key, this.onNotificationPressed});

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final User? currentUser = authService.currentUser;
    final profile = Provider.of<UserProvider>(context).profile;
    final bool isAdmin =
        (profile != null &&
        (profile['role'] ?? '').toString().toUpperCase() == 'ADMIN');

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
          backgroundImage: currentUser?.photoURL != null
              ? NetworkImage(currentUser!.photoURL!)
              : null,
          child: currentUser?.photoURL == null
              ? const Icon(
                  Icons.person,
                  color: AppColors.primaryGreen,
                  size: 24,
                )
              : null,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAdmin ? 'Welcome back Admin,' : 'Welcome back,',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                currentUser?.displayName?.split(' ').first ?? 'User',
                style: AppTypography.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: widget.onNotificationPressed ?? () {},
        ),
      ],
    );
  }
}

/// MenuListItem
/// Reusable menu tile used on profile screens
class MenuListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  const MenuListItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: AppSpacing.borderRadiusMD,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? AppColors.textSecondary),
        title: Text(
          title,
          style: AppTypography.bodyMedium.copyWith(
            color: titleColor ?? AppColors.textPrimary,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: AppColors.textTertiary),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMD),
      ),
    );
  }
}
