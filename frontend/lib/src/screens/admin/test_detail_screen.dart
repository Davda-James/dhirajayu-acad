import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppColors.dart';
import 'package:dhiraj_ayu_academy/src/services/test_service.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppSpacing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';
import 'package:dhiraj_ayu_academy/src/services/media_token_cache.dart';
import 'dart:async';

class AdminTestDetailScreen extends StatefulWidget {
  final String testId;
  final String testTitle;
  final Map<String, dynamic>? test;
  const AdminTestDetailScreen({
    Key? key,
    required this.testId,
    required this.testTitle,
    this.test,
  }) : super(key: key);

  @override
  State<AdminTestDetailScreen> createState() => _AdminTestDetailScreenState();
}

class _AdminTestDetailScreenState extends State<AdminTestDetailScreen> {
  bool _isLoading = false;
  bool _isLoadingDetails = false;
  List<Map<String, dynamic>> _questions = [];
  Map<String, dynamic>? _testDetails;
  final Set<String> _expandedQuestionIds = {};
  @override
  void initState() {
    super.initState();
    if (widget.test != null) {
      _testDetails = widget.test;
    } else {
      _fetchTestDetails();
    }
    _fetchQuestions();
  }

  Future<void> _fetchTestDetails() async {
    setState(() => _isLoadingDetails = true);
    try {
      final details = await TestService().getTestDetails(widget.testId);
      setState(() => _testDetails = details);
    } catch (e) {
      setState(() => _testDetails = null);
    } finally {
      setState(() => _isLoadingDetails = false);
    }
  }

