import 'package:flutter/material.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppColors.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppSpacing.dart';
import 'package:dhiraj_ayu_academy/src/services/api_service.dart';
import 'package:dhiraj_ayu_academy/src/widgets/cards.dart';
import 'package:dhiraj_ayu_academy/src/screens/courses/module_content_screen.dart';
import 'package:dhiraj_ayu_academy/src/screens/tests/tests_list_screen.dart';

class CourseContentScreen extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic> courseDetails;
  const CourseContentScreen({
    super.key,
    required this.courseId,
    required this.courseDetails,
  });

  @override
  State<CourseContentScreen> createState() => _CourseContentScreenState();
}

class _CourseContentScreenState extends State<CourseContentScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _modules = [];

  @override
  void initState() {
    super.initState();
    _loadModules();
  }

  Future<void> _loadModules() async {
    setState(() => _isLoading = true);
    try {
      final resp = await ApiService().get('modules/course/${widget.courseId}');
      final List<dynamic> modules = resp.data['modules'] ?? [];
      setState(() {
        _modules = modules.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.courseDetails['title'] ?? 'Course Content'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: AppSpacing.screenPaddingAll,
              itemCount: _modules.length + 1,
              itemBuilder: (context, index) {
                // Last tile is always the Tests tile
                if (index == _modules.length) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: CourseCard(
                      title: 'Tests',
                      description: 'Practice and evaluate',
                      thumbnailUrl: null,
                      assetImagePath: 'assets/icons/app_logo.jpeg',
                      isPaid: widget.courseDetails['is_paid'] ?? false,
                      showPrice: false,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TestsListScreen(
                              courseId: widget.courseId,
                              courseTitle: widget.courseDetails['title'] ?? '',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }

                final module = _modules[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: CourseCard(
                    title: module['title'] ?? '',
                    description: '${module['mediaCount'] ?? 0} items',
                    thumbnailUrl: null,
                    assetImagePath: 'assets/icons/app_logo.jpeg',
                    isPaid: widget.courseDetails['is_paid'] ?? false,
                    showPrice: false,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ModuleContentScreen(
                            moduleId: module['id'],
                            moduleTitle: module['title'],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
