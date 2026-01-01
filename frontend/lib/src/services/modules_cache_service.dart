import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dhiraj_ayu_academy/src/services/api_service.dart';

/// Lightweight cache for module folders with ETag support.
class ModulesCacheService {
  static final ModulesCacheService _instance = ModulesCacheService._internal();
  factory ModulesCacheService() => _instance;
  ModulesCacheService._internal();

  final Map<String, List<Map<String, dynamic>>> _inMemory = {};

  String _etagKey(String key) => 'folders_etag_$key';
  String _cacheKey(String key) => 'folders_cache_$key';

  /// Fetch top-level folders for a module (uses /folders/children?moduleId=...)
  Future<List<Map<String, dynamic>>> fetchFolders(
    String moduleId, {
    bool force = false,
  }) async {
    final cacheKey = 'module_$moduleId';
    // Return in-memory cache if available and not forced
    if (!force && _inMemory.containsKey(cacheKey)) {
      return _inMemory[cacheKey]!;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedEtag = prefs.getString(_etagKey(cacheKey));
    try {
      final response = await ApiService().get(
        'folders/root/$moduleId',
        extraHeaders: storedEtag != null ? {'If-None-Match': storedEtag} : null,
      );

      // 304 Not Modified -> return cached payload
      if (response.statusCode == 304) {
        final cachedJson = prefs.getString(_cacheKey(cacheKey));
        if (cachedJson != null) {
          final List decoded = jsonDecode(cachedJson) as List;
          final List<Map<String, dynamic>> folders = decoded
              .cast<Map<String, dynamic>>();
          _inMemory[cacheKey] = folders;
          return folders;
        }
        // Fallback: no cached body despite 304, force full fetch
        return fetchFolders(moduleId, force: true);
      }

      // 200 -> update cache and return
      if (response.statusCode == 200) {
        final etag = response.headers.value('etag');
        final List<dynamic> foldersRaw = response.data['folders'] ?? [];
        final List<Map<String, dynamic>> folders = foldersRaw
            .cast<Map<String, dynamic>>();
        _inMemory[cacheKey] = folders;
        // persist
        await prefs.setString(_cacheKey(cacheKey), jsonEncode(folders));
        if (etag != null) await prefs.setString(_etagKey(cacheKey), etag);
        return folders;
      }

      // Other statuses: throw to be handled by caller
      throw Exception('Unexpected response status: ${response.statusCode}');
    } catch (e) {
      // On network/fetch error: fall back to persisted cache if present
      final cachedJson = prefs.getString(_cacheKey(cacheKey));
      if (cachedJson != null) {
        final List decoded = jsonDecode(cachedJson) as List;
        final List<Map<String, dynamic>> folders = decoded
            .cast<Map<String, dynamic>>();
        _inMemory[cacheKey] = folders;
        return folders;
      }
      rethrow;
    }
  }

  /// Fetch immediate children for a folder (uses /folders/children/:parentId)
  Future<List<Map<String, dynamic>>> fetchChildren(
    String parentId, {
    bool force = false,
  }) async {
    final cacheKey = 'parent_$parentId';
    if (!force && _inMemory.containsKey(cacheKey)) {
      return _inMemory[cacheKey]!;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedEtag = prefs.getString(_etagKey(cacheKey));

    try {
      final response = await ApiService().get(
        'folders/children/$parentId',
        extraHeaders: storedEtag != null ? {'If-None-Match': storedEtag} : null,
      );

      if (response.statusCode == 304) {
        final cachedJson = prefs.getString(_cacheKey(cacheKey));
        if (cachedJson != null) {
          final List decoded = jsonDecode(cachedJson) as List;
          final List<Map<String, dynamic>> folders = decoded
              .cast<Map<String, dynamic>>();
          _inMemory[cacheKey] = folders;
          return folders;
        }
        return fetchChildren(parentId, force: true);
      }

      if (response.statusCode == 200) {
        final etag = response.headers.value('etag');
        final List<dynamic> foldersRaw = response.data['folders'] ?? [];
        final List<Map<String, dynamic>> folders = foldersRaw
            .cast<Map<String, dynamic>>();
        _inMemory[cacheKey] = folders;
        await prefs.setString(_cacheKey(cacheKey), jsonEncode(folders));
        if (etag != null) await prefs.setString(_etagKey(cacheKey), etag);
        return folders;
      }

      throw Exception('Unexpected response status: ${response.statusCode}');
    } catch (e) {
      final cachedJson = prefs.getString(_cacheKey(cacheKey));
      if (cachedJson != null) {
        final List decoded = jsonDecode(cachedJson) as List;
        final List<Map<String, dynamic>> folders = decoded
            .cast<Map<String, dynamic>>();
        _inMemory[cacheKey] = folders;
        return folders;
      }
      rethrow;
    }
  }

  void invalidate(String moduleId) {
    _inMemory.remove(moduleId);
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_cacheKey(moduleId));
      prefs.remove(_etagKey(moduleId));
    });
  }

  void invalidateAll() {
    _inMemory.clear();
    SharedPreferences.getInstance().then((prefs) {
      for (final key in prefs.getKeys()) {
        if (key.startsWith('folders_cache_') ||
            key.startsWith('folders_etag_')) {
          prefs.remove(key);
        }
      }
    });
  }
}
