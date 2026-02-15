import 'package:dhiraj_ayu_academy/src/utils/common.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:mime/mime.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppColors.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppTypography.dart';
import 'package:dhiraj_ayu_academy/src/services/api_service.dart';
import 'package:dhiraj_ayu_academy/src/services/modules_cache_service.dart';
import 'package:dhiraj_ayu_academy/src/widgets/media_player_widget.dart';
import 'package:dhiraj_ayu_academy/src/widgets/add_media_sheet.dart';
import 'package:dhiraj_ayu_academy/src/services/test_service.dart';
import 'package:dhiraj_ayu_academy/src/screens/admin/test_detail_screen.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppSpacing.dart';

/// Data structure for navigation stack
class NavNode {
  final String type; // 'module' or 'folder'
  final String id;
  final String title;
  final String? parentId;
  NavNode({
    required this.type,
    required this.id,
    required this.title,
    this.parentId,
  });
}

/// AdminCourseDetailScreen: Shows modules, folders, and media for a selected course
class AdminCourseDetailScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  const AdminCourseDetailScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<AdminCourseDetailScreen> createState() =>
      _AdminCourseDetailScreenState();
}

class _AdminCourseDetailScreenState extends State<AdminCourseDetailScreen> {
  // Cache for media usages by folder
  final Map<String, List<Map<String, dynamic>>> _mediaByFolder = {};
  // In-flight fetches to deduplicate concurrent requests
  final Map<String, Future<List<Map<String, dynamic>>>> _mediaFetchInFlight =
      {};
  final Map<String, Future<List<Map<String, dynamic>>>> _foldersFetchInFlight =
      {};

  Future<List<Map<String, dynamic>>> _fetchMediaForFolder(
    String folderId,
  ) async {
    if (_mediaByFolder.containsKey(folderId)) {
      return _mediaByFolder[folderId]!;
    }
    if (_mediaFetchInFlight[folderId] != null) {
      return _mediaFetchInFlight[folderId]!;
    }

    final future = ModulesCacheService().fetchUsages(folderId).then((usages) {
      _mediaByFolder[folderId] = usages;
      return usages;
    });

    _mediaFetchInFlight[folderId] = future;
    future.whenComplete(() => _mediaFetchInFlight.remove(folderId));
    return future;
  }

  bool _isAdding = false;
  bool _isLoadingModules = false;
  List<Map<String, dynamic>> _modules = [];
  List<NavNode> _navStack = [];
  final Map<String, List<Map<String, dynamic>>> _foldersByModule = {};
  final Map<String, List<Map<String, dynamic>>> _subfoldersByFolder = {};

  // Tests state
  List<Map<String, dynamic>> _tests = [];
  bool _isLoadingTests = false;
  bool _showTests = false;

  Future<void> _fetchTests() async {
    setState(() => _isLoadingTests = true);
    try {
      final tests = await TestService().fetchTestsForCourse(widget.courseId);
      setState(() => _tests = tests.cast<Map<String, dynamic>>());
    } catch (e) {
      setState(() => _tests = []);
    } finally {
      setState(() => _isLoadingTests = false);
    }
  }

