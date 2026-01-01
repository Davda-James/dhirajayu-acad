import 'package:flutter/material.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppColors.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppSpacing.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppTypography.dart';
import 'package:dhiraj_ayu_academy/src/services/api_service.dart';
import 'package:dhiraj_ayu_academy/src/services/modules_cache_service.dart';
import 'package:dhiraj_ayu_academy/src/widgets/media_player_widget.dart';

class ModuleContentScreen extends StatefulWidget {
  final String moduleId;
  final String moduleTitle;

  const ModuleContentScreen({
    super.key,
    required this.moduleId,
    required this.moduleTitle,
  });

  @override
  State<ModuleContentScreen> createState() => _ModuleContentScreenState();
}

class _ModuleContentScreenState extends State<ModuleContentScreen> {
  bool _isLoading = true;
  List<dynamic> _folders = [];

  @override
  void initState() {
    super.initState();
    _loadModuleContent();
  }

  Future<void> _loadModuleContent({bool force = false}) async {
    setState(() => _isLoading = true);
    try {
      final folders = await ModulesCacheService().fetchFolders(
        widget.moduleId,
        force: force,
      );
      setState(() {
        _folders = folders;
        _isLoading = false;
      });
    } catch (e) {
      try {
        final foldersResp = await ApiService().get(
          'folders/children',
          queryParameters: {'moduleId': widget.moduleId},
        );
        setState(() {
          _folders = foldersResp.data['folders'] ?? [];
          _isLoading = false;
        });
      } catch (e) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildFolderList(List<dynamic> folders) {
    if (folders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: Text('No folders')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: folders.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final f = folders[index];
        return ListTile(
          leading: const Icon(Icons.folder_open),
          title: Text(f['title'] ?? '', style: AppTypography.bodyMedium),
          subtitle: Text('${f['mediaCount'] ?? 0} items'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FolderContentScreen(
                  folderId: f['id'],
                  folderTitle: f['title'],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.moduleTitle),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadModuleContent(force: true),
              child: ListView(
                padding: AppSpacing.screenPaddingHorizontal,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  Text('Folders', style: AppTypography.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  _buildFolderList(_folders),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
    );
  }
}

class FolderContentScreen extends StatefulWidget {
  final String folderId;
  final String folderTitle;
  const FolderContentScreen({
    super.key,
    required this.folderId,
    required this.folderTitle,
  });

  @override
  State<FolderContentScreen> createState() => _FolderContentScreenState();
}

class _FolderContentScreenState extends State<FolderContentScreen> {
  bool _isLoading = true;
  List<dynamic> _usages = [];
  List<dynamic> _children = [];

  @override
  void initState() {
    super.initState();
    _loadFolder();
  }

  Future<void> _loadFolder() async {
    setState(() => _isLoading = true);
    try {
      final usagesResp = await ApiService().get(
        'media-usages/folder/${widget.folderId}',
      );
      final children = await ModulesCacheService().fetchChildren(
        widget.folderId,
      );
      setState(() {
        _usages = usagesResp.data['usages'] ?? [];
        _children = children;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.folderTitle),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: AppSpacing.screenPaddingAll,
              children: [
                if (_children.isNotEmpty) ...[
                  Text('Subfolders', style: AppTypography.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  ..._children.map(
                    (f) => ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(f['title'] ?? ''),
                      subtitle: Text('${f['mediaCount'] ?? 0} items'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FolderContentScreen(
                              folderId: f['id'],
                              folderTitle: f['title'],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                Text('Media', style: AppTypography.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                if (_usages.isEmpty) const Text('No media in this folder'),
                ..._usages.map((u) {
                  final asset = u['media_asset'] ?? {};
                  final String usageId = (u['id'] ?? '') as String;
                  final String assetId = (asset['id'] ?? '') as String;
                  final String mediaType =
                      (u['type'] ?? asset['type'] ?? 'DOCUMENT') as String;
                  final String title =
                      u['title'] ?? asset['file_name'] ?? 'Untitled';
                  final String subtitle =
                      u['description'] ??
                      (u['duration'] != null
                          ? 'Duration: ${u['duration']}s'
                          : '');

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
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
                      title: Text(title),
                      subtitle: Text(subtitle),
                      trailing: const Icon(
                        Icons.play_arrow,
                        color: AppColors.primaryGreen,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                leading: IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                title: Text(title),
                                backgroundColor: AppColors.primaryGreen,
                              ),
                              body: Padding(
                                padding: AppSpacing.screenPaddingAll,
                                child: Center(
                                  child: MediaPlayerWidget(
                                    usageId: usageId,
                                    assetId: assetId.isNotEmpty
                                        ? assetId
                                        : null,
                                    type: mediaType,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
              ],
            ),
    );
  }
}
