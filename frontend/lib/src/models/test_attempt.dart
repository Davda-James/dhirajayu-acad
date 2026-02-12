class Attempt {
  final String id;
  final double score;
  final DateTime attemptedAt;

  Attempt({required this.id, required this.score, required this.attemptedAt});

  factory Attempt.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    if (id == null || id.isEmpty) throw FormatException('Attempt.id missing');

    final attemptedAtRaw = json['attempted_at'] ?? json['attemptedAt'];
    if (attemptedAtRaw == null)
      throw FormatException('Attempt.attempted_at missing');

    double parseScore(dynamic s) {
      if (s == null) return 0.0;
      if (s is double) return s;
      if (s is int) return s.toDouble();
      final parsed = double.tryParse(s.toString());
      return parsed ?? 0.0;
    }

    return Attempt(
      id: id,
      score: parseScore(json['score']),
      attemptedAt: DateTime.parse(attemptedAtRaw.toString()),
    );
  }
}

class AttemptQuestion {
  final String id;
  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final int marks;
  final String? imageId;
  final String? mediaUrl;
  final String correctOption;
  final String? selectedOption;
  final bool? isCorrect;

  AttemptQuestion({
    required this.id,
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.marks,
    required this.imageId,
    required this.mediaUrl,
    required this.correctOption,
    required this.selectedOption,
    required this.isCorrect,
  });

  factory AttemptQuestion.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    if (id == null || id.isEmpty) throw FormatException('Question.id missing');

    final qtext = json['question_text'] ?? json['question'];
    if (qtext == null) throw FormatException('Question.question_text missing');

    final optionA = json['option_a']?.toString() ?? '';
    final optionB = json['option_b']?.toString() ?? '';
    final optionC = json['option_c']?.toString() ?? '';
    final optionD = json['option_d']?.toString() ?? '';

    final marks = json['marks'] is int
        ? json['marks'] as int
        : (json['marks'] == null ? 0 : int.parse(json['marks'].toString()));

    final correct = json['correct_option']?.toString();
    if (correct == null)
      throw FormatException('Question.correct_option missing');

    final selected = json['selected_option']?.toString();

    final mediaUrl =
        json['media_url'] as String? ??
        (json['image'] is Map ? (json['image']['media_url'] as String?) : null);

    return AttemptQuestion(
      id: id,
      questionText: qtext.toString(),
      optionA: optionA,
      optionB: optionB,
      optionC: optionC,
      optionD: optionD,
      marks: marks,
      imageId: json['image_id']?.toString(),
      mediaUrl: mediaUrl,
      correctOption: correct,
      selectedOption: selected,
      isCorrect: json['is_correct'] == null
          ? null
          : (json['is_correct'] == true),
    );
  }
}
