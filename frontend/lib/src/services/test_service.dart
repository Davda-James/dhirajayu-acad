import 'package:dhiraj_ayu_academy/src/services/api_service.dart';

class TestService {
  static final TestService _instance = TestService._internal();
  factory TestService() => _instance;
  TestService._internal();

  Future<List<dynamic>> fetchTestsForCourse(String courseId) async {
    final resp = await ApiService().get('tests/course/$courseId');
    return (resp.data['tests'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> createTest(Map<String, dynamic> payload) async {
    await ApiService().post('tests/create', data: payload);
  }

  Future<void> updateTest(String testId, Map<String, dynamic> payload) async {
    await ApiService().put('tests/update-test/$testId', data: payload);
  }

  Future<void> addQuestion(Map<String, dynamic> payload) async {
    await ApiService().post('tests/add-question', data: payload);
  }

  Future<Map<String, dynamic>> requestQuestionImageUpload(
    Map<String, dynamic> payload,
  ) async {
    print("reached here");
    final resp = await ApiService().post(
      'tests/ques-image-upload',
      data: payload,
    );
    return resp.data['upload'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> startTest(String testId) async {
    final resp = await ApiService().post('tests/start/$testId');
    return resp.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getTestAttempts(String testId) async {
    final resp = await ApiService().get('tests/$testId/attempts');
    return (resp.data['attempts'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getAttemptDetails(String attemptId) async {
    final resp = await ApiService().get('tests/attempt/$attemptId/questions');
    return resp.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getQuestionsForTest(String testId) async {
    final resp = await ApiService().get('tests/get-questions/$testId');
    return (resp.data['questions'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getTestDetails(String testId) async {
    final resp = await ApiService().get('tests/details/$testId');
    return resp.data as Map<String, dynamic>;
  }

  Future<void> updateQuestion(
    String questionId,
    Map<String, dynamic> payload,
  ) async {
    await ApiService().put('tests/question/$questionId', data: payload);
  }

  Future<void> deleteQuestion(String questionId) async {
    await ApiService().delete('tests/question/$questionId');
  }
}