  Future<void> _showAddTestDialog([Map<String, dynamic>? existingTest]) async {
    final titleCtrl = TextEditingController(
      text: existingTest != null ? (existingTest['title'] ?? '') : '',
    );
    final descCtrl = TextEditingController(
      text: existingTest != null ? (existingTest['description'] ?? '') : '',
    );
    final marksCtrl = TextEditingController(
      text: existingTest != null
          ? (existingTest['total_marks']?.toString() ?? '')
          : '',
    );
    final durationCtrl = TextEditingController(
      text: existingTest != null
          ? (existingTest['duration']?.toString() ?? '')
          : '',
    );
    final negativeMarksCtrl = TextEditingController(
      text: existingTest != null
          ? (existingTest['negative_marks']?.toString() ?? '')
          : '',
    );

    final _formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        bool isCreating = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(existingTest == null ? 'Add Test' : 'Edit Test'),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.72,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: titleCtrl,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Title is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: descCtrl,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                        validator: (v) => null,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: marksCtrl,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Total Marks',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final text = (v ?? '').trim();
                          final n = int.tryParse(text);
                          if (text.isEmpty) return 'Total marks is required';
                          if (n == null) return 'Enter a valid integer';
                          if (n < 0)
                            return 'Total Marks must be zero or greater';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: durationCtrl,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Duration (minutes)',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n <= 0)
                            return 'Duration must be a positive number';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: negativeMarksCtrl,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Negative marks (default 0.25)',
                          hintText: 'e.g. 0.25',
                        ),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          final text = (v ?? '').trim();
                          if (text.isEmpty) return null;
                          final d = double.tryParse(text);
                          if (d == null) return 'Enter a valid number';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isCreating
                    ? null
                    : () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isCreating
                    ? null
                    : () async {
                        final title = titleCtrl.text.trim();
                        final totalMarks =
                            int.tryParse(marksCtrl.text.trim()) ?? 0;
                        final duration = int.tryParse(durationCtrl.text.trim());

                        if (!(_formKey.currentState?.validate() ?? false)) {
                          return;
                        }

                        setState(() => isCreating = true);
                        try {
                          final negText = negativeMarksCtrl.text.trim();
                          final negVal = negText.isEmpty
                              ? null
                              : double.tryParse(negText);

                          if (existingTest == null) {
                            await TestService()
                                .createTest({
                                  'course_id': widget.courseId,
                                  'title': title,
                                  'description': descCtrl.text.trim(),
                                  'total_marks': totalMarks,
                                  'duration': duration,
                                  if (negVal != null) 'negative_marks': negVal,
                                })
                                .timeout(const Duration(seconds: 12));
                          } else {
                            final testId = existingTest['id'];
                            await TestService()
                                .updateTest(testId.toString(), {
                                  'title': title,
                                  'description': descCtrl.text.trim(),
                                  'total_marks': totalMarks,
                                  'duration': duration,
                                  if (negVal != null) 'negative_marks': negVal,
                                })
                                .timeout(const Duration(seconds: 12));
                          }
                          Navigator.pop(context, true);
                        } on TimeoutException {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Request timed out. Please check your connection and try again.',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          String msg = existingTest == null
                              ? 'Failed to create test'
                              : 'Failed to update test';
                          if (e is DioException) {
                            final data = e.response?.data;
                            if (data is Map && data['message'] != null) {
                              msg = data['message'];
                            }
                            if (data is Map && data['errors'] != null) {
                              final errs = data['errors'];
                              if (errs is List) {
                                final joined = errs
                                    .map((it) {
                                      if (it is Map && it['message'] != null)
                                        return it['message'].toString();
                                      return it.toString();
                                    })
                                    .join('; ');
                                msg = '$msg: $joined';
                              }
                            }
                          } else {
                            msg = e.toString();
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(msg)));
                          }
                        } finally {
                          if (mounted) setState(() => isCreating = false);
                        }
                      },
                child: isCreating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnPrimary,
                        ),
                      )
                    : Text(existingTest == null ? 'Create' : 'Update'),
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      await _fetchTests();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchModules();
  }

  Future<void> _fetchModules() async {
    setState(() {
      _isLoadingModules = true;
    });
    try {
      final resp = await ApiService().get('modules/course/${widget.courseId}');
      final modules = (resp.data['modules'] as List)
          .cast<Map<String, dynamic>>();
      setState(() {
        _modules = modules;
        _navStack = [];
        _isLoadingModules = false;
      });
    } catch (e) {
      debugPrint('Failed to load modules: $e');
      setState(() {
        _isLoadingModules = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load modules')));
      }
    }
  }

  Future<void> _showAddModuleDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Module'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Module Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _addModule(result);
    }
  }

  Future<void> _addModule(String name) async {
    setState(() {
      _isAdding = true;
    });
    try {
      final resp = await ApiService().post(
        'modules/create',
        data: {'courseId': widget.courseId, 'title': name},
      );
      setState(() {
        _modules.add({
          'id': resp.data['module']['id'],
          'courseId': resp.data['module']['courseId'],
          'title': resp.data['module']['title'],
          'folders': [],
          'mediaCount': 0,
        });
      });
    } on DioException catch (e) {
      String msg = 'Failed to add module';
      debugPrint(
        'DioException: status=${e.response?.statusCode}, data=${e.response?.data}',
      );
      if (e.response?.data != null && e.response?.data['message'] != null) {
        msg = e.response?.data['message'];
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      debugPrint('Other error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to add module')));
      }
    } finally {
      setState(() => _isAdding = false);
    }
  }

  Future<void> _showAddFolderDialog(String moduleId, {String? parentId}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _addFolder(moduleId, result, parentId: parentId);
    }
  }

  Future<void> _handleAddMedia(
    String moduleId, {
    String? parentFolderId,
  }) async {
    try {
      final sheetResult = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
        ),
        builder: (context) => const AddMediaSheet(),
      );

      if (sheetResult == null) return;

      final picked = sheetResult['picked'] as PlatformFile;
      final title = (sheetResult['title'] as String?) ?? picked.name;
      final desc = (sheetResult['description'] as String?) ?? '';
      final duration = sheetResult['duration'] as int?;

      final mimeType =
          lookupMimeType(picked.path ?? picked.name) ??
          'application/octet-stream';
      final mapType = mimeType.startsWith('video/')
          ? 'VIDEO'
          : mimeType.startsWith('audio/')
          ? 'AUDIO'
          : mimeType.startsWith('image/')
          ? 'IMAGE'
          : 'DOCUMENT';

      final mediaPayload = {
        'fileName': picked.name,
        'fileSize': picked.size,
        'mimeType': mimeType,
        'type': mapType,
        'title': title,
        'description': desc,
        'duration': duration,
      };

      final payload = {
        'courseId': widget.courseId,
        'moduleId': moduleId,
        'moduleFolderId': parentFolderId,
        'media': [mediaPayload],
      };

      final resp = await ApiService().requestUpload(widget.courseId, payload);
      final uploads = (resp.data['uploads'] as List)
          .cast<Map<String, dynamic>>();
      if (uploads.isEmpty) throw Exception('No upload URL returned');

      final up = uploads.first;
      final mediaId = up['mediaId'] as String;
      final uploadUrl = up['uploadUrl'] as String;

      if (picked.path == null) {
        throw Exception(
          'Large file upload requires a file path. Please re-select the file with in-memory mode disabled.',
        );
      }

      final file = File(picked.path!);
      final dataStream = file.openRead();
      final contentLength = await file.length();

      final dio = Dio();
      final uploadHeaders = {
        'Content-Type': mimeType,
        'Content-Length': contentLength.toString(),
      };

      setState(() {
        _isAdding = true;
      });

      final uploadResp = await dio.put(
        uploadUrl,
        data: dataStream,
        options: Options(headers: uploadHeaders),
      );

      if (uploadResp.statusCode == null ||
          uploadResp.statusCode! < 200 ||
          uploadResp.statusCode! >= 300) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload failed'),
            duration: Duration(seconds: 3),
          ),
        );
        throw Exception('Upload failed for ${picked.name}');
      }

      // show complete
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload complete'),
          duration: Duration(seconds: 2),
        ),
      );

      await ApiService().confirmMediaUpload([mediaId]);

      final usageId = up['usageId'] as String?;
      final createdUsage = {
        'id': usageId ?? mediaId,
        'media_id': mediaId,
        'title': mediaPayload['title'],
        'description': mediaPayload['description'] ?? '',
        'order': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'media_asset': {
          'id': mediaId,
          'file_name': mediaPayload['fileName'],
          'file_size': mediaPayload['fileSize'],
          'mime_type': mediaPayload['mimeType'],
          'media_path': up['mediaPath'],
          'type': mediaPayload['type'],
          'duration': mediaPayload['duration'] ?? null,
          'status': 'PENDING',
        },
      };

      // Update UI atomically to avoid intermediate jerks
      if (mounted) {
        setState(() {
          if (parentFolderId != null) {
            if (_mediaByFolder.containsKey(parentFolderId)) {
              _mediaByFolder[parentFolderId]!.add(createdUsage);
            } else {
              _mediaByFolder[parentFolderId] = [createdUsage];
            }
          } else {
            _doFetchFoldersForModule(moduleId)
                .then((_) {
                  if (mounted) setState(() {});
                })
                .catchError((e) {
                  debugPrint('Background folders refresh failed: $e');
                });
          }
          _isAdding = false;
        });
      }
    } catch (e) {
      debugPrint('Add media error: $e');
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading media: $e')));
      }
    }
  }

  Future<void> _addFolder(
    String moduleId,
    String name, {
    String? parentId,
  }) async {
    setState(() {
      _isAdding = true;
    });
    try {
      final data = {'moduleId': moduleId, 'title': name};
      if (parentId != null) data['parentId'] = parentId;
      final resp = await ApiService().post('folders/create', data: data);
      final newFolder = resp.data['folder'] ?? {'title': name};
      setState(() {
        if (parentId == null) {
          // Top-level folder
          _foldersByModule[moduleId] = [
            ...(_foldersByModule[moduleId] ?? []),
            newFolder,
          ];
        } else {
          // Subfolder
          _subfoldersByFolder[parentId] = [
            ...(_subfoldersByFolder[parentId] ?? []),
            newFolder,
          ];
        }
        _isAdding = false;
      });
    } catch (e) {
      debugPrint('Failed to add folder: $e');
      setState(() => _isAdding = false);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to add folder')));
      }
    }
  }

  Future<void> _deleteModule(String moduleId) async {
    try {
      await ApiService().delete('modules/$moduleId');
      await _fetchModules();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Module deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete module')),
        );
      }
    }
  }

  Future<void> _deleteFolder(String folderId) async {
    try {
      await ApiService().delete('folders/$folderId');
      // Remove from local cache (foldersByModule or subfoldersByFolder)
      bool removed = false;
      // Remove from subfoldersByFolder if present
      _subfoldersByFolder.forEach((parentId, subfolders) {
        final idx = subfolders.indexWhere((f) => f['id'] == folderId);
        if (idx != -1) {
          subfolders.removeAt(idx);
          removed = true;
        }
      });
      // Remove from foldersByModule if present and not already removed
      if (!removed) {
        _foldersByModule.forEach((moduleId, folders) {
          final idx = folders.indexWhere((f) => f['id'] == folderId);
          if (idx != -1) {
            folders.removeAt(idx);
          }
        });
      }
      setState(() {}); // Refresh view
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Folder deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete folder')),
        );
      }
    }
  }

  Future<void> _deleteMedia(String mediaId, String folderId) async {
    try {
      await ApiService().delete('media-usages/delete/$mediaId');

      setState(() {
        if (_mediaByFolder.containsKey(folderId)) {
          _mediaByFolder[folderId]!.removeWhere(
            (media) => media['id'] == mediaId,
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Media deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete media: $e')));
    }
  }

  // Future<void> _addMediaToFolder(
  //   String folderId,
  //   Map<String, dynamic> media,
  // ) async {
  //   setState(() {
  //     if (_mediaByFolder.containsKey(folderId)) {
  //       _mediaByFolder[folderId]!.add(media);
  //     } else {
  //       _mediaByFolder[folderId] = [media];
  //     }
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(widget.courseTitle, style: AppTypography.headlineMedium),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBreadcrumb(),
                    const SizedBox(height: 8),
                    // Toggle between Modules and Tests (only at course root)
                    _navStack.isEmpty
                        ? Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showTests = false;
                                  });
                                },
                                child: Text(
                                  'Modules',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: _showTests
                                        ? AppColors.textSecondary
                                        : AppColors.primaryGreen,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  setState(() {
                                    _showTests = true;
                                  });
                                  // fetch tests for this course
                                  await _fetchTests();
                                },
                                child: Text(
                                  'Tests',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: _showTests
                                        ? AppColors.primaryGreen
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ],
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(
                        _navStack.isEmpty
                            ? 'modules'
                            : '${_navStack.last.type}_${_navStack.last.id}',
                      ),
                      child: _buildContentView(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isAdding)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: AppColors.primaryGreen,
                minHeight: 3,
              ),
            ),
        ],
      ),
      floatingActionButton:
          (_navStack.isEmpty &&
              ((_showTests && _tests.isNotEmpty) ||
                  (!_showTests && _modules.isNotEmpty)))
          ? Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  onPressed: _isAdding
                      ? null
                      : () {
                          if (_showTests) {
                            _showAddTestDialog();
                          } else {
                            _showAddModuleDialog();
                          }
                        },
                  icon: const Icon(Icons.add),
                  label: Text(_showTests ? 'Add Test' : 'Add Module'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBreadcrumb() {
    if (_navStack.isEmpty) {
      // Show context-sensitive title
      return Text(
        _showTests ? 'Tests' : 'Modules & Content',
        style: AppTypography.titleMedium,
      );
    }
    List<Widget> crumbs = [];
    crumbs.add(
      GestureDetector(
        onTap: () {
          setState(() {
            _navStack.clear();
            _showTests = false; // ensure we return to Modules view
          });
        },
        child: Text(
          'Modules',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.primaryGreen,
          ),
        ),
      ),
    );
    for (int i = 0; i < _navStack.length; i++) {
      crumbs.add(const Icon(Icons.chevron_right, size: 20));
      final node = _navStack[i];
      crumbs.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _navStack = _navStack.sublist(0, i + 1);
            });
          },
          child: Text(
            node.title,
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.primaryGreen,
            ),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: crumbs),
    );
  }

  Widget _buildContentView() {
    if (_navStack.isEmpty) {
      // Toggle view: Tests or Modules
      if (_showTests) {
        // Show tests list
        if (_isLoadingTests && _tests.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!_isLoadingTests && _tests.isEmpty) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            children: [
              _buildEmptyState(
                title: 'No tests yet',
                subtitle: 'Add your first test using the button below.',
                primaryAction: _showAddTestDialog,
                primaryLabel: 'Add Test',
                primaryIcon: Icons.add,
                titleStyle: AppTypography.titleLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
                subtitleStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
                containerSize: 140,
                iconSize: 64,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          );
        }

        return ListView.builder(
          key: const ValueKey('tests'),
          itemCount: _tests.length,
          itemBuilder: (context, idx) {
            final t = _tests[idx];
            return ListTile(
              leading: const Icon(Icons.quiz, color: AppColors.primaryGreen),
              title: Text(
                t['title'] ?? 'Test',
                style: AppTypography.titleMedium,
              ),
              subtitle: Text('${t['total_marks']} marks'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminTestDetailScreen(
                      testId: t['id'],
                      testTitle: t['title'] ?? 'Test',
                      test: t,
                    ),
                  ),
                );
              },
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    await _showAddTestDialog(t);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                ],
              ),
            );
          },
        );
      }

      // Show modules list
      if (_isLoadingModules && _modules.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      if (!_isLoadingModules && _modules.isEmpty) {
        return RefreshIndicator(
          onRefresh: () async {
            await _fetchModules();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _buildEmptyState(
                title: 'No modules yet',
                subtitle: 'Add your first module using the + button.',
                primaryAction: _showAddModuleDialog,
                primaryLabel: 'Add Module',
                primaryIcon: Icons.add,
                titleStyle: AppTypography.titleLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
                subtitleStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
                containerSize: 140,
                iconSize: 64,
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          await _fetchModules();
        },
        child: ListView.builder(
          key: const ValueKey('modules'),
          itemCount: _modules.length,
          itemBuilder: (context, idx) {
            final module = _modules[idx];
            return ListTile(
              leading: const Icon(Icons.folder_open),
              title: Text(
                module['title'] ?? 'Module',
                style: AppTypography.titleMedium,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Delete Module',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Module'),
                      content: const Text(
                        'Are you sure you want to delete this module and all its folders and media?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _deleteModule(module['id']);
                  }
                },
              ),
              onTap: () => _openModule(module),
            );
          },
        ),
      );
    } else {
      final node = _navStack.last;
      if (node.type == 'module') {
        // Use cache directly if available
        final folders = _foldersByModule[node.id];
        if (folders != null) {
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _foldersByModule.remove(node.id);
              });
            },
            child: folders.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _buildEmptyState(
                        title: 'No folders. Tap + to add.',
                        primaryAction: () => _showAddFolderDialog(node.id),
                        primaryLabel: 'Add Folder',
                        secondaryAction: () => _handleAddMedia(node.id),
                        secondaryLabel: 'Add Media',
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView(
                          children: [
                            ...folders.map(
                              (folder) => ListTile(
                                leading: const Icon(Icons.folder),
                                title: Text(
                                  folder['title'] ?? 'Folder',
                                  style: AppTypography.titleMedium,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Delete Folder',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete Folder'),
                                        content: const Text(
                                          'Are you sure you want to delete this folder and all its subfolders and media?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _deleteFolder(folder['id']);
                                    }
                                  },
                                ),
                                onTap: () =>
                                    _openFolder(folder['moduleId'], folder),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _showAddFolderDialog(node.id),
                                icon: const Icon(Icons.create_new_folder),
                                label: const Text('Add Folder'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () => _handleAddMedia(node.id),
                                icon: const Icon(Icons.add_photo_alternate),
                                label: const Text('Add Media'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          );
        } else {
          // Not in cache, use FutureBuilder
          return FutureBuilder(
            key: ValueKey('folders_${node.id}'),
            future: _fetchFoldersForModule(node.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final folders = snapshot.data ?? [];
              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _foldersByModule.remove(node.id);
                  });
                },
                child: folders.isEmpty
                    ? _buildEmptyState(
                        title: 'No folders. Tap + to add.',
                        primaryAction: () => _showAddFolderDialog(node.id),
                        primaryLabel: 'Add Folder',
                        secondaryAction: () =>
                            _handleAddMedia(node.id, parentFolderId: null),
                        secondaryLabel: 'Add Media',
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: ListView(
                              children: [
                                ...folders.map(
                                  (folder) => ListTile(
                                    leading: const Icon(Icons.folder),
                                    title: Text(
                                      folder['title'] ?? 'Folder',
                                      style: AppTypography.titleMedium,
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      tooltip: 'Delete Folder',
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Folder'),
                                            content: const Text(
                                              'Are you sure you want to delete this folder and all its subfolders and media?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await _deleteFolder(folder['id']);
                                        }
                                      },
                                    ),
                                    onTap: () =>
                                        _openFolder(folder['moduleId'], folder),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _showAddFolderDialog(node.id),
                                    icon: const Icon(Icons.create_new_folder),
                                    label: const Text('Add Folder'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: () => _handleAddMedia(
                                      _navStack
                                          .firstWhere((n) => n.type == 'module')
                                          .id,
                                      parentFolderId: node.id,
                                    ),
                                    icon: const Icon(Icons.add_photo_alternate),
                                    label: const Text('Add Media'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              );
            },
          );
        }
      } else if (node.type == 'media') {
        // Inline media detail view (keeps AppBar & breadcrumb intact)
        // Find media details from cached usages
        String? foundAssetId;
        String? foundType;
        int? foundDuration;

        _mediaByFolder.forEach((folderId, usages) {
          for (final u in usages) {
            if (u['id'] == node.id) {
              final asset = u['media_asset'] ?? {};
              foundAssetId = asset['id']?.toString();
              foundType = asset['type']?.toString();
              foundDuration = asset['duration'] as int?;
              break;
            }
          }
        });

        if (foundAssetId == null) {
          return const Center(child: Text('Media details not found'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(node.title, style: AppTypography.titleLarge),
              const SizedBox(height: 12),
              if (foundType != null)
                Text('Type: $foundType', style: AppTypography.bodyMedium),
              const SizedBox(height: 8),
              if (foundDuration != null)
                Text(
                  'Duration: ${formatDurationHms(foundDuration!)}',
                  style: AppTypography.bodyMedium,
                ),
              const SizedBox(height: 12),

              MediaPlayerWidget(
                usageId: node.id,
                assetId: foundAssetId!,
                type: foundType ?? 'UNKNOWN',
              ),
            ],
          ),
        );
      } else if (node.type == 'folder') {
        // Show subfolders and media in this folder
        return FutureBuilder(
          key: ValueKey('subfolders_and_media_${node.id}'),
          future: Future.wait([
            _fetchSubfolders(node.id),
            _fetchMediaForFolder(node.id),
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final folders =
                (snapshot.data?[0] as List?) ??
                _subfoldersByFolder[node.id] ??
                [];
            final media = _mediaByFolder.containsKey(node.id)
                ? _mediaByFolder[node.id]!
                : (snapshot.data?[1] as List?) ?? [];
            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _subfoldersByFolder.remove(node.id);
                  _mediaByFolder.remove(node.id);
                });
              },
              child: (folders.isEmpty && media.isEmpty)
                  // Only show the icon empty state with both buttons centered, but inside a scrollable ListView for pull-to-refresh
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        _buildEmptyState(
                          title: 'No subfolders or media yet.',
                          subtitle:
                              'Add your first folder or media using the buttons below.',
                          primaryAction: () => _showAddFolderDialog(
                            _navStack.firstWhere((n) => n.type == 'module').id,
                            parentId: node.id,
                          ),
                          primaryLabel: 'Add Folder',
                          secondaryAction: () => _handleAddMedia(
                            _navStack.firstWhere((n) => n.type == 'module').id,
                            parentFolderId: node.id,
                          ),
                          secondaryLabel: 'Add Media',
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              if (folders.isNotEmpty) ...[
                                ...folders.map(
                                  (folder) => ListTile(
                                    leading: const Icon(Icons.folder),
                                    title: Text(
                                      folder['title'] ?? 'Folder',
                                      style: AppTypography.titleMedium,
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      tooltip: 'Delete Folder',
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Folder'),
                                            content: const Text(
                                              'Are you sure you want to delete this folder and all its subfolders and media?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await _deleteFolder(folder['id']);
                                        }
                                      },
                                    ),
                                    onTap: () =>
                                        _openFolder(folder['moduleId'], folder),
                                  ),
                                ),
                                const Divider(),
                              ],
                              if (media.isNotEmpty) ...[
                                // Debug: log each raw usage and its resolved media object to diagnose missing fields
                                ...media.map((m) {
                                  final mediaObj = _resolveMediaFromUsage(m);

                                  return _buildMediaCard(mediaObj, node.id);
                                }).toList(),
                              ],
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _showAddFolderDialog(
                                    _navStack
                                        .firstWhere((n) => n.type == 'module')
                                        .id,
                                    parentId: node.id,
                                  ),
                                  icon: const Icon(Icons.create_new_folder),
                                  label: const Text('Add Folder'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryGreen,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () => _handleAddMedia(
                                    _navStack
                                        .firstWhere((n) => n.type == 'module')
                                        .id,
                                    parentFolderId: node.id,
                                  ),
                                  icon: const Icon(Icons.add_photo_alternate),
                                  label: const Text('Add Media'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            );
          },
        );
      }
      return const SizedBox.shrink();
    }
  }

  void _openModule(Map<String, dynamic> module) {
    setState(() {
      _navStack.add(
        NavNode(
          type: 'module',
          id: module['id'],
          title: module['title'],
          parentId: null,
        ),
      );
      _showTests = false; // hide Tests view when navigating into a module
    });
  }

  void _openFolder(String moduleId, Map<String, dynamic> folder) {
    setState(() {
      _navStack.add(
        NavNode(
          type: 'folder',
          id: folder['id'],
          title: folder['title'],
          parentId: folder['parent_id'],
        ),
      );
      _showTests = false; // hide Tests view when navigating into a folder
    });
  }

  Future<List<Map<String, dynamic>>> _doFetchFoldersForModule(
    String moduleId,
  ) async {
    final resp = await ApiService().get('folders/module/$moduleId');
    final folders = (resp.data['folders'] as List).cast<Map<String, dynamic>>();
    _foldersByModule[moduleId] = folders;
    return folders;
  }

  Future<List<Map<String, dynamic>>> _fetchFoldersForModule(
    String moduleId,
  ) async {
    // Use local cache if available
    if (_foldersByModule.containsKey(moduleId)) {
      debugPrint(
        'Cache hit: folders for module $moduleId (${_foldersByModule[moduleId]!.length} items)',
      );
      return _foldersByModule[moduleId]!;
    }
    if (_foldersFetchInFlight[moduleId] != null) {
      debugPrint('Using in-flight fetch for folders of module $moduleId');
      return _foldersFetchInFlight[moduleId]!;
    }
    final future = _doFetchFoldersForModule(moduleId);
    _foldersFetchInFlight[moduleId] = future;
    future.whenComplete(() => _foldersFetchInFlight.remove(moduleId));
    return future;
  }

  Future<List<Map<String, dynamic>>> _fetchSubfolders(String folderId) async {
    // Use local cache if available
    if (_subfoldersByFolder.containsKey(folderId)) {
      return _subfoldersByFolder[folderId]!;
    }
    // Fallback to old logic if not cached
    final moduleId = _navStack.firstWhere((n) => n.type == 'module').id;
    final resp = await ApiService().get('folders/module/$moduleId');
    final allFolders = (resp.data['folders'] as List)
        .cast<Map<String, dynamic>>();
    Map<String, dynamic>? findFolder(
      List<Map<String, dynamic>> folders,
      String id,
    ) {
      for (final f in folders) {
        if (f['id'] == id) return f;
        if (f['children'] != null) {
          final found = findFolder(
            (f['children'] as List).cast<Map<String, dynamic>>(),
            id,
          );
          if (found != null) return found;
        }
      }
      return null;
    }

    final folderNode = findFolder(allFolders, folderId);
    if (folderNode != null && folderNode['children'] != null) {
      final subfolders = (folderNode['children'] as List)
          .cast<Map<String, dynamic>>();
      _subfoldersByFolder[folderId] = subfolders;
      return subfolders;
    }
    _subfoldersByFolder[folderId] = [];
    return [];
  }

  Map<String, dynamic> _resolveMediaFromUsage(Map<String, dynamic> usage) {
    // asset may be missing; prefer asset fields but fall back to usage-level fields
    final asset =
        (usage['media'] as Map<String, dynamic>?) ??
        (usage['media_asset'] as Map<String, dynamic>?) ??
        {};
    final String? fileName =
        (asset['fileName'] ?? asset['file_name'] ?? usage['title']) as String?;
    final String? mimeType =
        (asset['mimeType'] ?? asset['mime_type'] ?? usage['mime_type'])
            as String?;
    final String? type = (asset['type'] ?? usage['type']) as String?;
    final String? title =
        (usage['title'] as String?) ?? asset['title'] ?? fileName;
    final dynamic durationRaw = asset['duration'] ?? usage['duration'];
    final int? duration = durationRaw is String
        ? int.tryParse(durationRaw)
        : (durationRaw is int ? durationRaw : null);
    final dynamic fileSize =
        asset['fileSize'] ?? asset['file_size'] ?? usage['fileSize'];
    final String? usageId = usage['id'] as String?;
    final String? assetId = (asset['id'] ?? usage['media_id']) as String?;

    return {
      'fileName': fileName,
      'mimeType': mimeType,
      'type': type,
      'title': title,
      'duration': duration,
      'fileSize': fileSize,
      'usageId': usageId,
      'assetId': assetId,
      'raw': usage,
    };
  }

  Widget _buildEmptyState({
    required String title,
    String? subtitle,
    required VoidCallback primaryAction,
    String primaryLabel = 'Add Folder',
    IconData primaryIcon = Icons.create_new_folder,
    VoidCallback? secondaryAction,
    String? secondaryLabel,
    IconData secondaryIcon = Icons.add_photo_alternate,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    double containerSize = 120,
    double iconSize = 56,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Build the core empty-state content once so it can be reused.
        final content = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: containerSize,
                height: containerSize,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.folder_outlined,
                      size: iconSize,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style:
                    titleStyle ??
                    AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style:
                      subtitleStyle ??
                      AppTypography.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Center(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: primaryAction,
                        icon: Icon(primaryIcon),
                        label: Text(primaryLabel),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                        ),
                      ),
                      if (secondaryAction != null && secondaryLabel != null)
                        ElevatedButton.icon(
                          onPressed: secondaryAction,
                          icon: Icon(secondaryIcon),
                          label: Text(secondaryLabel),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        if (constraints.maxHeight.isFinite) {
          return SizedBox(
            height: constraints.maxHeight,
            child: Center(child: content),
          );
        }

        final mq = MediaQuery.of(context);
        final verticalPadding = mq.size.height * 0.12;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 24.0,
            vertical: verticalPadding,
          ),
          child: Center(child: content),
        );
      },
    );
  }

  Widget _buildMediaCard(Map<String, dynamic> mediaObj, String folderId) {
    final String? usageId = mediaObj['usageId'] as String?;
    final String mediaUsageId = usageId ?? '';

    final String mediaTitle = mediaObj['title'];
    final String mediaType = mediaObj['type'];
    final String mediaDuration = mediaObj['duration'] != null
        ? '${formatDurationHms(mediaObj['duration'])}'
        : '';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () {
          setState(() {
            _navStack.add(
              NavNode(
                type: 'media',
                id: mediaUsageId,
                title: mediaTitle,
                parentId: folderId,
              ),
            );
          });
        },
        leading: Icon(
          mediaType == 'VIDEO'
              ? Icons.videocam
              : mediaType == 'AUDIO'
              ? Icons.audiotrack
              : mediaType == 'IMAGE'
              ? Icons.image
              : Icons.insert_drive_file,
          color: AppColors.primaryGreen,
        ),
        title: Text(mediaTitle, style: AppTypography.titleMedium),
        subtitle: Text(
          '$mediaType ${mediaDuration.isNotEmpty ? '- $mediaDuration' : ''}',
          style: AppTypography.bodySmall,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          tooltip: 'Delete Media',
          onPressed: () async {
            if (mediaUsageId.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invalid media usage ID. Cannot delete.'),
                ),
              );
              return;
            }

            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete Media'),
                content: const Text(
                  'Are you sure you want to delete this media?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              await _deleteMedia(mediaUsageId, folderId);
            }
          },
        ),
      ),
    );
  }
}
