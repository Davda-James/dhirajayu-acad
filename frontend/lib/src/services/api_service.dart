import 'package:dio/dio.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppConstants.dart';
import 'package:dhiraj_ayu_academy/src/services/auth_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: '${AppConstants.apiBaseUrl}/${AppConstants.apiVersion}/',
      connectTimeout: const Duration(milliseconds: AppConstants.apiTimeout),
      receiveTimeout: const Duration(milliseconds: AppConstants.apiTimeout),
    ),
  );
  final AuthService _authService = AuthService();

  /// Make authenticated DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Session mismatch - user logged in from another device
        await clearSession();
        throw Exception('Session expired. Please login again.');
      }
      rethrow;
    }
  }

  /// Get device ID (unique identifier for this device)
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(AppConstants.keyDeviceId);

    if (deviceId == null) {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown-ios';
      } else {
        deviceId = 'unknown-platform';
      }
      await prefs.setString(AppConstants.keyDeviceId, deviceId);
    }

    return deviceId;
  }

  /// Save session ID
  Future<void> _saveSessionId(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keySessionId, sessionId);
    print('Saved sessionId to prefs: $sessionId');
  }

  /// Get session ID
  Future<String?> getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keySessionId);
  }

  /// Clear session data
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keySessionId);
  }

  /// Register or update user session (call after Firebase login)
  Future<Map<String, dynamic>> registerUserSession() async {
    try {
      // Get Firebase ID token
      final idToken = await _authService.getIdToken(forceRefresh: true);

      if (idToken == null) {
        throw Exception('No authentication token available');
      }

      // Get device ID
      final deviceId = await _getDeviceId();
      // Call backend to create/update user session
      final response = await _dio.post(
        'users/create',
        options: Options(
          headers: {
            'Authorization': 'Bearer $idToken',
            'x-device-id': deviceId,
          },
        ),
      );

      // Save session ID
      final sessionId = response.data['session_id'];
      if (sessionId != null) {
        await _saveSessionId(sessionId);
      }

      return response.data;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to register session',
      );
    } catch (e) {
      throw Exception('Failed to register session: $e');
    }
  }

  /// Get authenticated request headers
  Future<Map<String, String>> _getAuthHeaders() async {
    final idToken = await _authService.getIdToken(forceRefresh: true);
    final sessionId = await getSessionId();
    // // If sessionId is missing, try to (re)register session automatically
    // if (sessionId == null) {
    //   try {
    //     await registerUserSession();
    //   } catch (e) {}
    // }
    final deviceId = await _getDeviceId();

    return {
      if (idToken != null) 'Authorization': 'Bearer $idToken',
      if (sessionId != null) 'x-session-id': sessionId,
      'x-device-id': deviceId,
    };
  }

  /// Make authenticated GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? extraHeaders,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      if (extraHeaders != null) {
        headers.addAll(extraHeaders);
      }
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Session mismatch - user logged in from another device
        await clearSession();
        throw Exception('Session expired. Please login again.');
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Get user profile from backend
  Future<Map<String, dynamic>> getUserProfile() async {
    final headers = await _getAuthHeaders();
    final resp = await _dio.get(
      'users/profile',
      options: Options(headers: headers),
    );
    return resp.data as Map<String, dynamic>;
  }

  /// Make authenticated POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Session mismatch - user logged in from another device
        await clearSession();
        throw Exception('Session expired. Please login again.');
      }
      rethrow;
    }
  }

  /// Make authenticated PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Session mismatch - user logged in from another device
        await clearSession();
        throw Exception('Session expired. Please login again.');
      }
      rethrow;
    }
  }

  /// Request signed upload URLs for course media
  Future<Response> requestUpload(
    String? courseId,
    Map<String, dynamic> payload,
  ) async {
    if (courseId == null) {
      return await post('courses/thumbnail/request-upload', data: payload);
    } else {
      return await post('courses/$courseId/request-upload', data: payload);
    }
  }

  /// Confirm uploaded media after client uploads files to storage
  Future<Response> confirmMediaUpload(List<String> mediaIds) async {
    return await post(
      'courses/media/confirm-upload',
      data: {'mediaIds': mediaIds},
    );
  }

  Future<Response> getMediaUsagesByFolder(String folderId) async {
    return await get('media-usages/folder/$folderId');
  }

  /// Get media access token and URL
  Future<Map<String, dynamic>> getMediaAccessToken(String assetId) async {
    final response = await get('media-assets/$assetId/accessToken');
    return response.data;
  }

  /// Delete media usage by ID
  Future<void> deleteMediaUsage(String usageId) async {
    await delete('media-usages/delete/$usageId');
  }
}
