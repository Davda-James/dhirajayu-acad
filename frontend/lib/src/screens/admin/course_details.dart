import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:mime/mime.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../constants/AppColors.dart';
import '../../constants/AppTypography.dart';
import '../../services/api_service.dart';
import '../../services/media_token_cache.dart';
import '../../services/media_player_service.dart';
import '../../widgets/media_player_widget.dart';
import '../../widgets/add_media_sheet.dart';

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

    final future = ApiService().getMediaUsagesByFolder(folderId).then((
      response,
    ) {
      final usages = (response.data['usages'] as List)
          .cast<Map<String, dynamic>>();
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
  // Cached details for media usages (signed URL, token, etc.) keyed by usage ID
  final Map<String, Map<String, dynamic>> _mediaDetails = {};
  // Track transient initialization errors for media (usageId -> error message)
  final Map<String, String?> _mediaInitErrors = {};

  // Audio/video players state
  AudioPlayer? _audioPlayer;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  // Current audio URL and token for reuse checks
  String? _currentAudioUrl;
  String? _currentAudioToken;

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _videoInitialized = false;
  String? _currentPlayingUsageId;

  // Video init guards & playback preservation
  final Map<String, bool> _videoInitInFlight = {};
  final Map<String, Duration> _playbackPositions = {};
  static const Duration _videoInitTimeout = Duration(seconds: 15);

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  // For logging seek/position changes in video
  Duration _lastVideoLoggedPosition = Duration.zero;

  // Initialize audio player for a usage (smart reuse + headers)
  Future<void> _initAudioPlayer(
    String url,
    String usageId, {
    String? token,
  }) async {
    debugPrint(
      'audio:init requested usage=$usageId url=$url token=${token != null ? "provided" : "none"}',
    );

    final existingTs = _mediaDetails[usageId]?['token_expires_at'];
    final fetchedAt = _mediaDetails[usageId]?['fetched_at'];
    debugPrint(
      'audio:init: existing token_expires_at=$existingTs fetched_at=$fetchedAt for $usageId',
    );

    // Reuse existing player if same source and token
    if (_currentPlayingUsageId == usageId &&
        _audioPlayer != null &&
        _currentAudioUrl == url &&
        _currentAudioToken == token) {
      debugPrint('audio:init: reusing existing player for $usageId');
      _attachAudioListeners(usageId);
      return;
    }

    final preservedPosition = _audioPosition;

    // Dispose any existing audio-only resources when switching
    await _disposeAudioOnly();

    try {
      // Use shared service to create and initialize the audio player
      _audioPlayer = await mediaPlayerService.initAudioPlayer(
        url,
        token: token,
      );
    } on MissingPluginException catch (e) {
      debugPrint('audio:init: MissingPluginException: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio playback is not available in this build.'),
          ),
        );
      }
      return;
    } catch (e) {
      debugPrint('audio:init: AudioPlayer init error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio initialization failed')),
        );
      }
      return;
    }

    _currentPlayingUsageId = usageId;
    _currentAudioUrl = url;
    _currentAudioToken = token;
    _audioPosition = Duration.zero;
    _audioDuration = Duration.zero;

    _attachAudioListeners(usageId);

    try {
      // If the token is expired, refresh and re-create player with new token
      if (_isTokenExpired(usageId)) {
        debugPrint('audio:init: token expired for $usageId — refreshing first');
        final refreshed = await _refreshToken(usageId);
        if (refreshed) {
          token = _mediaDetails[usageId]?['worker_token'] as String?;
          _currentAudioToken = token;
          debugPrint('audio:init: token refreshed for $usageId');

          // Re-create player with updated token
          await _audioPlayer?.dispose();
          _audioPlayer = await mediaPlayerService.initAudioPlayer(
            url,
            token: token,
          );
          _attachAudioListeners(usageId);
        } else {
          debugPrint('audio:init: token refresh failed for $usageId');
        }
      }

      // Restore preserved position if needed
      if (preservedPosition > Duration.zero) {
        try {
          await _audioPlayer!.seek(preservedPosition);
          debugPrint(
            'audio:init: restored position for $usageId -> $preservedPosition',
          );
        } catch (e) {
          debugPrint('audio:init: failed to restore position for $usageId: $e');
        }
      }

      debugPrint('audio:init: initialized successfully for $usageId');
    } catch (e, st) {
      debugPrint('audio:init FAILED for $usageId: $e\n$st');
      _mediaInitErrors[usageId] = e.toString();
      if (mounted) setState(() {});
    }
  }

  // Attach listeners to audio player with debug logs
  void _attachAudioListeners(String usageId) {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _playerStateSub?.cancel();

    _durationSub = _audioPlayer!.durationStream.listen((d) {
      _audioDuration = d ?? Duration.zero;
      debugPrint('audio: duration for $usageId = $_audioDuration');
      if (mounted) setState(() {});
    });

    _positionSub = _audioPlayer!.positionStream.listen((p) {
      if ((p - _audioPosition).abs() > const Duration(seconds: 2)) {
        debugPrint(
          'audio: position jump for $usageId from $_audioPosition to $p',
        );
      }
      _audioPosition = p;
      if (mounted) setState(() {});
    });

    _playerStateSub = _audioPlayer!.playerStateStream.listen(
      (s) {
        debugPrint(
          'audio: playerState for $usageId = ${s.processingState} playing=${s.playing}',
        );
        if (s.processingState == ProcessingState.completed) {
          debugPrint('audio: completed $usageId');
        }
        if (mounted) setState(() {});
      },
      onError: (e) {
        debugPrint('audio: playerStateStream error for $usageId: $e');
      },
    );
  }

  // Dispose only audio controllers (used internally)
  Future<void> _disposeAudioOnly() async {
    try {
      await _positionSub?.cancel();
      await _durationSub?.cancel();
      await _playerStateSub?.cancel();
    } catch (_) {}
    _positionSub = null;
    _durationSub = null;
    _playerStateSub = null;

    try {
      await _audioPlayer?.dispose();
    } catch (e) {
      debugPrint('audio: dispose error: $e');
    }
    _audioPlayer = null;
    _currentAudioUrl = null;
    _currentAudioToken = null;
    _audioPosition = Duration.zero;
    _audioDuration = Duration.zero;
  }

  // Retry audio init: refresh token if expired or forced and preserve position
  Future<void> _retryAudioInit(
    String usageId, {
    bool forceRefresh = false,
  }) async {
    debugPrint('audio:retry requested for $usageId forceRefresh=$forceRefresh');
    final details = _mediaDetails[usageId];
    if (details == null) {
      debugPrint('audio:retry: no mediaDetails for $usageId');
      _mediaInitErrors[usageId] = 'No media details';
      if (mounted) setState(() {});
      return;
    }

    if (forceRefresh || _isTokenExpired(usageId)) {
      final ok = await _refreshToken(usageId);
      debugPrint('audio:retry: refresh result for $usageId = $ok');
      if (!ok) {
        _mediaInitErrors[usageId] = 'Token refresh failed';
        if (mounted) setState(() {});
        return;
      }
    }

    final url = _mediaDetails[usageId]!['media_url'] as String?;
    final token = _mediaDetails[usageId]!['worker_token'] as String?;
    if (url == null) {
      _mediaInitErrors[usageId] = 'Media URL missing';
      if (mounted) setState(() {});
      return;
    }

    final pos = _audioPlayer?.position ?? _audioPosition;
    await _initAudioPlayer(url, usageId, token: token);
    if (_audioPlayer != null && pos > Duration.zero) {
      try {
        await _audioPlayer!.seek(pos);
        debugPrint('audio:retry: seeked to $pos for $usageId');
      } catch (e) {
        debugPrint('audio:retry: seek failed for $usageId: $e');
      }
    }
    _mediaInitErrors.remove(usageId);
    if (mounted) setState(() {});
  }

  // Initialize video player for a usage
  Future<void> _initVideoPlayer(
    String url,
    String usageId, {
    String? token,
  }) async {
    // Prevent concurrent inits for same usage
    if (_videoInitInFlight[usageId] == true) {
      return;
    }
    _videoInitInFlight[usageId] = true;

    // If already initialized and healthy, reuse
    try {
      if (_currentPlayingUsageId == usageId &&
          _videoController != null &&
          _videoController!.value.isInitialized &&
          !_videoController!.value.hasError) {
        if (_chewieController == null) {
          _chewieController = ChewieController(
            videoPlayerController: _videoController!,
            autoPlay: false,
            looping: false,
            showControls: true,
          );
        }
        _videoInitInFlight.remove(usageId);
        return;
      }

      // preserve position if switching
      Duration? preservedPosition = _playbackPositions[usageId];

      // Dispose previous only if switching to different usage
      await _disposeMediaControllers();
      _mediaInitErrors.remove(usageId);
      _currentPlayingUsageId = usageId;

      // Preflight probe to verify the media URL and token (small-range GET)
      try {
        final probeStatus = await _probeMediaUrl(url, token: token);
        if (probeStatus == 401) {
          // token likely invalid/expired: try refresh and re-probe
          final refreshed = await _refreshToken(usageId);
          if (refreshed) {
            final newToken = _mediaDetails[usageId]?['worker_token'] as String?;
            final newUrl =
                _mediaDetails[usageId]?['media_url'] as String? ?? url;
            final probe2 = await _probeMediaUrl(newUrl, token: newToken);
            if (probe2 >= 400) {
              _mediaInitErrors[usageId] = 'Probe failed with status $probe2';
              if (mounted) setState(() {});
              _videoInitInFlight.remove(usageId);
              return;
            }
            // swap to new values
            url = newUrl;
            token = newToken;
          } else {
            _mediaInitErrors[usageId] = 'Token refresh failed during probe';
            if (mounted) setState(() {});
            _videoInitInFlight.remove(usageId);
            return;
          }
        } else if (probeStatus >= 400) {
          _mediaInitErrors[usageId] = 'Probe failed with status $probeStatus';
          if (mounted) setState(() {});
          _videoInitInFlight.remove(usageId);
          return;
        }
      } catch (e) {
        _mediaInitErrors[usageId] = 'Probe error: $e';
        if (mounted) setState(() {});
        _videoInitInFlight.remove(usageId);
        return;
      }

      final initFuture = () async {
        try {
          // Use shared MediaPlayerService to initialize controller (handles headers)
          _videoController = await mediaPlayerService.initVideoController(
            url,
            token: token,
          );

          // attach listener via the shared helper but keep UI-side handling here
          mediaPlayerService.attachVideoListener(_videoController!, (
            pos,
            dur,
            isBuffering,
            hasError,
          ) {
            try {
              if ((pos - _lastVideoLoggedPosition).inSeconds.abs() > 2 ||
                  isBuffering ||
                  hasError) {
                debugPrint(
                  'videoController.listener: usage=$usageId pos=$pos dur=$dur isBuffering=$isBuffering hasError=$hasError',
                );
                _lastVideoLoggedPosition = pos;
              }

              // Detect playback completion
              if (!isBuffering &&
                  !hasError &&
                  dur > Duration.zero &&
                  pos >= dur - const Duration(milliseconds: 500)) {
                debugPrint(
                  'videoController.listener: playback complete detected for usage=$usageId pos=$pos dur=$dur',
                );
              }

              // If an error is observed by the controller, kick off automatic retry flow
              if (hasError) {
                debugPrint(
                  'videoController.listener: detected hasError for usage=$usageId; scheduling automatic retry',
                );
                _handleVideoPlaybackError(usageId);
              }
            } catch (e) {
              debugPrint(
                'videoController.listener: exception for usage=$usageId: $e',
              );
            }
          });

          // create chewie controller
          _chewieController = ChewieController(
            videoPlayerController: _videoController!,
            autoPlay: false,
            looping: false,
            showControls: true,
            allowFullScreen: true,
            allowedScreenSleep: false,
            materialProgressColors: ChewieProgressColors(
              playedColor: AppColors.primaryGreen,
              handleColor: AppColors.primaryGreen,
            ),
          );

          // restore position if any
          if (preservedPosition != null && _videoController != null) {
            try {
              debugPrint(
                'initVideoPlayer: restoring position to $preservedPosition for $usageId',
              );
              await _videoController!.seekTo(preservedPosition);
            } catch (e) {
              debugPrint(
                'initVideoPlayer: failed to restore position for $usageId: $e',
              );
            }
          }

          _videoInitialized = true;
        } catch (e, st) {
          debugPrint('initVideoPlayer (inner) FAILED for $usageId: $e\n$st');
          rethrow;
        }
      }();

      // apply timeout
      await initFuture.timeout(_videoInitTimeout);
      _mediaInitErrors.remove(usageId);
      if (mounted) setState(() {});
    } on TimeoutException catch (_) {
      final msg = 'Video initialization timeout';
      _mediaInitErrors[usageId] = msg;
      if (mounted) setState(() {});
    } catch (e, _) {
      final msg = e.toString();
      _mediaInitErrors[usageId] = msg;
      if (mounted) setState(() {});
    } finally {
      _videoInitInFlight.remove(usageId);
    }
  }

  Future<void> _disposeMediaControllers() async {
    // preserve playback pos for current usage before disposing
    if (_videoController != null && _currentPlayingUsageId != null) {
      try {
        final pos = _videoController!.value.position;
        _playbackPositions[_currentPlayingUsageId!] = pos;
      } catch (e) {
        debugPrint('_disposeMediaControllers: failed to read position: $e');
      }
    }
    try {
      await _positionSub?.cancel();
    } catch (_) {}
    try {
      await _durationSub?.cancel();
    } catch (_) {}
    try {
      await _playerStateSub?.cancel();
    } catch (_) {}
    _positionSub = null;
    _durationSub = null;
    _playerStateSub = null;

    try {
      if (_audioPlayer != null) {
        try {
          await _audioPlayer!.stop();
        } catch (_) {}
        try {
          await _audioPlayer!.dispose();
        } catch (_) {}
        _audioPlayer = null;
      }
    } catch (_) {}
    try {
      if (_chewieController != null) {
        try {
          _chewieController!.pause();
        } catch (_) {}
        try {
          _chewieController!.dispose();
        } catch (_) {}
        _chewieController = null;
      }
    } catch (_) {}
    try {
      if (_videoController != null) {
        await _videoController!.pause();
        await _videoController!.dispose();
        _videoController = null;
        _videoInitialized = false;
      }
    } catch (e) {
      debugPrint(
        '_disposeMediaControllers: error while disposing video controller: $e',
      );
    }
    _audioDuration = Duration.zero;
    _audioPosition = Duration.zero;
    _currentPlayingUsageId = null;
  }

  // --- Token and retry helpers ---
  bool _isTokenExpired(String usageId) {
    final details = _mediaDetails[usageId];
    if (details == null) {
      return true;
    }
    final ts = details['token_expires_at'] as String?;
    if (ts == null) {
      return true;
    }
    try {
      final exp = DateTime.parse(ts);
      final now = DateTime.now();
      // Consider token expired if within 30s of expiry
      final isExpired = now.add(const Duration(seconds: 30)).isAfter(exp);
      return isExpired;
    } catch (_) {
      debugPrint(
        '_isTokenExpired: parse error for token_expires_at=$ts -> expired',
      );
      return true;
    }
  }

  Future<bool> _refreshToken(String usageId) async {
    // Delegate token refresh to centralized cache/service
    final assetId = _getAssetIdForUsage(usageId);
    if (assetId == null) {
      debugPrint('_refreshToken: assetId not found for $usageId');
      return false;
    }

    final ok = await mediaTokenCache.ensureTokenForUsage(
      usageId,
      assetId: assetId,
    );
    if (!ok) return false;

    final details = mediaTokenCache.getDetails(usageId);
    if (details != null) {
      _mediaDetails[usageId] = {...?_mediaDetails[usageId], ...details};
    }

    debugPrint('_refreshToken: delegated to MediaTokenCache for $usageId');
    return true;
  }

  String? _getAssetIdForUsage(String usageId) {
    for (final entry in _mediaByFolder.entries) {
      for (final u in entry.value) {
        if (u['id'] == usageId) {
          return (u['media_asset']?['id'] ?? u['media_id'])?.toString();
        }
      }
    }
    return null;
  }

  // Probe a media URL with a small-range GET to validate token and range handling
  Future<int> _probeMediaUrl(String url, {String? token}) async {
    try {
      final dio = Dio();
      final headers = <String, dynamic>{
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        'Range': 'bytes=0-1023',
      };
      final resp = await dio.get(
        url,
        options: Options(headers: headers, validateStatus: (_) => true),
      );
      try {
        // Log final URI after following redirects (helps detect http://127.0.0.1 redirects)
        final finalUri = (resp.realUri.toString());
        debugPrint(
          '_probeMediaUrl: status=${resp.statusCode} finalUri=$finalUri for url=$url',
        );
      } catch (e) {
        debugPrint(
          '_probeMediaUrl: status=${resp.statusCode} (failed to read finalUri): $e',
        );
      }
      return resp.statusCode ?? 0;
    } catch (e) {
      debugPrint('_probeMediaUrl: exception for url=$url -> $e');
      rethrow;
    }
  }

  final Map<String, int> _videoRetryCounts = {};
  static const int _maxVideoRetries = 3;

  Future<void> _handleVideoPlaybackError(String usageId) async {
    final count = _videoRetryCounts[usageId] ?? 0;
    if (count >= _maxVideoRetries) {
      _mediaInitErrors[usageId] = 'Playback error: exceeded automatic retries';
      if (mounted) setState(() {});
      return;
    }

    _videoRetryCounts[usageId] = count + 1;

    // If token expired, refresh first
    if (_isTokenExpired(usageId)) {
      final refreshed = await _refreshToken(usageId);
      if (!refreshed) {
        _mediaInitErrors[usageId] = 'Token refresh failed';
        if (mounted) setState(() {});
        return;
      }
    }

    // Attempt to re-init (keeps playback position)
    await _retryVideoInit(usageId);
  }

  Future<void> _retryVideoInit(String usageId) async {
    final details = _mediaDetails[usageId];
    if (details == null) {
      _mediaInitErrors[usageId] = 'No cached media details';
      if (mounted) setState(() {});
      return;
    }

    _mediaInitErrors.remove(usageId);
    if (mounted) setState(() {});

    final tokenExpired = _isTokenExpired(usageId);
    if (tokenExpired) {
      final refreshed = await _refreshToken(usageId);
      if (!refreshed) {
        _mediaInitErrors[usageId] = 'Token refresh failed';
        if (mounted) setState(() {});
        return;
      }
    }

    final url = _mediaDetails[usageId]!['media_url'] as String?;
    final token = _mediaDetails[usageId]!['worker_token'] as String?;
    if (url == null) {
      _mediaInitErrors[usageId] = 'Media URL missing';
      if (mounted) setState(() {});
      return;
    }

    Duration? pos;
    try {
      pos = _videoController?.value.position;
    } catch (_) {
      pos = _playbackPositions[usageId];
    }

    try {
      await _initVideoPlayer(url, usageId, token: token);
      if (_videoController != null && pos != null) {
        try {
          await _videoController!.seekTo(pos);
        } catch (e) {
          debugPrint('_retryVideoInit: seek failed for $usageId: $e');
        }
      }
      _mediaInitErrors.remove(usageId);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('_retryVideoInit: init failed for $usageId: $e');
      _mediaInitErrors[usageId] = e.toString();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _disposeMediaControllers();
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
        content: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Module Name'),
            ),
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
    // Use a bottom sheet (isScrollControlled) so the sheet moves above the
    // keyboard and the TextField remains visible on small screens / web.
    final controller = TextEditingController();

    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width < 600
                      ? MediaQuery.of(context).size.width
                      : MediaQuery.of(context).size.width * 0.6,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Add Folder',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12.0),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Folder Name',
                          border: UnderlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8.0),
                          ElevatedButton(
                            onPressed: () => Navigator.of(
                              context,
                            ).pop(controller.text.trim()),
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    // Do not explicitly dispose the controller here; the sheet's TextField may
    // still have listeners during the pop lifecycle causing assertion failures
    // like "_dependents.isEmpty is not true". Let GC clean it up after route
    // is fully removed.

    if (name != null && name.isNotEmpty) {
      await _addFolder(moduleId, name, parentId: parentId);
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

      Uint8List fileBytes;
      if (picked.bytes != null) {
        fileBytes = picked.bytes!;
      } else if (picked.path != null) {
        fileBytes = await File(picked.path!).readAsBytes();
      } else {
        throw Exception('Selected file has no bytes or path');
      }

      final dio = Dio();
      final uploadHeaders = {'Content-Type': mimeType};

      setState(() {
        _isAdding = true;
      });

      final uploadResp = await dio.put(
        uploadUrl,
        data: fileBytes,
        options: Options(headers: uploadHeaders),
        onSendProgress: (_, __) {},
      );

      if (uploadResp.statusCode == null ||
          uploadResp.statusCode! < 200 ||
          uploadResp.statusCode! >= 300) {
        throw Exception('Upload failed for ${picked.name}');
      }

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

  Future<void> _addMediaToFolder(
    String folderId,
    Map<String, dynamic> media,
  ) async {
    setState(() {
      if (_mediaByFolder.containsKey(folderId)) {
        _mediaByFolder[folderId]!.add(media);
      } else {
        _mediaByFolder[folderId] = [media];
      }
    });
  }

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
                _buildBreadcrumb(),
                const SizedBox(height: 8),
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
      floatingActionButton: _navStack.isEmpty
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
                  onPressed: _isAdding ? null : _showAddModuleDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Module'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBreadcrumb() {
    if (_navStack.isEmpty) {
      return Text('Modules & Content', style: AppTypography.titleMedium);
    }
    List<Widget> crumbs = [];
    crumbs.add(
      GestureDetector(
        onTap: () {
          setState(() {
            _navStack.clear();
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
        final details = _mediaDetails[node.id];
        return FutureBuilder<void>(
          future: details == null
              ? () async {
                  // Try to find assetId from cached media usages if details missing
                  String? foundAssetId;
                  _mediaByFolder.forEach((folderId, usages) {
                    for (final u in usages) {
                      if (u['id'] == node.id) {
                        foundAssetId =
                            (u['media_asset']?['id'] ?? u['media_id'])
                                ?.toString();
                        break;
                      }
                    }
                  });
                  if (foundAssetId != null) {
                    final resp = await ApiService().getMediaAccessToken(
                      foundAssetId!,
                    );
                    final tokenExpires = resp['expires_in'] != null
                        ? DateTime.now().add(
                            Duration(seconds: resp['expires_in']),
                          )
                        : null;
                    _mediaDetails[node.id] = {
                      'media_url': resp['media_url'],
                      'worker_token': resp['worker_token'],
                      'expires_in': resp['expires_in'],
                      'token_expires_at': tokenExpires?.toIso8601String(),
                      'fetched_at': DateTime.now().toIso8601String(),
                      'title': node.title,
                    };
                  }
                }()
              : null,
          builder: (context, snap) {
            final d = _mediaDetails[node.id];
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (d == null) {
              return Center(child: Text('Media details not available'));
            }

            // Player initialization is now handled by MediaPlayerWidget for both AUDIO and VIDEO.
            // The widget will probe/init and handle token refresh/retries as needed.
            // (kept here for reference; initialization removed from screen-level.)

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d['title'] ?? node.title,
                    style: AppTypography.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Type: ${d['type'] ?? ''}',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  if (d['duration'] != null)
                    Text(
                      'Duration: ${d['duration']} seconds',
                      style: AppTypography.bodyMedium,
                    ),
                  const SizedBox(height: 12),

                  // Player UI
                  if (d['media_url'] != null && d['type'] == 'AUDIO') ...[
                    MediaPlayerWidget(
                      usageId: node.id,
                      assetId: (d['media_asset']?['id'] ?? d['media_id'])
                          ?.toString(),
                      type: 'AUDIO',
                      initialDetails: d,
                    ),
                  ] else if (d['media_url'] != null &&
                      d['type'] == 'VIDEO') ...[
                    MediaPlayerWidget(
                      usageId: node.id,
                      assetId: (d['media_asset']?['id'] ?? d['media_id'])
                          ?.toString(),
                      type: 'VIDEO',
                      initialDetails: d,
                    ),

                    const SizedBox(height: 12),
                    if (d['media_url'] != null)
                      SelectableText(
                        d['media_url'] ?? '',
                        style: AppTypography.bodySmall,
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: d['media_url'] == null
                          ? null
                          : () {
                              Clipboard.setData(
                                ClipboardData(text: d['media_url']),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Media URL copied'),
                                ),
                              );
                            },
                      child: const Text('Copy media URL'),
                    ),
                  ],
                ],
              ),
            );
          },
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
    // Prefer usage ID for delete, asset ID for playback
    final String? usageId = mediaObj['usageId'] as String?;
    final String? assetId = mediaObj['assetId'] as String?;
    final String mediaUsageId = usageId ?? '';
    final String mediaAssetId = assetId ?? '';

    final String mediaTitle =
        mediaObj['title'] ?? mediaObj['fileName'] ?? 'Unknown Media';
    final String mediaType = mediaObj['type'] ?? 'Unknown';
    final String mediaDuration = mediaObj['duration'] != null
        ? 'Duration: ${mediaObj['duration']} seconds'
        : '';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () async {
          if (mediaAssetId.isNotEmpty) {
            try {
              final resp = await ApiService().getMediaAccessToken(mediaAssetId);
              _mediaDetails[mediaUsageId] = {
                'media_url': resp['media_url'],
                'worker_token': resp['worker_token'],
                'expires_in': resp['expires_in'],
                'token_expires_at': resp['expires_in'] != null
                    ? DateTime.now()
                          .add(Duration(seconds: resp['expires_in']))
                          .toIso8601String()
                    : null,
                'fetched_at': DateTime.now().toIso8601String(),
                'title': mediaTitle,
                'type': mediaType,
                'duration': mediaObj['duration'],
              };
            } catch (e) {}
          }
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
