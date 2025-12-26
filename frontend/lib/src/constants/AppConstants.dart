/// App Constants
/// General constants used throughout the app
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Dhiraj Ayu Academy';
  static const String appDescription = 'Learn Ayurveda with expert-led courses';

  // API Configuration
  static const String apiBaseUrl =
      'http://192.168.29.241:3000/api'; // Update with your backend URL
  static const String apiVersion = 'v0';
  static const int apiTimeout = 30000; // 30 seconds

  // Pagination
  static const int defaultPageSize = 10;
  static const int coursesPerPage = 10;

  // Animation Durations (in milliseconds)
  static const int animationDurationFast = 200;
  static const int animationDurationNormal = 300;
  static const int animationDurationSlow = 500;
  static const int splashScreenDuration = 2000;

  // Image/Video Configuration
  static const double thumbnailAspectRatio = 16 / 9;
  static const int maxImageSizeMB = 5;
  static const int videoQualityOptions = 720;

  // Form Validation
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 64;
  static const int maxNameLength = 100;
  static const int maxDescriptionLength = 500;

  // Storage Keys
  static const String keyAuthToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyUserEmail = 'user_email';
  static const String keyDeviceId = 'device_id';
  static const String keySessionId = 'session_id';
  static const String keyThemeMode = 'theme_mode';
  static const String keyOnboardingCompleted = 'onboarding_completed';

  // Error Messages
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork =
      'Network error. Please check your connection.';
  static const String errorUnauthorized = 'Unauthorized. Please log in again.';
  static const String errorNotFound = 'Resource not found.';
  static const String errorTimeout = 'Request timed out. Please try again.';

  // Success Messages
  static const String successLogin = 'Welcome back!';
  static const String successEnrollment = 'Successfully enrolled in course';
  static const String successUpdate = 'Updated successfully';

  // Course Filters
  static const List<String> courseCategories = ['All Courses', 'Free', 'Paid'];

  static const List<String> courseSortOptions = [
    'Most Recent',
    'Most Popular',
    'Price: Low to High',
    'Price: High to Low',
    'A-Z',
    'Z-A',
  ];

  // Media Types
  static const String mediaTypeVideo = 'VIDEO';
  static const String mediaTypeAudio = 'AUDIO';
  static const String mediaTypeDocument = 'DOCUMENT';

  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
}
