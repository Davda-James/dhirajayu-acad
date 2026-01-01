import 'package:flutter/material.dart';
import 'package:dhiraj_ayu_academy/src/services/api_service.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppColors.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppTypography.dart';

class MediaDetailScreen extends StatefulWidget {
  final String mediaId;

  const MediaDetailScreen({Key? key, required this.mediaId}) : super(key: key);

  @override
  State<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends State<MediaDetailScreen> {
  String? mediaUrl;
  String? workerToken;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMediaDetails();
  }

  Future<void> _fetchMediaDetails() async {
    try {
      final response = await ApiService().getMediaAccessToken(widget.mediaId);
      setState(() {
        mediaUrl = response['media_url'];
        workerToken = response['worker_token'];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load media details';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Details', style: AppTypography.headlineMedium),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mediaUrl != null)
                  Expanded(
                    child: Center(
                      child: Text(
                        'Media content will be displayed here using mediaUrl: $mediaUrl',
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
