import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isGoogleSignInInitialized = false;

  // Initialize Google Sign-In
  Future<void> _initializeGoogleSignIn() async {
    if (_isGoogleSignInInitialized) return;

    try {
      await _googleSignIn.initialize();
      _isGoogleSignInInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize Google Sign-In: $e');
      rethrow;
    }
  }

  // Ensure Google Sign-In is initialized
  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_isGoogleSignInInitialized) {
      await _initializeGoogleSignIn();
    }
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get Firebase ID token for the current user
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Cannot get ID token: No user signed in');
        return null;
      }
      return await user.getIdToken(forceRefresh);
    } catch (e) {
      debugPrint('Error getting ID token: $e');
      return null;
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Ensure Google Sign-In is initialized
      await _ensureGoogleSignInInitialized();

      // Authenticate with Google
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email'],
      );

      // Get authorization client for access token
      final authClient = _googleSignIn.authorizationClient;
      final authorization = await authClient.authorizationForScopes(['email']);

      if (authorization == null) {
        throw Exception('Failed to get authorization');
      }

      // Get authentication (now synchronous in v7)
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: authorization.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      return await _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      debugPrint('Google Sign In Exception: ${e.code.name} - ${e.description}');
      rethrow;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
    } catch (e) {
      debugPrint('Sign Out Error: $e');
      rethrow;
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      await currentUser?.delete();
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Delete Account Error: $e');
      rethrow;
    }
  }
}
