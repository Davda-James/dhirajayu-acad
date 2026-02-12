import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dhiraj_ayu_academy/src/services/test_service.dart';
import 'package:dhiraj_ayu_academy/src/models/test_attempt.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppSpacing.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppTypography.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppColors.dart';
import 'package:dhiraj_ayu_academy/src/screens/tests/test_runner_screen.dart';
import 'package:dhiraj_ayu_academy/src/screens/tests/test_attempts_view_screen.dart';
import 'package:dhiraj_ayu_academy/src/utils/common.dart';

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
  bool _loadingMoreAttempts = false;
  List<Map<String, dynamic>> _attempts = [];
  int _attemptsPage = 1;
  final int _attemptsPageSize = 20;
  int _attemptsTotal = 0;

  bool get _hasMoreAttempts => _attempts.length < _attemptsTotal;

  @override
  void initState() {
    super.initState();
    _details = widget.test;
    _fetchAttempts(page: 1);
  }

  Future<void> _fetchAttempts({int page = 1, bool append = false}) async {
    if (page == 1) setState(() => _loadingAttempts = true);
    if (append) setState(() => _loadingMoreAttempts = true);

    try {
      final resp = await TestService().getTestAttempts(
        _details['id'].toString(),
        page: page,
        pageSize: _attemptsPageSize,
      );

      final attempts = (resp['attempts'] as List).cast<Map<String, dynamic>>();
      final pagination = resp['pagination'] as Map<String, dynamic>?;

      setState(() {
        _attemptsTotal = pagination != null
            ? (pagination['total'] as int)
            : attempts.length;
        _attemptsPage = page;
        if (append) {
          _attempts.addAll(attempts);
        } else {
          _attempts = attempts;
        }
      });
    } catch (e) {
      if (!append) setState(() => _attempts = []);
    } finally {
      if (page == 1) setState(() => _loadingAttempts = false);
      if (append) setState(() => _loadingMoreAttempts = false);
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
          final completer = Completer<dynamic>();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TestRunnerScreen(
                  test: serverTest,
                  attemptId: attemptId.toString(),
                ),
              ),
            ).then((v) => completer.complete(v));
          });

          await completer.future;
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
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(),
        ),
      ),
    );

    try {
      final data = await TestService().getAttemptDetails(attemptId);
      final attemptMap = data['attempt'] as Map<String, dynamic>;
      final attempt = Attempt.fromJson(attemptMap);
      final questionsRaw = (data['questions'] as List)
          .cast<Map<String, dynamic>>();
      final questions = questionsRaw
          .map((m) => AttemptQuestion.fromJson(m))
          .toList();
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loader
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TestAttemptScreen(
            attempt: attempt,
            questions: questions,
            title: _details['title'] ?? 'Test',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load attempt details')),
        );
      }
    }
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'Negative marking: ',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(width: 8),
                          Chip(label: Text('${_details['negative_marks']}')),
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
                    Column(
                      children: [
                        ..._attempts.map((a) {
                          final formattedDate = formatAttemptDate(
                            a['attempted_at'],
                          );
                          final timeOnly = formatAttemptTime(a['attempted_at']);

                          return Card(
                            elevation: 0.6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),

                              title: Text(
                                'Score: ${(() {
                                  final s = a['score'];
                                  final val = (s is num) ? s.toDouble() : double.tryParse(s?.toString() ?? '0') ?? 0.0;
                                  return val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(2);
                                })()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    timeOnly,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: TextButton(
                                onPressed: () => _showAttemptDetails(a['id']),
                                child: const Text('View'),
                              ),
                            ),
                          );
                        }).toList(),

                        const SizedBox(height: 8),

                        if (_loadingMoreAttempts)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          )
                        else if (_hasMoreAttempts)
                          TextButton(
                            onPressed: () => _fetchAttempts(
                              page: _attemptsPage + 1,
                              append: true,
                            ),
                            child: const Text('Load more'),
                          ),

                        const SizedBox(height: 16),
                        Text(
                          'Showing ${_attempts.length} of $_attemptsTotal attempts',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),

                        const SizedBox(height: 56),
                      ],
                    ),
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
