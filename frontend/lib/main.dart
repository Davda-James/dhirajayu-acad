import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'src/providers/user_provider.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:screen_protector/screen_protector.dart';
import 'firebase_options.dart';
import 'src/constants/AppTheme.dart';
import 'src/constants/AppConstants.dart';
import 'src/screens/splash_screen.dart';
import 'src/screens/auth/login_screen.dart';
import 'src/screens/home/home_screen.dart';
import 'src/screens/courses/course_detail_screen.dart';
import 'src/screens/admin/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Disable screenshots and screen recording
  await _disableScreenCapture();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const AyurvedaAcademyApp());
}

Future<void> _disableScreenCapture() async {
  try {
    await ScreenProtector.protectDataLeakageOn();
  } catch (e) {}
}

class AyurvedaAcademyApp extends StatelessWidget {
  const AyurvedaAcademyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UserProvider(),
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/admin': (context) => const AdminHomeScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name?.startsWith('/course/') == true) {
            final courseId = settings.name!.split('/').last;
            final courseDetails =
                settings.arguments
                    as Map<
                      String,
                      dynamic
                    >?; // Extract course details from arguments
            return MaterialPageRoute(
              builder: (context) => CourseDetailScreen(
                courseId: courseId,
                courseDetails:
                    courseDetails ?? {}, // Pass course details or empty map
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}
