import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Stream provider that emits the current Firebase auth state.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Auth service provider for login/register/logout actions.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  GoogleSignIn? _googleSignIn;
  bool _initialized = false;

  User? get currentUser => _auth.currentUser;

  /// Initialize Google Sign-In (must be called before using signInWithGoogle)
  Future<void> _initGoogleSignIn() async {
    if (_initialized) return;

    _googleSignIn = GoogleSignIn.instance;
    await _googleSignIn!.initialize();
    _initialized = true;
  }

  /// Sign in with email and password.
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Register with email and password.
  Future<UserCredential> registerWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(displayName);
    return credential;
  }

  /// Sign in with Google.
  Future<UserCredential> signInWithGoogle() async {
    // Initialize Google Sign-In if not already done
    await _initGoogleSignIn();

    // Check if authenticate method is supported on this platform
    final supportsAuth = await _googleSignIn!.supportsAuthenticate();

    if (!supportsAuth) {
      throw Exception(
        'Google Sign-In authenticate not supported on this platform. Use renderButton for web.',
      );
    }

    try {
      // Trigger the Google Sign-In authentication
      final GoogleSignInAccount? result = await _googleSignIn!.authenticate();

      if (result == null) {
        throw Exception('Google Sign-In authentication returned null');
      }

      // Obtain the auth details from the result
      final GoogleSignInAuthentication googleAuth = await result.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.idToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      return await _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw Exception('Google Sign-In was cancelled');
      }
      rethrow;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    await _initGoogleSignIn();
    await Future.wait([_auth.signOut(), _googleSignIn!.signOut()]);
  }
}