  Future<void> _fetchQuestions() async {
    setState(() => _isLoading = true);
    try {
      final qs = await TestService().getQuestionsForTest(widget.testId);
      setState(() => _questions = qs.cast<Map<String, dynamic>>());
    } catch (e) {
      setState(() => _questions = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildOptionRow(
    BuildContext context,
    String label,
    String? text,
    bool isCorrect,
  ) {
    final labelBox = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isCorrect
            ? AppColors.primaryGreen.withValues(alpha: 0.12)
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isCorrect ? AppColors.primaryGreen : Colors.black87,
        ),
      ),
    );

    final optionText = (text ?? '').toString().trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        labelBox,
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            optionText.isNotEmpty ? optionText : '-',
            style: TextStyle(
              fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
              color: isCorrect ? AppColors.primaryGreen : Colors.black87,
            ),
          ),
        ),
        if (isCorrect) ...[
          const SizedBox(width: 8),
          Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 18),
        ],
      ],
    );
  }

  Future<void> _showAddQuestionDialog() async {
    final qCtrl = TextEditingController();
    final marksCtrl = TextEditingController();
    final aCtrl = TextEditingController();
    final bCtrl = TextEditingController();
    final cCtrl = TextEditingController();
    final dCtrl = TextEditingController();
    String correct = 'A';
    bool isSubmitting = false;
    PlatformFile? _pickedImage;
    Uint8List? _previewBytes;
    String? _formError;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      TextField(
                        controller: qCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Question',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: marksCtrl,
                        decoration: const InputDecoration(labelText: 'Marks'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: aCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Option A',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: bCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Option B',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: cCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Option C',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: dCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Option D',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      DropdownButton<String>(
                        value: correct,
                        items: const [
                          DropdownMenuItem(value: 'A', child: Text('A')),
                          DropdownMenuItem(value: 'B', child: Text('B')),
                          DropdownMenuItem(value: 'C', child: Text('C')),
                          DropdownMenuItem(value: 'D', child: Text('D')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => correct = v);
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Image picker (optional)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              final res = await FilePicker.platform.pickFiles(
                                type: FileType.image,
                                allowMultiple: false,
                                withData: true,
                                withReadStream: true,
                              );
                              if (res == null || res.files.isEmpty) return;
                              setState(() {
                                _pickedImage = PlatformFile(
                                  name: res.files.first.name,
                                  path: res.files.first.path,
                                  size: res.files.first.size,
                                );
                              });
                            },
                            icon: const Icon(Icons.add_photo_alternate),
                            label: Text(
                              _pickedImage == null
                                  ? 'Add image (optional)'
                                  : 'Change image',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          if (_pickedImage != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final w =
                                      constraints.maxWidth.isFinite &&
                                          constraints.maxWidth > 0
                                      ? constraints.maxWidth
                                      : MediaQuery.of(context).size.width * 0.8;

                                  // Prefer in-memory preview when available, otherwise use file path, else show placeholder
                                  if (_previewBytes != null) {
                                    return Image.memory(
                                      _previewBytes!,
                                      width: w,
                                      height: 160,
                                      fit: BoxFit.cover,
                                    );
                                  }

                                  if (_pickedImage != null &&
                                      _pickedImage!.path != null &&
                                      _pickedImage!.path!.isNotEmpty) {
                                    return Image.file(
                                      File(_pickedImage!.path!),
                                      width: w,
                                      height: 160,
                                      fit: BoxFit.cover,
                                    );
                                  }

                                  return Container(
                                    width: w,
                                    height: 160,
                                    color: Colors.grey.shade200,
                                    alignment: Alignment.center,
                                    child: const Text('Preview not available'),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _pickedImage = null;
                                      _previewBytes = null;
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Remove image'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_formError != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _formError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    final question = qCtrl.text.trim();
                                    final marks =
                                        int.tryParse(marksCtrl.text.trim()) ??
                                        0;
                                    if (question.isEmpty) {
                                      setState(
                                        () => _formError =
                                            'Question text is required',
                                      );
                                      return;
                                    }
                                    setState(() => isSubmitting = true);
                                    try {
                                      String? mediaId;
                                      if (_pickedImage != null) {
                                        final mimeType =
                                            lookupMimeType(
                                              _pickedImage!.name,
                                            ) ??
                                            'application/octet-stream';

                                        // Ask server for a presigned upload URL
                                        final upload = await TestService()
                                            .requestQuestionImageUpload({
                                              'media': {
                                                'fileName': _pickedImage!.name,
                                                'fileSize': _pickedImage!.size,
                                                'mimeType': mimeType,
                                              },
                                            })
                                            .timeout(
                                              const Duration(seconds: 8),
                                            );
                                        final uploadUrl =
                                            upload['uploadUrl'] as String;
                                        mediaId = upload['mediaId'] as String;

                                        final dio = Dio();
                                        Response resp;

                                        if (_pickedImage!.path != null &&
                                            _pickedImage!.path!.isNotEmpty) {
                                          final file = File(
                                            _pickedImage!.path!,
                                          );
                                          final fileSize = await file.length();
                                          final dataStream = file.openRead();

                                          resp = await dio
                                              .put(
                                                uploadUrl,
                                                data: dataStream,
                                                options: Options(
                                                  headers: {
                                                    'Content-Type': mimeType,
                                                    'Content-Length': fileSize
                                                        .toString(),
                                                  },
                                                ),
                                              )
                                              .timeout(
                                                const Duration(seconds: 20),
                                              );
                                        } else if (_pickedImage!.bytes !=
                                            null) {
                                          // Fallback to in-memory bytes upload
                                          final bytes = _pickedImage!.bytes!;
                                          resp = await dio
                                              .put(
                                                uploadUrl,
                                                data: bytes,
                                                options: Options(
                                                  headers: {
                                                    'Content-Type': mimeType,
                                                    'Content-Length': bytes
                                                        .length
                                                        .toString(),
                                                  },
                                                ),
                                              )
                                              .timeout(
                                                const Duration(seconds: 20),
                                              );
                                        } else {
                                          throw Exception(
                                            'No file data available to upload',
                                          );
                                        }

                                        if (resp.statusCode == null ||
                                            resp.statusCode! < 200 ||
                                            resp.statusCode! >= 300)
                                          throw Exception('Upload failed');
                                      }
                                      final payload = {
                                        'test_id': widget.testId,
                                        'question_text': question,
                                        'marks': marks,
                                        'option_a': aCtrl.text.trim(),
                                        'option_b': bCtrl.text.trim(),
                                        'option_c': cCtrl.text.trim(),
                                        'option_d': dCtrl.text.trim(),
                                        'correct_option': correct,
                                        if (mediaId != null) 'mediaId': mediaId,
                                      };
                                      await TestService()
                                          .addQuestion(payload)
                                          .timeout(const Duration(seconds: 12));
                                      Navigator.of(context).pop(true);
                                    } catch (e) {
                                      setState(
                                        () => _formError =
                                            'Failed to add question',
                                      );
                                    } finally {
                                      setState(() => isSubmitting = false);
                                    }
                                  },
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.textOnPrimary,
                                    ),
                                  )
                                : const Text('Add'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    if (result == true) {
      await _fetchQuestions();
    }
  }

  Future<void> _showEditQuestionDialog(Map<String, dynamic> q) async {
    final qCtrl = TextEditingController(text: q['question_text'] ?? '');
    final marksCtrl = TextEditingController(
      text: (q['marks'] ?? '').toString(),
    );
    final aCtrl = TextEditingController(text: q['option_a'] ?? '');
    final bCtrl = TextEditingController(text: q['option_b'] ?? '');
    final cCtrl = TextEditingController(text: q['option_c'] ?? '');
    final dCtrl = TextEditingController(text: q['option_d'] ?? '');
    String correct = (q['correct_option'] ?? 'A') as String;
    bool isSubmitting = false;
    PlatformFile? _pickedImage;
    Uint8List? _previewBytes;
    bool _removeImage = false;
    String? _formError;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      TextField(
                        controller: qCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Question',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: marksCtrl,
                        decoration: const InputDecoration(labelText: 'Marks'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: aCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Option A',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: bCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Option B',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: cCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Option C',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: dCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Option D',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      DropdownButton<String>(
                        value: correct,
                        items: const [
                          DropdownMenuItem(value: 'A', child: Text('A')),
                          DropdownMenuItem(value: 'B', child: Text('B')),
                          DropdownMenuItem(value: 'C', child: Text('C')),
                          DropdownMenuItem(value: 'D', child: Text('D')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => correct = v);
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Image picker / remove controls
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (q['image_id'] != null && !_removeImage) ...[
                            const SizedBox(height: AppSpacing.sm),

                            // Image preview for existing question image
                            FutureBuilder<Uint8List?>(
                              future: () async {
                                try {
                                  final assetId = q['image_id'].toString();
                                  final usageId =
                                      'edit_question_image_${q['id']}';
                                  final ok = await mediaTokenCache
                                      .ensureTokenForUsage(
                                        usageId,
                                        assetId: assetId,
                                      );
                                  if (!ok) return null;
                                  final details = mediaTokenCache.getDetails(
                                    usageId,
                                  );
                                  final url = details?['media_url'] as String?;
                                  final token =
                                      details?['worker_token'] as String?;
                                  if (url == null) return null;
                                  final dio = Dio();
                                  final resp = await dio.get<List<int>>(
                                    url,
                                    options: Options(
                                      responseType: ResponseType.bytes,
                                      headers: {
                                        if (token != null)
                                          'Authorization': 'Bearer $token',
                                      },
                                    ),
                                  );
                                  return Uint8List.fromList(resp.data!);
                                } catch (e) {
                                  return null;
                                }
                              }(),
                              builder: (context, snap) {
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
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text('Preview not available'),
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

                            const SizedBox(height: AppSpacing.xs),

                            // Center the action buttons below the preview
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              children: [
                                TextButton.icon(
                                  onPressed: () =>
                                      setState(() => _removeImage = true),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Remove image'),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    final res = await FilePicker.platform
                                        .pickFiles(
                                          type: FileType.image,
                                          allowMultiple: false,
                                          withData: true,
                                          withReadStream: true,
                                        );
                                    if (res == null || res.files.isEmpty)
                                      return;
                                    setState(() {
                                      _pickedImage = PlatformFile(
                                        name: res.files.first.name,
                                        path: res.files.first.path,
                                        size: res.files.first.size,
                                      );
                                      _removeImage = false;
                                    });
                                  },
                                  icon: const Icon(Icons.add_photo_alternate),
                                  label: const Text('Replace image'),
                                ),
                              ],
                            ),
                          ] else ...[
                            ElevatedButton.icon(
                              onPressed: () async {
                                final res = await FilePicker.platform.pickFiles(
                                  type: FileType.image,
                                  allowMultiple: false,
                                  withData: true,
                                  withReadStream: true,
                                );
                                if (res == null || res.files.isEmpty) return;
                                setState(() {
                                  _pickedImage = PlatformFile(
                                    name: res.files.first.name,
                                    path: res.files.first.path,
                                    size: res.files.first.size,
                                  );
                                  _removeImage = false;
                                });
                              },
                              icon: const Icon(Icons.add_photo_alternate),
                              label: Text(
                                _pickedImage == null
                                    ? 'Add image (optional)'
                                    : 'Change image',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],

                          if (_pickedImage != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final w =
                                      constraints.maxWidth.isFinite &&
                                          constraints.maxWidth > 0
                                      ? constraints.maxWidth
                                      : MediaQuery.of(context).size.width * 0.8;

                                  if (_previewBytes != null) {
                                    return Image.memory(
                                      _previewBytes!,
                                      width: w,
                                      height: 160,
                                      fit: BoxFit.cover,
                                    );
                                  }

                                  if (_pickedImage != null &&
                                      _pickedImage!.path != null &&
                                      _pickedImage!.path!.isNotEmpty) {
                                    return Image.file(
                                      File(_pickedImage!.path!),
                                      width: w,
                                      height: 160,
                                      fit: BoxFit.cover,
                                    );
                                  }

                                  return Container(
                                    width: w,
                                    height: 160,
                                    color: Colors.grey.shade200,
                                    alignment: Alignment.center,
                                    child: const Text('Preview not available'),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _pickedImage = null;
                                      _previewBytes = null;
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Remove image'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: AppSpacing.md),
                      if (_formError != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _formError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    final question = qCtrl.text.trim();
                                    final marks =
                                        int.tryParse(marksCtrl.text.trim()) ??
                                        0;
                                    if (question.isEmpty) {
                                      setState(
                                        () => _formError =
                                            'Question text is required',
                                      );
                                      return;
                                    }
                                    setState(() => isSubmitting = true);
                                    try {
                                      String? mediaId;

                                      // If user picked image -> upload and get mediaId
                                      if (_pickedImage != null) {
                                        final mimeType =
                                            lookupMimeType(
                                              _pickedImage!.name,
                                            ) ??
                                            'application/octet-stream';
                                        final upload = await TestService()
                                            .requestQuestionImageUpload({
                                              'media': {
                                                'fileName': _pickedImage!.name,
                                                'fileSize': _pickedImage!.size,
                                                'mimeType': mimeType,
                                              },
                                            })
                                            .timeout(
                                              const Duration(seconds: 8),
                                            );

                                        final uploadUrl =
                                            upload['uploadUrl'] as String;
                                        mediaId = upload['mediaId'] as String;

                                        final dio = Dio();
                                        Response resp;

                                        if (_pickedImage!.path != null &&
                                            _pickedImage!.path!.isNotEmpty) {
                                          final file = File(
                                            _pickedImage!.path!,
                                          );
                                          final fileSize = await file.length();
                                          final dataStream = file.openRead();

                                          resp = await dio
                                              .put(
                                                uploadUrl,
                                                data: dataStream,
                                                options: Options(
                                                  headers: {
                                                    'Content-Type': mimeType,
                                                    'Content-Length': fileSize
                                                        .toString(),
                                                  },
                                                ),
                                              )
                                              .timeout(
                                                const Duration(seconds: 20),
                                              );
                                        } else if (_pickedImage!.bytes !=
                                            null) {
                                          final bytes = _pickedImage!.bytes!;
                                          resp = await dio
                                              .put(
                                                uploadUrl,
                                                data: bytes,
                                                options: Options(
                                                  headers: {
                                                    'Content-Type': mimeType,
                                                    'Content-Length': bytes
                                                        .length
                                                        .toString(),
                                                  },
                                                ),
                                              )
                                              .timeout(
                                                const Duration(seconds: 20),
                                              );
                                        } else {
                                          throw Exception(
                                            'No file data available to upload',
                                          );
                                        }

                                        if (resp.statusCode == null ||
                                            resp.statusCode! < 200 ||
                                            resp.statusCode! >= 300) {
                                          throw Exception('Upload failed');
                                        }
                                      }

                                      // Build payload
                                      final payload = <String, dynamic>{
                                        if (qCtrl.text.trim() !=
                                            q['question_text'])
                                          'question_text': qCtrl.text.trim(),
                                        if (marks != q['marks']) 'marks': marks,
                                        if (aCtrl.text.trim() != q['option_a'])
                                          'option_a': aCtrl.text.trim(),
                                        if (bCtrl.text.trim() != q['option_b'])
                                          'option_b': bCtrl.text.trim(),
                                        if (cCtrl.text.trim() != q['option_c'])
                                          'option_c': cCtrl.text.trim(),
                                        if (dCtrl.text.trim() != q['option_d'])
                                          'option_d': dCtrl.text.trim(),
                                        if (correct != q['correct_option'])
                                          'correct_option': correct,
                                      };

                                      if (_pickedImage != null) {
                                        payload['imageId'] = mediaId;
                                        if (q['image_id'] != null)
                                          payload['previous_imageId'] =
                                              q['image_id'];
                                      }

                                      if (_removeImage &&
                                          q['image_id'] != null) {
                                        payload['removeImage'] = true;
                                        payload['previous_imageId'] =
                                            q['image_id'];
                                      }

                                      await TestService()
                                          .updateQuestion(
                                            q['id'].toString(),
                                            payload,
                                          )
                                          .timeout(const Duration(seconds: 12));

                                      Navigator.of(context).pop(true);
                                    } catch (e) {
                                      setState(
                                        () => _formError =
                                            'Failed to update question',
                                      );
                                    } finally {
                                      setState(() => isSubmitting = false);
                                    }
                                  },
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.textOnPrimary,
                                    ),
                                  )
                                : const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    if (result == true) {
      await _fetchQuestions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.chevron_left),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _testDetails != null
              ? (_testDetails!['title'] ?? widget.testTitle)
              : widget.testTitle,
        ),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: (_isLoading || _isLoadingDetails)
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _testDetails != null
                                ? (_testDetails!['title'] ?? widget.testTitle)
                                : widget.testTitle,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          if (_testDetails != null &&
                              (_testDetails!['description'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                            Text(
                              _testDetails!['description'] ?? '',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_testDetails != null)
                                Row(
                                  children: [
                                    Text(
                                      'Marks:',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(width: 8),
                                    Chip(
                                      label: Text(
                                        '${_testDetails!['total_marks']}',
                                      ),
                                    ),
                                  ],
                                ),
                              if (_testDetails != null)
                                const SizedBox(height: 6),
                              if (_testDetails != null)
                                Row(
                                  children: [
                                    Text(
                                      'Duration:',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(width: 8),
                                    Chip(
                                      label: Text(
                                        '${_testDetails!['duration']} mins',
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    'Questions:',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(label: Text('${_questions.length}')),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _questions.isEmpty
                      ? const Center(child: Text('No questions'))
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 100),
                          itemCount: _questions.length,
                          itemBuilder: (context, idx) {
                            final q = _questions[idx];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 8.0,
                              ),
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  onExpansionChanged: (expanded) {
                                    setState(() {
                                      if (expanded) {
                                        _expandedQuestionIds.add(
                                          q['id'].toString(),
                                        );
                                      } else {
                                        _expandedQuestionIds.remove(
                                          q['id'].toString(),
                                        );
                                      }
                                    });
                                  },
                                  title: Text(
                                    q['question_text'] ?? '',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Chip(label: Text('${q['marks']} marks')),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert),
                                        onSelected: (v) async {
                                          if (v == 'edit') {
                                            Future.microtask(
                                              () => _showEditQuestionDialog(q),
                                            );
                                          } else if (v == 'delete') {
                                            final confirmed =
                                                await showDialog<bool>(
                                                  context: context,
                                                  builder: (c) => AlertDialog(
                                                    title: const Text(
                                                      'Delete question',
                                                    ),
                                                    content: const Text(
                                                      'Are you sure you want to delete this question? This cannot be undone.',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              c,
                                                            ).pop(false),
                                                        child: const Text(
                                                          'Cancel',
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              c,
                                                            ).pop(true),
                                                        child: const Text(
                                                          'Delete',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                            if (confirmed == true) {
                                              try {
                                                await TestService()
                                                    .deleteQuestion(
                                                      q['id'].toString(),
                                                    )
                                                    .timeout(
                                                      const Duration(
                                                        seconds: 8,
                                                      ),
                                                    );
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Question deleted',
                                                    ),
                                                  ),
                                                );
                                                await _fetchQuestions();
                                              } catch (e) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Failed to delete question',
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        },
                                        itemBuilder: (c) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Edit'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete'),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        _expandedQuestionIds.contains(
                                              q['id'].toString(),
                                            )
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                        vertical: 8.0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Show attached image if present
                                          if (q['image_id'] != null) ...[
                                            FutureBuilder<Uint8List>(
                                              future: () async {
                                                try {
                                                  final assetId = q['image_id']
                                                      .toString();
                                                  final usageId =
                                                      'question_image_${q['id']}';
                                                  final ok =
                                                      await mediaTokenCache
                                                          .ensureTokenForUsage(
                                                            usageId,
                                                            assetId: assetId,
                                                          );
                                                  if (!ok)
                                                    throw Exception(
                                                      'Failed to get media token',
                                                    );
                                                  final details =
                                                      mediaTokenCache
                                                          .getDetails(usageId);
                                                  final url =
                                                      details?['media_url']
                                                          as String?;
                                                  final token =
                                                      details?['worker_token']
                                                          as String?;
                                                  if (url == null)
                                                    throw Exception(
                                                      'No media URL',
                                                    );
                                                  final dio = Dio();
                                                  final resp = await dio
                                                      .get<List<int>>(
                                                        url,
                                                        options: Options(
                                                          responseType:
                                                              ResponseType
                                                                  .bytes,
                                                          headers: {
                                                            if (token != null)
                                                              'Authorization':
                                                                  'Bearer $token',
                                                          },
                                                        ),
                                                      );
                                                  return Uint8List.fromList(
                                                    resp.data!,
                                                  );
                                                } catch (e) {
                                                  rethrow;
                                                }
                                              }(),
                                              builder: (context, snap) {
                                                if (snap.connectionState !=
                                                    ConnectionState.done) {
                                                  return const SizedBox(
                                                    height: 160,
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                                  );
                                                }
                                                if (snap.hasError ||
                                                    snap.data == null) {
                                                  return const SizedBox(
                                                    height: 160,
                                                    child: Center(
                                                      child: Text(
                                                        'Failed to load image',
                                                      ),
                                                    ),
                                                  );
                                                }
                                                return ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.memory(
                                                    snap.data!,
                                                    height: 160,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          _buildOptionRow(
                                            context,
                                            'A',
                                            q['option_a'],
                                            q['correct_option'] == 'A',
                                          ),
                                          const SizedBox(height: 6),
                                          _buildOptionRow(
                                            context,
                                            'B',
                                            q['option_b'],
                                            q['correct_option'] == 'B',
                                          ),
                                          const SizedBox(height: 6),
                                          _buildOptionRow(
                                            context,
                                            'C',
                                            q['option_c'],
                                            q['correct_option'] == 'C',
                                          ),
                                          const SizedBox(height: 6),
                                          _buildOptionRow(
                                            context,
                                            'D',
                                            q['option_d'],
                                            q['correct_option'] == 'D',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddQuestionDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
