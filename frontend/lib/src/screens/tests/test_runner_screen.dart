import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppSpacing.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppTypography.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppColors.dart';
import 'package:dhiraj_ayu_academy/src/services/test_service.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';
import 'package:dhiraj_ayu_academy/src/services/media_token_cache.dart';

class TestRunnerScreen extends StatefulWidget {
  final Map<String, dynamic> test;
  final String attemptId;
  const TestRunnerScreen({
    Key? key,
    required this.test,
    required this.attemptId,
  }) : super(key: key);

  @override
  State<TestRunnerScreen> createState() => _TestRunnerScreenState();
}

class _TestRunnerScreenState extends State<TestRunnerScreen> {
  late final List<Map<String, dynamic>> _questions;
  int _index = 0;
  Map<String, String> _answers = {}; // questionId -> selected option (A/B/C/D)
  Timer? _timer;
  int _remainingSeconds = 0;
  // Notifier for remaining seconds so only timer widget rebuilds
  final ValueNotifier<int> _remainingNotifier = ValueNotifier<int>(0);
  bool _submitting = false;

  // Cache image fetch futures per question so rebuilds (timer ticks) don't re-run network calls
  final Map<String, Future<Uint8List?>> _imageFutures = {};
  @override
  void initState() {
    super.initState();
    final qlist = (widget.test['questions'] is List)
        ? (widget.test['questions'] as List)
        : [];
    _questions = qlist.cast<Map<String, dynamic>>();
    _remainingSeconds = (widget.test['duration'] ?? 0) * 60;
    _remainingNotifier.value = _remainingSeconds;
    startCountdown();
  }

  void startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        _remainingSeconds -= 1;
        _remainingNotifier.value = _remainingSeconds;
      } else {
        t.cancel();
        _autoSubmit();
      }
    });
  }

  String formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _selectOption(String questionId, String option) {
    setState(() {
      _answers[questionId] = option;
    });
  }

  Future<void> _confirmAndSubmit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Submit Test'),
        content: const Text('Are you sure you want to submit the test?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _submit();
  }

  Future<bool> _handleWillPop() async {
    // Prevent navigation while submission in progress
    if (_submitting) return false;

    final submit = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Leave Test?'),
        content: const Text('Do you want to submit the test before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Submit & Exit'),
          ),
        ],
      ),
    );

    if (submit == true) {
      await _submit();
      // _submit will pop on success; block the default pop
      return false;
    }
    return false;
  }

  Future<void> _autoSubmit() async {
    if (_submitting) return;
    await _submit();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final payload = {'answers': _answers};
      await TestService().submitAttempt(widget.attemptId, payload);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Test submitted')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to submit test')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _imageFutures.clear();
    _remainingNotifier.dispose();
    super.dispose();
  }

  // Return a cached future for a question's image bytes. If not cached, start a fetch.
  Future<Uint8List?> _loadQuestionImage(Map<String, dynamic> q) {
    final id = q['id'].toString();
    if (_imageFutures.containsKey(id)) return _imageFutures[id]!;
    final fut = _fetchQuestionImage(q);
    _imageFutures[id] = fut;
    return fut;
  }

  Future<Uint8List?> _fetchQuestionImage(Map<String, dynamic> q) async {
    try {
      final assetId = q['image_id']?.toString();
      if (assetId == null) return null;
      final usageId = 'runner_question_${q['id']}';
      final ok = await mediaTokenCache.ensureTokenForUsage(
        usageId,
        assetId: assetId,
      );
      if (!ok) return null;
      final details = mediaTokenCache.getDetails(usageId);
      final url = details?['media_url'] as String?;
      final token = details?['worker_token'] as String?;
      if (url == null) return null;
      final dio = Dio();
      final resp = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        ),
      );
      return Uint8List.fromList(resp.data!);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // If there are no questions, show a friendly message and let user exit
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(widget.test['title'] ?? 'Test'),
          backgroundColor: AppColors.primaryGreen,
        ),
        body: Center(child: Text('No questions are available for this test.')),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Exit'),
            ),
          ),
        ),
      );
    }

    final q = _questions[_index];
    final qId = q['id'].toString();
    final selected = _answers[qId];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(widget.test['title'] ?? 'Test'),
          backgroundColor: AppColors.primaryGreen,
          actions: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Center(
                child: ValueListenableBuilder<int>(
                  valueListenable: _remainingNotifier,
                  builder: (context, remaining, _) => Chip(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: AppColors.primaryGreen.withOpacity(0.12),
                      ),
                    ),
                    avatar: Icon(
                      Icons.timer,
                      size: 18,
                      color: AppColors.primaryGreen,
                    ),
                    label: Text(
                      formatTime(remaining),
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 96),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${_index + 1} of ${_questions.length}',
                        style: AppTypography.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(q['question_text'] ?? q['question'] ?? ''),
                              const SizedBox(height: AppSpacing.sm),

                              // Show question image if present
                              if (q['image_id'] != null) ...[
                                FutureBuilder<Uint8List?>(
                                  future: _loadQuestionImage(q),
                                  builder: (context, snap) {
                                    final qId = q['id'].toString();
                                    if (snap.connectionState !=
                                        ConnectionState.done) {
                                      return const SizedBox(
                                        height: 160,
                                        child: Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    if (snap.hasError || snap.data == null) {
                                      return Container(
                                        width: double.infinity,
                                        height: 160,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Text('Preview not available'),
                                            const SizedBox(height: 8),
                                            TextButton.icon(
                                              onPressed: () {
                                                // Clear cached future so retry actually refetches
                                                setState(() {
                                                  _imageFutures.remove(qId);
                                                });
                                              },
                                              icon: const Icon(Icons.refresh),
                                              label: const Text('Retry'),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        snap.data!,
                                        width: double.infinity,
                                        height: 160,
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                const Divider(),
                                const SizedBox(height: AppSpacing.sm),
                              ],
                              const Divider(),
                              const SizedBox(height: AppSpacing.sm),
                              RadioGroup<String>(
                                groupValue: selected,
                                onChanged: (v) {
                                  if (v != null) _selectOption(qId, v);
                                },
                                child: Column(
                                  children: ['A', 'B', 'C', 'D'].map((opt) {
                                    final key = 'option_${opt.toLowerCase()}';
                                    final text = q[key] ?? '';
                                    return RadioListTile<String>(
                                      value: opt,
                                      title: Text('$opt. $text'),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.all(AppSpacing.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _index == 0
                      ? null
                      : () => setState(() => _index -= 1),
                  child: const Text('Previous'),
                ),
                if (_index < _questions.length - 1)
                  ElevatedButton(
                    onPressed: () => setState(() => _index += 1),
                    child: const Text('Next'),
                  )
                else
                  ElevatedButton(
                    onPressed: _submitting ? null : _confirmAndSubmit,
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('End Test'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
