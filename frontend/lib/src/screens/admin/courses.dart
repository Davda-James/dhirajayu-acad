import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:crypto/crypto.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppColors.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppTypography.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppSpacing.dart';
import 'package:dhiraj_ayu_academy/src/services/api_service.dart';
import 'package:dhiraj_ayu_academy/src/widgets/common_widgets.dart';
import 'package:dhiraj_ayu_academy/src/screens/admin/course_details.dart';

class AdminCoursesScreen extends StatefulWidget {
  const AdminCoursesScreen({super.key});

  @override
  State<AdminCoursesScreen> createState() => _AdminCoursesScreenState();
}

class _AdminCoursesScreenState extends State<AdminCoursesScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isRetrying = false;
  bool _showAddForm = false;
  final List<Map<String, dynamic>> _courses = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _showAddCourseDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.9;
        return Container(
          height: maxHeight,
          decoration: const BoxDecoration(
            color: AppColors.backgroundWhite,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusLG),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _InlineAddCourse(
              onCreated: () async {
                Navigator.pop(context);
                await _loadCourses();
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadCourses({bool showGlobalLoading = true}) async {
    if (showGlobalLoading) {
      setState(() => _isLoading = true);
    } else {
      // clear previous error so RefreshIndicator can show
      setState(() {
        _isRefreshing = true;
        _errorMessage = null;
      });
    }
    try {
      // request courses from backend
      final resp = await _apiService.get('courses/get-all-courses');
      final data = resp.data as Map<String, dynamic>;
      setState(() {
        _courses.clear();
        _courses.addAll(
          (data['data'] as List<dynamic>).cast<Map<String, dynamic>>(),
        );
        _errorMessage = null;
      });
      // response received
    } on DioException catch (dio) {
      try {
        final data = dio.response?.data;
        if (data is Map && data['message'] != null) {
          setState(() {
            _errorMessage = data['message'].toString();
          });
        } else {
          setState(() {
            _errorMessage = 'Failed to load courses';
          });
        }
      } catch (_) {
        setState(() {
          _errorMessage = 'Failed to load courses';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load courses';
      });
    } finally {
      if (showGlobalLoading) {
        setState(() => _isLoading = false);
      } else {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _handleRetry() async {
    setState(() => _isRetrying = true);
    try {
      await _loadCourses(showGlobalLoading: true);
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('Courses', style: AppTypography.headlineMedium),
              ),
              ElevatedButton.icon(
                icon: Icon(_showAddForm ? Icons.close : Icons.add),
                label: Text(_showAddForm ? 'Close' : 'Add Course'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                ),
                onPressed: _showAddCourseDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PullToRefresh(
              onRefresh: () => _loadCourses(showGlobalLoading: false),
              child: (_isLoading && !_isRefreshing)
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ],
                    )
                  : (_errorMessage != null)
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 24.0,
                                ),
                                child: ErrorState(
                                  message: _errorMessage!,
                                  onRetry: _handleRetry,
                                  isLoading: _isRetrying,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : _courses.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.0),
                            child: Text('No courses yet'),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: [
                        ..._courses.map((c) {
                          final imageUrl = c['thumbnail_url'] as String?;
                          return SizedBox(
                            height: 240,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                                vertical: 8.0,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdminCourseDetailScreen(
                                        courseId: c['id'],
                                        courseTitle: c['title'] ?? '',
                                      ),
                                    ),
                                  );
                                },
                                child: _CourseCard(
                                  title: c['title'] ?? '',
                                  subtitle: c['description'] ?? '',
                                  price: c['is_paid'] == true
                                      ? (c['price'] as num?)?.toDouble()
                                      : null,
                                  imageUrl: imageUrl,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: const SizedBox.shrink(),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Course card used in list
class _CourseCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double? price;
  final String? imageUrl;

  const _CourseCard({
    required this.title,
    required this.subtitle,
    this.price,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image or placeholder
          if (imageUrl != null && imageUrl!.isNotEmpty)
            Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _placeholder(context),
            )
          else
            _placeholder(context),

          // Gradient overlay and text
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppTypography.titleMedium.copyWith(
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (price != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundWhite.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '₹${price!.toString()}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.surfaceLight, AppColors.backgroundLight],
          ),
        ),
        child: Center(
          child: Text(
            'Thumbnail',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Inline add course form used in admin courses screen
class _InlineAddCourse extends StatefulWidget {
  final VoidCallback? onCreated;
  const _InlineAddCourse({this.onCreated});

  @override
  State<_InlineAddCourse> createState() => _InlineAddCourseState();
}

class _InlineAddCourseState extends State<_InlineAddCourse> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _desc = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _thumb = TextEditingController();
  bool _isPaid = false;
  bool _submitting = false;
  PlatformFile? _selectedThumbFile;
  bool _isUploading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    String? thumbnailId;
    try {
      if (_selectedThumbFile != null) {
        setState(() => _isUploading = true);
        try {
          final picked = _selectedThumbFile!;
          final mimeType = (picked.path != null)
              ? (lookupMimeType(picked.path!) ?? 'application/octet-stream')
              : (picked.bytes != null
                    ? (lookupMimeType(picked.name) ??
                          'application/octet-stream')
                    : 'application/octet-stream');

          // For large uploads we require a file path so we can stream from disk and avoid OOM.
          if (picked.path == null) {
            throw Exception(
              'Thumbnail upload requires a file path. Please re-select the file with in-memory mode disabled.',
            );
          }
          final file = File(picked.path!);
          final fileSize = await file.length();
          final sha1Hex = (await sha1.bind(file.openRead()).first).toString();
          final dataStream = file.openRead();

          final payload = {
            'media': {
              'fileName': picked.name,
              'fileSize': fileSize,
              'mimeType': mimeType,
              'type': 'IMAGE',
              'title': 'thumbnail',
            },
          };
          print('[DEBUG] Thumbnail upload payload:');
          print(payload);
          try {
            final uploadResp = await ApiService().post(
              'courses/thumbnail/request-upload',
              data: payload,
            );
            print('[DEBUG] Thumbnail upload response:');
            print(uploadResp.data);
            final upload = uploadResp.data['upload'] as Map<String, dynamic>;
            final uploadUrl = upload['uploadUrl'] as String;
            final mediaId = upload['mediaId'] as String;
            final mediaPath = upload['mediaPath'] as String?;
            final authTokenHeader = upload['authToken'] as String?;

            final dio = Dio();
            final uploadHeaders = {
              if (authTokenHeader != null) 'Authorization': authTokenHeader,
              'Content-Type': 'b2/x-auto',
              'Content-Length': fileSize.toString(),
              if (mediaPath != null) 'X-Bz-File-Name': mediaPath,
              'X-Bz-Content-Sha1': sha1Hex,
            };

            final uploadResponse = await dio.post(
              uploadUrl,
              data: dataStream,
              options: Options(headers: uploadHeaders, contentType: mimeType),
            );

            if (uploadResponse.statusCode == null ||
                uploadResponse.statusCode! < 200 ||
                uploadResponse.statusCode! >= 300) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Upload failed'),
                  duration: Duration(seconds: 3),
                ),
              );
              throw Exception(
                'Upload failed with status ${uploadResponse.statusCode}',
              );
            }

            // confirm upload
            await ApiService().confirmMediaUpload([mediaId]);
            thumbnailId = mediaId; // store mediaId to attach to course
          } catch (e) {
            print('[DEBUG] Thumbnail upload error: $e');
            rethrow;
          }
        } finally {
          if (mounted) setState(() => _isUploading = false);
        }
      }

      final createData = {
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'is_paid': _isPaid,
        if (_isPaid) 'price': int.tryParse(_price.text) ?? 0,
        if (thumbnailId != null) 'thumbnail_id': thumbnailId,
      };
      final resp = await ApiService().post(
        'courses/create-course',
        data: createData,
      );
      if (resp.statusCode != 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create course')),
        );
        return;
      }

      widget.onCreated?.call();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    _thumb.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Create Course',
                      style: AppTypography.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => widget.onCreated?.call(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'Enter a valid title'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter a description'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Paid course'),
                  const SizedBox(width: 12),
                  Switch(
                    value: _isPaid,
                    onChanged: (v) => setState(() => _isPaid = v),
                  ),
                ],
              ),
              if (_isPaid) ...[
                TextFormField(
                  controller: _price,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (v) =>
                      (_isPaid && (v == null || double.tryParse(v) == null))
                      ? 'Enter a valid price'
                      : null,
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Thumbnail"),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child:
                              (_selectedThumbFile == null ||
                                  _selectedThumbFile!.path == null)
                              ? Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    size: 48,
                                    color: AppColors.textTertiary,
                                  ),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(_selectedThumbFile!.path!),
                                    fit: BoxFit.cover,
                                    width: 120,
                                    height: 120,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              icon: Icon(Icons.upload_file),
                              label: Text(
                                _selectedThumbFile == null
                                    ? 'Upload Image'
                                    : 'Change',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () async {
                                final res = await FilePicker.platform.pickFiles(
                                  type: FileType.image,
                                  allowMultiple: false,
                                  withData: false,
                                  withReadStream: true,
                                );
                                if (res != null && res.files.isNotEmpty) {
                                  setState(() {
                                    _selectedThumbFile = PlatformFile(
                                      name: res.files.first.name,
                                      path: res.files.first.path,
                                      size: res.files.first.size,
                                    );
                                  });
                                }
                              },
                            ),
                            if (_selectedThumbFile != null)
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(() => _selectedThumbFile = null),
                              ),
                          ],
                        ),
                        if (_selectedThumbFile != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              _selectedThumbFile!.name,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textTertiary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => widget.onCreated?.call(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: (_submitting || _isUploading) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                    ),
                    child: _submitting || _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
