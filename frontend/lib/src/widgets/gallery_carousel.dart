import 'package:flutter/material.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppSpacing.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppColors.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GalleryCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final double height;
  final bool autoplay;
  final String mediaType;
  final void Function(Map<String, dynamic> item)? onItemLongPress;

  const GalleryCarousel({
    Key? key,
    required this.items,
    this.height = 250,
    this.autoplay = true,
    this.mediaType = 'IMAGE',
    this.onItemLongPress,
  }) : super(key: key);

  @override
  State<GalleryCarousel> createState() => _GalleryCarouselState();
}

class _GalleryCarouselState extends State<GalleryCarousel> {
  int _currentPage = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  YoutubePlayerController? _activeController;
  String? _playingVideoId;

  @override
  void dispose() {
    _activeController?.dispose();
    super.dispose();
  }

  void _playVideo(String id, String url) {
    final ytId = YoutubePlayer.convertUrlToId(url);
    if (ytId == null) return;

    if (_playingVideoId == id && _activeController != null) {
      _activeController!.pause();
      setState(() {
        _playingVideoId = null;
      });
      return;
    }

    _activeController?.dispose();

    try {
      final newController = YoutubePlayerController(
        initialVideoId: ytId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          disableDragSeek: true,
          showLiveFullscreenButton: false,
        ),
      );

      setState(() {
        _activeController = newController;
        _playingVideoId = id;
      });
    } catch (e) {
      debugPrint('Failed to create YouTube controller: $e');
    }
  }

  void _stopVideo() {
    if (_activeController != null) {
      _activeController!.pause();
      _activeController!.seekTo(const Duration(seconds: 0));
    }

    setState(() {
      _playingVideoId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text('No items', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final isVideo = widget.mediaType.toUpperCase() == 'VIDEO';
    final isAnyVideoPlaying = _playingVideoId != null;

    return Column(
      children: [
        CarouselSlider(
          carouselController: _carouselController,
          options: CarouselOptions(
            height: widget.height,
            autoPlay:
                widget.autoplay &&
                widget.items.length > 1 &&
                !isAnyVideoPlaying,
            enableInfiniteScroll: widget.items.length > 1,
            autoPlayInterval: const Duration(seconds: 4),
            autoPlayAnimationDuration: const Duration(milliseconds: 600),
            autoPlayCurve: Curves.easeInOut,
            viewportFraction: 1,
            enlargeCenterPage: false,
            onPageChanged: (index, reason) {
              setState(() => _currentPage = index);
              // Stop video when manually swiping
              if (reason == CarouselPageChangedReason.manual) {
                _stopVideo();
              }
            },
          ),
          items: widget.items.map((item) {
            final String url = item['url'] as String;
            final String id = item['id'].toString();
            final isPlaying = _playingVideoId == id;

            return Container(
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: GestureDetector(
                onLongPress: widget.onItemLongPress != null
                    ? () => widget.onItemLongPress!(item)
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: isVideo
                      ? _buildVideoItem(id, url, isPlaying)
                      : _buildImageItem(url),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Carousel indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.items.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 12 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? AppColors.primaryGreen
                    : AppColors.shadowLight,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageItem(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      progressIndicatorBuilder: (context, child, loadingProgress) {
        return const Center(child: CircularProgressIndicator());
      },
      errorWidget: (context, error, stackTrace) {
        return const Center(
          child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
        );
      },
    );
  }

  Widget _buildVideoItem(String id, String url, bool isPlaying) {
    final ytId = YoutubePlayer.convertUrlToId(url);

    if (ytId == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('Invalid YouTube URL', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (isPlaying && _activeController != null) {
      return YoutubePlayer(
        controller: _activeController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppColors.primaryGreen,
        onReady: () {
          debugPrint('YouTube player ready for video: $id');
        },
        onEnded: (metadata) {
          _stopVideo();
        },
      );
    }

    final thumbnailUrl = 'https://img.youtube.com/vi/$ytId/hqdefault.jpg';

    return GestureDetector(
      onTap: () => _playVideo(id, url),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: thumbnailUrl,
            fit: BoxFit.cover,
            progressIndicatorBuilder: (context, child, loadingProgress) {
              return const Center(child: CircularProgressIndicator());
            },
            errorWidget: (context, error, stackTrace) {
              return const Center(
                child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
              );
            },
          ),
          // Play button overlay
          Container(
            color: Colors.black26,
            child: const Center(
              child: Icon(
                Icons.play_circle_fill,
                size: 64,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
