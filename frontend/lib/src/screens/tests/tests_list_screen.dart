import 'package:flutter/material.dart';
import 'package:dhiraj_ayu_academy/src/services/test_service.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppSpacing.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppTypography.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppColors.dart';
import 'package:dhiraj_ayu_academy/src/screens/tests/test_detail_screen.dart';

class TestsListScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  const TestsListScreen({
    Key? key,
    required this.courseId,
    required this.courseTitle,
  }) : super(key: key);

  @override
  State<TestsListScreen> createState() => _TestsListScreenState();
}

class _TestsListScreenState extends State<TestsListScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _tests = [];

  @override
  void initState() {
    super.initState();
    _fetchTests();
  }

  Future<void> _fetchTests() async {
    setState(() => _loading = true);
    try {
      final resp = await TestService().fetchTestsForCourse(widget.courseId);
      setState(() => _tests = resp.cast<Map<String, dynamic>>());
    } catch (e) {
      setState(() => _tests = []);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load tests')));
    } finally {
      setState(() => _loading = false);
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
        title: Text(
          'Tests — ${widget.courseTitle}',
          style: AppTypography.titleMedium,
        ),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _tests.isEmpty
            ? const Center(child: Text('No tests available'))
            : ListView.builder(
                itemCount: _tests.length,
                itemBuilder: (context, index) {
                  final t = _tests[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      title: Text(t['title'] ?? ''),
                      subtitle: Text(
                        '${t['total_marks'] ?? 0} marks · ${t['duration'] ?? 0} mins',
                      ),
                      trailing: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TestDetailScreen(test: t),
                          ),
                        ),
                        child: const Text('View'),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
