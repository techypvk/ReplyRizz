import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  FirebaseAuth? _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  bool get isFirebaseAvailable => _auth != null;

  AuthService() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        _auth = FirebaseAuth.instance;
        _auth?.authStateChanges().listen((User? user) {
          _user = user;
          notifyListeners();
        });
      } else {
        debugPrint("Firebase not initialized. Auth disabled.");
      }
    } catch (e) {
      debugPrint("Error initializing Auth: $e");
    }
  }

  // Email & Password Sign Up
  Future<String?> signUpWithEmail(String email, String password) async {
    if (_auth == null) return "Authentication service unavailable.";
    try {
      _isLoading = true;
      notifyListeners();
      await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return "An unknown error occurred.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Email & Password Login
  Future<String?> signInWithEmail(String email, String password) async {
    if (_auth == null) return "Authentication service unavailable.";
    try {
      _isLoading = true;
      notifyListeners();
      await _auth!.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return "An unknown error occurred.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Google Sign In
  Future<String?> signInWithGoogle() async {
    if (_auth == null) return "Authentication service unavailable.";
    try {
      _isLoading = true;
      notifyListeners();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return "Sign in cancelled";
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await _auth!.signInWithCredential(credential);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return "An unknown error occurred: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Password Reset
  Future<String?> sendPasswordResetEmail(String email) async {
    if (_auth == null) return "Authentication service unavailable.";
    try {
      await _auth!.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return "An unknown error occurred.";
    }
  }

  // Logout
  Future<void> signOut() async {
    if (_auth == null) return;
    try {
      await _googleSignIn.signOut();
      await _auth!.signOut();
    } catch (e) {
      debugPrint("Error signing out: $e");
    }
  }
}
