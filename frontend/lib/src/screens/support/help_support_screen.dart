import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/AppColors.dart';
import '../../constants/AppSpacing.dart';
import '../../constants/AppTypography.dart';

/// Help & Support Screen
/// Contact support and get help
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  // Temporary email - replace with your actual support email
  static const String supportEmail = 'drdhimantt@gmail.com';

  Future<void> _launchEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: 'subject=Support Query - Dhiraj Ayu Academy',
    );

    try {
      await launchUrl(emailUri);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open email client. Please email us at $supportEmail',
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 32),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Help & Support'),
        backgroundColor: AppColors.backgroundWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPaddingAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: AppSpacing.paddingLG,
              decoration: BoxDecoration(
                color: AppColors.backgroundWhite,
                borderRadius: AppSpacing.borderRadiusLG,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowLight,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.support_agent,
                    size: 80,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'We\'re Here to Help',
                    style: AppTypography.displayMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Have questions or need assistance? Contact our support team.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Contact Section
            Text(
              'Contact Us',
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Email Card
            InkWell(
              onTap: () => _launchEmail(context),
              borderRadius: AppSpacing.borderRadiusMD,
              child: Container(
                padding: AppSpacing.paddingMD,
                decoration: BoxDecoration(
                  color: AppColors.backgroundWhite,
                  borderRadius: AppSpacing.borderRadiusMD,
                  border: Border.all(color: AppColors.borderLight, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowLight,
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.email_outlined,
                        color: AppColors.primaryGreen,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email Support',
                            style: AppTypography.titleLarge.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            supportEmail,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.primaryGreen,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.textSecondary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // FAQ Section
            Text(
              'Frequently Asked Questions',
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            _buildFAQItem(
              question: 'How do I enroll in a course?',
              answer:
                  'Browse available courses, select the one you\'re interested in, and click the "Enroll" button. You\'ll get instant access to all course materials.',
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildFAQItem(
              question: 'Can I access courses offline?',
              answer: 'No! You cannot access courses offline or download it.',
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildFAQItem(
              question: 'What if I have technical issues?',
              answer:
                  'Contact our support team via email, and we\'ll help you resolve any technical problems you encounter.',
            ),

            const SizedBox(height: AppSpacing.xl),

            // Response Time Info
            Container(
              padding: AppSpacing.paddingMD,
              decoration: BoxDecoration(
                color: AppColors.primaryGreenLight,
                borderRadius: AppSpacing.borderRadiusMD,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    color: AppColors.primaryGreen,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'We typically respond within 24-48 hours',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem({required String question, required String answer}) {
    return Container(
      padding: AppSpacing.paddingMD,
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.help_outline,
                color: AppColors.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  question,
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              answer,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
