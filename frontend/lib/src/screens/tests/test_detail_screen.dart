import 'package:flutter/material.dart';
import 'package:dhiraj_ayu_academy/src/services/test_service.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppSpacing.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppTypography.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppColors.dart';
import 'package:dhiraj_ayu_academy/src/screens/tests/test_runner_screen.dart';

class TestDetailScreen extends StatefulWidget {
  final Map<String, dynamic> test;
  const TestDetailScreen({Key? key, required this.test}) : super(key: key);

  @override
  State<TestDetailScreen> createState() => _TestDetailScreenState();
}

class _TestDetailScreenState extends State<TestDetailScreen> {
  late Map<String, dynamic> _details;
  bool _loading = false;
  bool _loadingAttempts = false;
  List<Map<String, dynamic>> _attempts = [];

  @override
  void initState() {
    super.initState();
    // Always use passed test (caller guarantees it's available)
    _details = widget.test;
    _fetchAttempts();
  }

  Future<void> _fetchAttempts() async {
    setState(() => _loadingAttempts = true);
    try {
      final a = await TestService().getTestAttempts(_details['id'].toString());
      setState(() => _attempts = a.cast<Map<String, dynamic>>());
    } catch (e) {
      setState(() => _attempts = []);
    } finally {
      setState(() => _loadingAttempts = false);
    }
  }

  Future<void> _startTest() async {
    try {
      setState(() => _loading = true);
      final res = await TestService().startTest(_details['id'].toString());
      final attemptId = res['attemptId'];
      final serverTest = res['test'] is Map
          ? (res['test'] as Map<String, dynamic>)
          : null;

      if (attemptId != null) {
        if (serverTest != null &&
            serverTest['questions'] is List &&
            (serverTest['questions'] as List).isNotEmpty) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TestRunnerScreen(
                test: serverTest,
                attemptId: attemptId.toString(),
              ),
            ),
          );
          // refresh attempts when user returns
          await _fetchAttempts();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to start test: questions not provided by server',
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to start test')));
      }
    } catch (e) {
      String msg = 'Failed to start test';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showAttemptDetails(String attemptId) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FutureBuilder<Map<String, dynamic>>(
          future: TestService().getAttemptDetails(attemptId),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            final data = snapshot.data!;
            final attempt = data['attempt'];
            final questions = (data['questions'] as List)
                .cast<Map<String, dynamic>>();
            return Padding(
              padding: EdgeInsets.only(
                top: 12,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Attempt', style: AppTypography.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Score: ${attempt['score'] ?? 0}'),
                    const SizedBox(height: AppSpacing.sm),
                    ...questions
                        .map(
                          (q) => Card(
                            child: ListTile(
                              title: Text(q['question'] ?? ''),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Text(
                                    'Selected: ${q['selected_option'] ?? '-'}',
                                  ),
                                  Text(
                                    'Correct: ${q['correct_option'] ?? '-'}',
                                  ),
                                  if (q['is_correct'] == true)
                                    Text(
                                      'Correct',
                                      style: TextStyle(
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (_details['title'] ?? 'Untitled Test').toString();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _details['description'] ?? '',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Test metadata (marks/duration shown as chips)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Marks:',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(width: 8),
                          Chip(label: Text('${_details['total_marks'] ?? 0}')),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'Duration:',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text('${_details['duration'] ?? 0} mins'),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Your Attempts', style: AppTypography.titleMedium),
                  const SizedBox(height: AppSpacing.sm),

                  if (_loadingAttempts)
                    const Center(child: CircularProgressIndicator())
                  else if (_attempts.isEmpty)
                    const Text('No attempts yet')
                  else
                    ..._attempts.map((a) {
                      final ts =
                          DateTime.tryParse(a['attempted_at'] ?? '') ??
                          DateTime.now();
                      final local = ts.toLocal();
                      final date =
                          '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
                      final timeOnly =
                          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
                      final dateTime = '$date $timeOnly';
                      return Card(
                        child: ListTile(
                          title: Text('Score: ${a['score']}'),
                          subtitle: Text(dateTime),
                          trailing: TextButton(
                            onPressed: () => _showAttemptDetails(a['id']),
                            child: const Text('View'),
                          ),
                        ),
                      );
                    }).toList(),

                  const SizedBox(height: 96),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _loading ? null : _startTest,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnPrimary,
                      ),
                    )
                  : const Text('Start Test'),
            ),
          ),
        ),
      ),
    );
  }
}
