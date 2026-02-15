import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: AppColors.backgroundWhite,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.radiusLG),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    Expanded(
                      child: _InlineAddCourse(
                        scrollController: scrollController,
                        onCreated: () async {
                          Navigator.pop(context);
                          await _loadCourses();
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _loadCourses({bool showGlobalLoading = true}) async {
    if (showGlobalLoading) {
      setState(() => _isLoading = true);
    } else {
      setState(() {
        _isRefreshing = true;
        _errorMessage = null;
      });
    }
    try {
      final resp = await _apiService.get('courses/get-all-courses');
      final data = resp.data as Map<String, dynamic>;
      setState(() {
        _courses.clear();
        _courses.addAll(
          (data['data'] as List<dynamic>).cast<Map<String, dynamic>>(),
        );
        _errorMessage = null;
      });
    } on DioException catch (dio) {
      try {
        final data = dio.response?.data;
        if (data is Map && data['message'] != null) {
          setState(() => _errorMessage = data['message'].toString());
        } else {
          setState(() => _errorMessage = 'Failed to load courses');
        }
      } catch (_) {
        setState(() => _errorMessage = 'Failed to load courses');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load courses');
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
                icon: const Icon(Icons.add),
                label: const Text('Add Course'),
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
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

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
          if (imageUrl != null && imageUrl!.isNotEmpty)
            Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _placeholder(context),
            )
          else
            _placeholder(context),

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
                          color: AppColors.textOnPrimary,
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
    return Container(
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
    );
  }
}

class _InlineAddCourse extends StatefulWidget {
  final ScrollController scrollController;
  final VoidCallback? onCreated;

  const _InlineAddCourse({required this.scrollController, this.onCreated});

  @override
  State<_InlineAddCourse> createState() => _InlineAddCourseState();
}

class _InlineAddCourseState extends State<_InlineAddCourse> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _desc = TextEditingController();
  final TextEditingController _price = TextEditingController();
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

          if (picked.path == null) {
            throw Exception(
              'Thumbnail upload requires a file path. Please re-select the file.',
            );
          }

          final file = File(picked.path!);
          final fileSize = await file.length();
          final dataStream = file.openRead();

          final payload = {
            'media': {
              'fileName': picked.name,
              'fileSize': fileSize,
              'mimeType': mimeType,
            },
          };

          final uploadResp = await ApiService().post(
            'courses/thumbnail/request-upload',
            data: payload,
          );

          final upload = uploadResp.data['upload'] as Map<String, dynamic>;
          final uploadUrl = upload['uploadUrl'] as String;
          final mediaId = upload['mediaId'] as String;

          final dio = Dio();
          final uploadResponse = await dio.put(
            uploadUrl,
            data: dataStream,
            options: Options(
              headers: {
                'Content-Type': mimeType,
                'Content-Length': fileSize.toString(),
              },
            ),
          );

          if (uploadResponse.statusCode == null ||
              uploadResponse.statusCode! < 200 ||
              uploadResponse.statusCode! >= 300) {
            throw Exception('Upload failed');
          }

          thumbnailId = mediaId;
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create course')),
          );
        }
        return;
      }

      if (mounted) {
        widget.onCreated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create Course', style: AppTypography.headlineMedium),
              const SizedBox(height: 20),

              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'Enter a valid title'
                    : null,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _desc,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter a description'
                    : null,
              ),

              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text('Paid course'),
                value: _isPaid,
                onChanged: (v) => setState(() => _isPaid = v),
                contentPadding: EdgeInsets.zero,
              ),

              if (_isPaid) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _price,
                  decoration: const InputDecoration(
                    labelText: 'Price (₹)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) =>
                      (_isPaid && (v == null || double.tryParse(v) == null))
                      ? 'Enter a valid price'
                      : null,
                ),
              ],

              const SizedBox(height: 20),

              Text('Thumbnail', style: AppTypography.titleMedium),
              const SizedBox(height: 12),

              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child:
                    (_selectedThumbFile == null ||
                        _selectedThumbFile!.path == null)
                    ? Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 64,
                          color: AppColors.textTertiary,
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_selectedThumbFile!.path!),
                          fit: BoxFit.cover,
                        ),
                      ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      _selectedThumbFile == null ? 'Upload Image' : 'Change',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.textOnPrimary,
                    ),
                    onPressed: () async {
                      final res = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                        allowMultiple: false,
                        withData: false,
                      );
                      if (res != null && res.files.isNotEmpty) {
                        setState(() {
                          _selectedThumbFile = res.files.first;
                        });
                      }
                    },
                  ),
                  if (_selectedThumbFile != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          setState(() => _selectedThumbFile = null),
                    ),
                  ],
                ],
              ),

              if (_selectedThumbFile != null) ...[
                const SizedBox(height: 8),
                Text(
                  _selectedThumbFile!.name,
                  style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: (_submitting || _isUploading) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: (_submitting || _isUploading)
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Create Course'),
                  ),
                ],
              ),

              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ],
    );
  }
}
