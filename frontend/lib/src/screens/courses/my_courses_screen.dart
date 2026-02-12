import 'package:flutter/material.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppColors.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppSpacing.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppTypography.dart';
import 'package:dhiraj_ayu_academy/src/widgets/common_widgets.dart';
import 'package:dhiraj_ayu_academy/src/services/api_service.dart';
import 'package:dhiraj_ayu_academy/src/screens/courses/course_content_screen.dart';

/// My Courses Screen
/// Display user's enrolled courses
class MyCoursesScreen extends StatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  State<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<MyCoursesScreen> {
  bool _isLoading = false;
  bool _isRefreshing = false;

  final List<Map<String, dynamic>> _enrolledCourses = [];

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadCourses({bool showGlobalLoading = true}) async {
    if (showGlobalLoading) {
      setState(() {
        _isLoading = true;
      });
    } else {
      setState(() {
        _isRefreshing = true;
      });
    }

    try {
      final resp = await ApiService().get('courses/my-courses');
      final List<dynamic> courses = resp.data['courses'] ?? [];

      final enrolled = courses.cast<Map<String, dynamic>>();

      if (mounted) {
        setState(() {
          _enrolledCourses.clear();
          _enrolledCourses.addAll(enrolled.cast<Map<String, dynamic>>());
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // App Bar
            SliverAppBar(
              floating: true,
              snap: true,
              pinned: true,
              backgroundColor: AppColors.backgroundWhite,
              elevation: 0,
              title: const Text('My Courses'),
            ),
          ];
        },
        body: (_isLoading && !_isRefreshing)
            ? const LoadingIndicator()
            : _buildInProgressTab(),
      ),
    );
  }

  Widget _buildInProgressTab() {
    if (_enrolledCourses.isEmpty) {
      return const EmptyState(
        icon: Icons.school_outlined,
        title: 'No courses yet',
        subtitle: 'Enroll in a course to start learning',
        actionText: 'Browse Courses',
      );
    }

    return PullToRefresh(
      onRefresh: () => _loadCourses(showGlobalLoading: false),
      child: ListView.builder(
        padding: AppSpacing.screenPaddingAll,
        itemCount: _enrolledCourses.length,
        itemBuilder: (context, index) {
          final course = _enrolledCourses[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _buildCourseProgressCard(course),
          );
        },
      ),
    );
  }

  Widget _buildCourseProgressCard(Map<String, dynamic> course) {
    return Card(
      elevation: AppSpacing.elevationSM,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CourseContentScreen(
                courseId: course['id'],
                courseDetails: course,
              ),
            ),
          );
        },
        borderRadius: AppSpacing.borderRadiusMD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.radiusMD),
                  ),
                ),
                child: course['thumbnail_url'] != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppSpacing.radiusMD),
                        ),
                        child: Image.network(
                          course['thumbnail_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholder();
                          },
                        ),
                      )
                    : _buildPlaceholder(),
              ),
            ),

            // Content
            Padding(
              padding: AppSpacing.cardPaddingAll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    course['title'] ?? '',
                    style: AppTypography.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigate to course content
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CourseContentScreen(
                              courseId: course['id'],
                              courseDetails: course,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                      ),
                      child: const Text('Continue Learning'),
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
