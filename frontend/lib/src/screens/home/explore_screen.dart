import 'package:flutter/material.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppColors.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppSpacing.dart';
import 'package:dhiraj_ayu_academy/src/widgets/common_widgets.dart';
import 'package:dhiraj_ayu_academy/src/services/api_service.dart';
import 'package:dhiraj_ayu_academy/src/widgets/gallery_carousel.dart';

/// Explore Screen
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.backgroundWhite,
            elevation: 0,
            title: const ProfileHeader(),
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),

                // Gallery images
                const SectionHeader(title: 'Announcements'),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: AppSpacing.screenPaddingHorizontal,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: ApiService().listGalleryMedia('IMAGE'),
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const SizedBox(
                          height: 250,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snap.hasError)
                        return const Text('Failed to load gallery');
                      final items = snap.data ?? [];
                      return GalleryCarousel(items: items, mediaType: 'IMAGE');
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Gallery videos (public)
                const SectionHeader(title: 'Glimpses'),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: AppSpacing.screenPaddingHorizontal,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: ApiService().listGalleryMedia('VIDEO'),
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const SizedBox(
                          height: 250,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snap.hasError)
                        return const Text('Failed to load videos');
                      final items = snap.data ?? [];
                      return GalleryCarousel(items: items, mediaType: 'VIDEO');
                    },
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
