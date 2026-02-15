import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:flutter/material.dart';
import 'package:dhiraj_ayu_academy/src/widgets/common_widgets.dart';
import 'package:dhiraj_ayu_academy/src/widgets/gallery_carousel.dart';
import 'package:dhiraj_ayu_academy/src/services/api_service.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppSpacing.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppColors.dart';

class AdminHomeTab extends StatefulWidget {
  const AdminHomeTab({super.key});

  @override
  State<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<AdminHomeTab> {
  final ApiService _api = ApiService();

  List<Map<String, dynamic>> _images = [];
  bool _isLoadingImages = false;
  bool _isUploadingImage = false;

  List<Map<String, dynamic>> _videos = [];
  bool _isLoadingVideos = false;
  bool _isUploadingVideo = false;

  @override
  void initState() {
    super.initState();
    _loadGallery();
    _loadVideoGallery();
  }

  Future<void> _loadGallery() async {
    setState(() => _isLoadingImages = true);
    try {
      final items = await _api.listGalleryMedia('IMAGE');
      if (mounted) {
        setState(() => _images = items);
      }
    } catch (e) {
      debugPrint('Failed to load images: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingImages = false);
      }
    }
  }

  Future<void> _loadVideoGallery() async {
    setState(() => _isLoadingVideos = true);
    try {
      final items = await _api.listGalleryMedia('VIDEO');
      if (mounted) {
        setState(() => _videos = items);
      }
    } catch (e) {
      debugPrint('Failed to load videos: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingVideos = false);
      }
    }
  }

  Future<void> _addImage() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        withData: false,
      );

      if (res == null || res.count == 0) return;

      final picked = res.files.first;
      if (picked.path == null) {
        _showSnackBar('Please pick a local file');
        return;
      }

      setState(() => _isUploadingImage = true);

      final file = File(picked.path!);
      final fileSize = await file.length();
      final mimeType =
          lookupMimeType(picked.path!) ?? 'application/octet-stream';

      final uploadResp = await _api.requestGalleryMediaUpload({
        'media': {
          'fileName': picked.name,
          'fileSize': fileSize,
          'mimeType': mimeType,
        },
      });

      final uploadUrl = uploadResp.data['uploadUrl'] as String;
      final fileKey = uploadResp.data['fileKey'] as String;

      final dio = Dio();
      final uploadResponse = await dio.put(
        uploadUrl,
        data: file.openRead(),
        options: Options(
          headers: {'Content-Type': mimeType, 'Content-Length': fileSize},
        ),
      );

      if (uploadResponse.statusCode == null ||
          uploadResponse.statusCode! < 200 ||
          uploadResponse.statusCode! >= 300) {
        throw Exception(
          'Upload failed with status: ${uploadResponse.statusCode}',
        );
      }

      await _api.createGalleryMediaAsset({
        'fileName': picked.name,
        'fileSize': fileSize,
        'mimeType': mimeType,
        'mediaPath': fileKey,
        'type': 'IMAGE',
      }, 'IMAGE');

      _showSnackBar('Image uploaded successfully');
      await _loadGallery();
    } catch (e) {
      debugPrint('Upload error: $e');
      _showSnackBar('Failed to upload image');
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _addVideo() async {
    final urlCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Gallery Video'),
        content: TextField(
          controller: urlCtrl,
          decoration: const InputDecoration(
            labelText: 'Video URL',
            hintText: 'Enter YouTube or video URL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final url = urlCtrl.text.trim();
    if (url.isEmpty) {
      _showSnackBar('Please enter a video URL');
      return;
    }

    setState(() => _isUploadingVideo = true);
    try {
      await _api.createGalleryMediaAsset({'url': url}, 'VIDEO');
      _showSnackBar('Video added successfully');
      await _loadVideoGallery();
    } catch (e) {
      debugPrint('Failed to add video: $e');
      _showSnackBar('Failed to add video');
    } finally {
      if (mounted) {
        setState(() => _isUploadingVideo = false);
      }
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_loadGallery(), _loadVideoGallery()]);
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _confirmDeleteGalleryItem(
    Map<String, dynamic> item,
    String type,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final assetId = item['id'].toString();
      await _api.deleteGalleryMedia(assetId, type);

      setState(() {
        if (type == 'IMAGE') {
          _images.removeWhere((i) => i['id'].toString() == assetId);
        } else {
          _videos.removeWhere((v) => v['id'].toString() == assetId);
        }
      });
      _showSnackBar('Item deleted');
    } catch (e) {
      debugPrint('Failed to delete gallery item: $e');
      _showSnackBar('Failed to delete item');
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _buildImageSection() {
    if (_isLoadingImages && _images.isEmpty) {
      return const SizedBox(
        height: 245,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isUploadingImage)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 4,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primaryGreen,
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ),
        GalleryCarousel(
          items: _images,
          height: 245,
          autoplay: true,
          mediaType: 'IMAGE',
          onItemLongPress: (item) => _confirmDeleteGalleryItem(item, 'IMAGE'),
        ),
      ],
    );
  }

  Widget _buildVideoSection() {
    if (_isLoadingVideos && _videos.isEmpty) {
      return const SizedBox(
        height: 250,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isUploadingVideo)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 4,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primaryGreen,
                ),
                backgroundColor: Colors.white.withOpacity(0.2),
              ),
            ),
          ),
        GalleryCarousel(
          items: _videos,
          height: 250,
          autoplay: true,
          mediaType: 'VIDEO',
          onItemLongPress: (item) => _confirmDeleteGalleryItem(item, 'VIDEO'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      strokeWidth: 0,
      displacement: 0,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
              child: ProfileHeader(),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Expanded(child: SectionHeader(title: 'Announcements')),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isUploadingImage ? null : _addImage,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Add Image'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: AppSpacing.screenPaddingHorizontal,
              child: _buildImageSection(),
            ),

            const SizedBox(height: AppSpacing.md),

            // Glimpses Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(child: SectionHeader(title: 'Glimpses')),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isUploadingVideo ? null : _addVideo,
                    icon: const Icon(Icons.video_call),
                    label: const Text('Add Video'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: AppSpacing.screenPaddingHorizontal,
              child: _buildVideoSection(),
            ),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
