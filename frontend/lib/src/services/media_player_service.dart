import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

class MediaPlayerService {
  /// Probe a media URL with a small-range GET to validate token and detect finalUri/status
  Future<int> probeMediaUrl(String url, {String? token}) async {
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
      return resp.statusCode ?? 0;
    } catch (e) {
      rethrow;
    }
  }

  /// Initialize an AudioPlayer and set source. Caller is responsible for disposing.
  Future<AudioPlayer> initAudioPlayer(
    String url, {
    String? token,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final player = AudioPlayer();
    final audioSource = (token != null && token.isNotEmpty)
        ? AudioSource.uri(
            Uri.parse(url),
            headers: {'Authorization': 'Bearer $token'},
          )
        : AudioSource.uri(Uri.parse(url));
    await player.setAudioSource(audioSource).timeout(timeout);
    return player;
  }

  /// Initialize a VideoPlayerController (caller must dispose it)
  Future<VideoPlayerController> initVideoController(
    String url, {
    String? token,
  }) async {
    final controller = (token != null && token.isNotEmpty)
        ? VideoPlayerController.network(
            url,
            httpHeaders: {'Authorization': 'Bearer $token'},
          )
        : VideoPlayerController.network(url);
    await controller.initialize();
    return controller;
  }

  /// Attach a generic listener to a video controller. `onChange` is invoked with
  /// (position, duration, isBuffering, hasError) whenever the controller state changes.
  void attachVideoListener(
    VideoPlayerController controller,
    void Function(Duration pos, Duration dur, bool isBuffering, bool hasError)
    onChange,
  ) {
    controller.addListener(() {
      try {
        final pos = controller.value.position;
        final dur = controller.value.duration;
        final isBuffering = controller.value.isBuffering;
        final hasError = controller.value.hasError;
        onChange(pos, dur, isBuffering, hasError);
      } catch (_) {}
    });
  }
}

final MediaPlayerService mediaPlayerService = MediaPlayerService();
