import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'dart:math' as math;
import 'package:dhiraj_ayu_academy/src/services/media_player_service.dart';
import 'package:dhiraj_ayu_academy/src/services/media_token_cache.dart';

class MediaPlayerWidget extends StatefulWidget {
  final String usageId;
  final String? assetId;
  final String type; // 'AUDIO' or 'VIDEO'
  final Map<String, dynamic>? initialDetails;

  const MediaPlayerWidget({
    Key? key,
    required this.usageId,
    required this.type,
    this.assetId,
    this.initialDetails,
  }) : super(key: key);

  @override
  State<MediaPlayerWidget> createState() => _MediaPlayerWidgetState();
}

class _MediaPlayerWidgetState extends State<MediaPlayerWidget> {
  AudioPlayer? _audioPlayer;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _error;
  bool _loading = false;

  Map<String, dynamic>? _details;

  @override
  void initState() {
    super.initState();
    _details = widget.initialDetails;
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);

    // Ensure we have token/details either from initial or by fetching
    if (_details == null) {
      final assetId = widget.assetId;
      if (assetId != null) {
        final ok = await mediaTokenCache.ensureTokenForUsage(
          widget.usageId,
          assetId: assetId,
        );
        if (ok) _details = mediaTokenCache.getDetails(widget.usageId);
      }
    }

    if (_details == null) {
      setState(() {
        _error = 'Media details not available';
        _loading = false;
      });
      return;
    }

    final url = _details!['media_url'] as String?;
    final token = _details!['worker_token'] as String?;
    if (url == null) {
      setState(() {
        _error = 'Media URL missing';
        _loading = false;
      });
      return;
    }

    try {
      if (widget.type == 'AUDIO') {
        _audioPlayer = await mediaPlayerService.initAudioPlayer(
          url,
          token: token,
        );
        _attachAudioListeners();
      } else {
        _videoController = await mediaPlayerService.initVideoController(
          url,
          token: token,
        );
        mediaPlayerService.attachVideoListener(_videoController!, (
          pos,
          dur,
          isBuffering,
          hasError,
        ) {
          setState(() {
            _position = pos;
            _duration = dur;
          });
          if (hasError) {
            _handleError('Playback error');
          }
        });
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: false,
          looping: false,
          showControls: true,
        );
      }
    } catch (e) {
      _handleError(e.toString());
    }

    setState(() => _loading = false);
  }

  void _handleError(String msg) {
    setState(() {
      _error = msg;
    });
  }

  void _attachAudioListeners() {
    _audioPlayer?.durationStream.listen((d) {
      setState(() => _duration = d ?? Duration.zero);
    });
    _audioPlayer?.positionStream.listen((p) {
      setState(() => _position = p);
    });
    _audioPlayer?.playerStateStream.listen(
      (s) {
        if (s.processingState == ProcessingState.completed) {
          // nothing special
        }
      },
      onError: (e) {
        _handleError(e.toString());
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _retry({bool forceRefresh = false}) async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      if (forceRefresh && widget.assetId != null) {
        await mediaTokenCache.ensureTokenForUsage(
          widget.usageId,
          assetId: widget.assetId,
          forceRefresh: true,
        );
        _details = mediaTokenCache.getDetails(widget.usageId);
      }
      await _disposePlayers();
      await _init();
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _disposePlayers() async {
    try {
      await _audioPlayer?.dispose();
    } catch (_) {}
    _audioPlayer = null;

    try {
      await _chewieController?.pause();
      _chewieController?.dispose();
    } catch (_) {}
    _chewieController = null;

    try {
      await _videoController?.pause();
      await _videoController?.dispose();
    } catch (_) {}
    _videoController = null;
  }

  @override
  void dispose() {
    _disposePlayers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    if (_error != null) {
      return SizedBox(
        height: 160,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _retry(forceRefresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (widget.type == 'AUDIO') {
      return SizedBox(
        height: 120,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    _audioPlayer == null || !_audioPlayer!.playing
                        ? Icons.play_arrow
                        : Icons.pause,
                  ),
                  onPressed: () async {
                    if (_audioPlayer == null) return;
                    if (_audioPlayer!.playing)
                      await _audioPlayer!.pause();
                    else
                      await _audioPlayer!.play();
                    setState(() {});
                  },
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final maxSeconds = math.max(
                        1.0,
                        _duration.inSeconds.toDouble(),
                      );
                      final valueSeconds = _position.inSeconds.toDouble().clamp(
                        0.0,
                        maxSeconds,
                      );
                      return Slider(
                        min: 0.0,
                        max: maxSeconds,
                        value: valueSeconds,
                        onChanged: (v) {
                          final pos = Duration(seconds: v.toInt());
                          if (_audioPlayer != null) {
                            _audioPlayer!.seek(pos);
                          }
                          setState(() => _position = pos);
                        },
                      );
                    },
                  ),
                ),
                Text(_formatDuration(_position)),
              ],
            ),
          ],
        ),
      );
    }

    // Video UI
    final height = (MediaQuery.of(context).size.width - 32.0) / (16 / 9);
    return SizedBox(
      height: height.clamp(120.0, 360.0),
      child: _chewieController != null
          ? Chewie(controller: _chewieController!)
          : const SizedBox.shrink(),
    );
  }
}
