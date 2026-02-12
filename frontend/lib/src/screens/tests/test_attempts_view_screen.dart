import 'package:flutter/material.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppSpacing.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppTypography.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppColors.dart';
import 'package:dhiraj_ayu_academy/src/models/test_attempt.dart';

class TestAttemptScreen extends StatefulWidget {
  final Attempt attempt;
  final List<AttemptQuestion> questions;
  final String title;

  const TestAttemptScreen({
    Key? key,
    required this.attempt,
    required this.questions,
    required this.title,
  }) : super(key: key);

  @override
  State<TestAttemptScreen> createState() => _TestAttemptScreenState();
}

class _TestAttemptScreenState extends State<TestAttemptScreen> {
  int _index = 0;

  Widget _buildOption(AttemptQuestion q, String opt) {
    String text;
    switch (opt) {
      case 'A':
        text = q.optionA;
        break;
      case 'B':
        text = q.optionB;
        break;
      case 'C':
        text = q.optionC;
        break;
      default:
        text = q.optionD;
    }
    final selected = q.selectedOption;
    final correct = q.correctOption;
    final isCorrect = opt == correct;
    final isSelected = selected == opt;
    final isUnattempted = selected == null;

    Color? bg;
    Widget? trailing;

    if (isCorrect && isSelected) {
      bg = AppColors.primaryGreen.withValues(alpha: 0.06);
      trailing = const Icon(Icons.check_circle, color: AppColors.primaryGreen);
    } else if (isCorrect && isUnattempted) {
      bg = Colors.orange.withValues(alpha: 0.06);
      trailing = const Icon(Icons.info_outline, color: Colors.orange);
    }

    if (isSelected && !isCorrect) {
      bg = Colors.red.withValues(alpha: 0.06);
      trailing = const Icon(Icons.close, color: Colors.red);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCorrect
                ? (isUnattempted
                      ? Colors.orange.withValues(alpha: 0.12)
                      : AppColors.primaryGreen.withValues(alpha: 0.12))
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            opt,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isCorrect
                  ? (isUnattempted ? Colors.orange : AppColors.primaryGreen)
                  : Colors.black87,
            ),
          ),
        ),
        title: Text(text),
        trailing: trailing,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[_index];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('${widget.title} — Attempt'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question ${_index + 1} of ${widget.questions.length}',
              style: AppTypography.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.questionText),
                    const SizedBox(height: AppSpacing.sm),
                    if (q.mediaUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          q.mediaUrl!,
                          width: double.infinity,
                          height: 160,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const SizedBox(
                              height: 160,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                height: 160,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: const Text('Preview not available'),
                              ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],

                    const SizedBox(height: AppSpacing.sm),
                    ...[
                      'A',
                      'B',
                      'C',
                      'D',
                    ].map((opt) => _buildOption(q, opt)).toList(),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: IntrinsicWidth(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _index == 0
                        ? null
                        : () => setState(() => _index -= 1),
                    child: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _index < widget.questions.length - 1
                        ? () => setState(() => _index += 1)
                        : () => Navigator.pop(context),
                    child: Text(
                      _index < widget.questions.length - 1 ? 'Next' : 'Done',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
