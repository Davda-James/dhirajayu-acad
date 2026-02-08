import 'package:flutter/foundation.dart';
import 'package:dhiraj_ayu_academy/src/services/api_service.dart';

class MediaTokenCache {
  final Map<String, Map<String, dynamic>> _cache = {};

  Future<bool> ensureTokenForUsage(
    String usageId, {
    required String assetId,
    String? courseId,
    bool forceRefresh = false,
  }) async {
    final existing = _cache[usageId];

    // Fast checks: if we already have a token and not forcing refresh
    if (!forceRefresh && existing != null) {
      final fetchedAt = existing['fetched_at'] as String?;
      final tokenExp = existing['token_expires_at'] as String?;

      // Debounce: skip refresh if fetched within last 5s
      if (fetchedAt != null) {
        try {
          final last = DateTime.parse(fetchedAt);
          if (DateTime.now().difference(last) < const Duration(seconds: 5))
            return true;
        } catch (_) {}
      }

      // Not near expiry (30s buffer)
      if (tokenExp != null) {
        try {
          final exp = DateTime.parse(tokenExp);
          if (!DateTime.now().add(const Duration(seconds: 30)).isAfter(exp)) {
            return true;
          }
        } catch (_) {}
      }
    }

    try {
      final resp = await ApiService().getMediaAccessToken(
        assetId,
        courseId: (courseId != null && courseId.isNotEmpty) ? courseId : null,
      );
      final tokenExpires = resp['expires_in'] != null
          ? DateTime.now().add(Duration(seconds: resp['expires_in']))
          : null;
      _cache[usageId] = {
        'media_url': resp['media_url'],
        'worker_token': resp['worker_token'],
        'expires_in': resp['expires_in'],
        'token_expires_at': tokenExpires?.toIso8601String(),
        'fetched_at': DateTime.now().toIso8601String(),
      };
      return true;
    } catch (e) {
      debugPrint('MediaTokenCache.refresh FAILED for $usageId: $e');
      return false;
    }
  }

  Map<String, dynamic>? getDetails(String usageId) => _cache[usageId];

  void setDetails(String usageId, Map<String, dynamic> details) {
    _cache[usageId] = details;
  }

  void remove(String usageId) => _cache.remove(usageId);

  void clear() => _cache.clear();
}

// singleton instance for convenience
final MediaTokenCache mediaTokenCache = MediaTokenCache();
