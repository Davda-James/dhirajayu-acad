import 'package:flutter/material.dart';
import '../../constants/AppColors.dart';
import '../../constants/AppSpacing.dart';
import '../../constants/AppTypography.dart';
import '../../services/api_service.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic> courseDetails; // Add courseDetails field

  const CourseDetailScreen({
    super.key,
    required this.courseId,
    required this.courseDetails, // Initialize courseDetails
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final ApiService _apiService = ApiService();
  bool _isEnrolled = false;

  @override
  void initState() {
    super.initState();
    _checkEnrollment(); // Only check enrollment
  }

  Future<void> _checkEnrollment() async {
    try {
      final enrollmentResponse = await _apiService.get(
        'courses/check_enrollment/${widget.courseId}',
      );
      setState(() {
        _isEnrolled = enrollmentResponse.data['enrolled'];
      });
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.courseDetails; // Use passed course details

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Course Details', style: AppTypography.titleLarge),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: Column(
        children: [
          // Scrollable content (image included)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail now scrolls with content
                  if (course['thumbnail_url'] != null)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        course['thumbnail_url'],
                        fit: BoxFit.cover,
                      ),
                    ),

                  const SizedBox(height: AppSpacing.md),

                  Text(course['title'], style: AppTypography.headlineMedium),
                  const SizedBox(height: AppSpacing.sm),

                  // Prominent price (extra large)
                  Text(
                    course['price'] != null
                        ? '₹ ${(course['price'] as num).toInt()}'
                        : 'FREE',
                    style: AppTypography.displaySmall.copyWith(
                      color: course['price'] != null
                          ? AppColors.primaryGreen
                          : AppColors.success,
                      fontWeight: AppTypography.extraBold,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  Text(course['description'], style: AppTypography.bodyMedium),
                ],
              ),
            ),
          ),

          // Buy Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            color: AppColors.backgroundWhite,
            child: ElevatedButton(
              onPressed: _isEnrolled ? null : () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: _isEnrolled
                    ? AppColors.textSecondary.withValues(alpha: 0.5)
                    : AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
              child: Text(
                _isEnrolled ? 'Already Enrolled' : 'Buy Now',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.backgroundWhite,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
