// lib/features/auth/auth_bloc.dart
// Firebase Authentication BLoC

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Events ────────────────────────────────────────────────────────────────────

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override List<Object?> get props => [];
}

class CheckAuthStatus extends AuthEvent { const CheckAuthStatus(); }
class SignInWithGoogle extends AuthEvent { const SignInWithGoogle(); }
class SignInWithEmail extends AuthEvent {
  final String email;
  final String password;
  const SignInWithEmail({required this.email, required this.password});
}
class RegisterWithEmail extends AuthEvent {
  final String email;
  final String password;
  final String displayName;
  const RegisterWithEmail({required this.email, required this.password, required this.displayName});
}
class SignOut extends AuthEvent { const SignOut(); }

// ── States ────────────────────────────────────────────────────────────────────

abstract class AuthState extends Equatable {
  const AuthState();
  @override List<Object?> get props => [];
}

class AuthInitial extends AuthState { const AuthInitial(); }
class AuthLoading extends AuthState { const AuthLoading(); }

class AuthAuthenticated extends AuthState {
  final String userId;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String token;
  final String plan;   // free | pro | premium
  const AuthAuthenticated({
    required this.userId, required this.email, required this.token,
    this.displayName, this.avatarUrl, this.plan = 'free',
  });
  @override List<Object?> get props => [userId, email, token, plan, displayName, avatarUrl];
}

class AuthUnauthenticated extends AuthState { const AuthUnauthenticated(); }

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override List<Object?> get props => [message];
}

// ── BLoC ──────────────────────────────────────────────────────────────────────

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final _firebase = FirebaseAuth.instance;

  //  Google Sign-In 
  final GoogleSignIn _google = GoogleSignIn(
    scopes: ['email'],
  );

  static const _apiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.yourapp.com',
  );

  AuthBloc() : super(const AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<SignInWithGoogle>(_onSignInWithGoogle);
    on<SignInWithEmail>(_onSignInWithEmail);
    on<RegisterWithEmail>(_onRegisterWithEmail);
    on<SignOut>(_onSignOut);
  }

  // ── Handlers ────────────────────────────────────────────────────────────

  Future<void> _onCheckAuthStatus(CheckAuthStatus event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedToken = prefs.getString('auth_token');
      final firebaseUser = _firebase.currentUser;

      if (firebaseUser != null && cachedToken != null) {
        final idToken = await firebaseUser.getIdToken(true);
        final result = await _exchangeFirebaseToken(idToken);
        if (result != null) {
          await prefs.setString('auth_token', result['token']);
          emit(AuthAuthenticated(
            userId: result['user']['id']?.toString() ?? '',
            email: result['user']['email'] ?? '',
            displayName: result['user']['displayName'],
            avatarUrl: result['user']['avatarUrl'],
            token: result['token'],
            plan: result['user']['plan'] ?? 'free',
          ));
          return;
        }
      }
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onSignInWithGoogle(SignInWithGoogle event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      // ignore: undefined_method
      final googleAccount = await _google.signIn();
      if (googleAccount == null) { emit(const AuthUnauthenticated()); return; }

      final googleAuth = await googleAccount.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _firebase.signInWithCredential(credential);
      final idToken = await userCred.user!.getIdToken();

      final result = await _exchangeFirebaseToken(idToken);
      if (result == null) { emit(const AuthError('Server authentication failed')); return; }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', result['token']);

      emit(AuthAuthenticated(
        userId: result['user']['id']?.toString() ?? '',
        email: result['user']['email'] ?? '',
        displayName: result['user']['displayName'],
        avatarUrl: result['user']['avatarUrl'],
        token: result['token'],
        plan: result['user']['plan'] ?? 'free',
      ));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_firebaseErrorMessage(e.code)));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignInWithEmail(SignInWithEmail event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final userCred = await _firebase.signInWithEmailAndPassword(
        email: event.email.trim(), password: event.password,
      );
      final idToken = await userCred.user!.getIdToken();
      final result = await _exchangeFirebaseToken(idToken);
      if (result == null) { emit(const AuthError('Server error')); return; }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', result['token']);

      emit(AuthAuthenticated(
        userId: result['user']['id']?.toString() ?? '',
        email: result['user']['email'] ?? '',
        displayName: result['user']['displayName'],
        token: result['token'],
        plan: result['user']['plan'] ?? 'free',
      ));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_firebaseErrorMessage(e.code)));
    }
  }

  Future<void> _onRegisterWithEmail(RegisterWithEmail event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final userCred = await _firebase.createUserWithEmailAndPassword(
        email: event.email.trim(), password: event.password,
      );
      await userCred.user!.updateDisplayName(event.displayName);
      await userCred.user!.sendEmailVerification();

      final idToken = await userCred.user!.getIdToken();
      final result = await _exchangeFirebaseToken(idToken);
      if (result == null) { emit(const AuthError('Server error')); return; }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', result['token']);

      emit(AuthAuthenticated(
        userId: result['user']['id']?.toString() ?? '',
        email: result['user']['email'] ?? '',
        displayName: event.displayName,
        token: result['token'],
        plan: 'free',
      ));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_firebaseErrorMessage(e.code)));
    }
  }

  Future<void> _onSignOut(SignOut event, Emitter<AuthState> emit) async {
    await _firebase.signOut();
    // ignore: undefined_method
    await _google.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    emit(const AuthUnauthenticated());
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _exchangeFirebaseToken(String? firebaseToken) async {
    if (firebaseToken == null) return null;
    try {
      final dio = Dio();
      final res = await dio.post(
        '$_apiBase/auth/firebase',
        data: {'firebase_token': firebaseToken},
      );
      return res.data as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  String _firebaseErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':      return 'No account found with this email.';
      case 'wrong-password':      return 'Incorrect password.';
      case 'email-already-in-use':return 'An account already exists with this email.';
      case 'weak-password':       return 'Password must be at least 6 characters.';
      case 'invalid-email':       return 'Please enter a valid email address.';
      case 'too-many-requests':   return 'Too many attempts. Please try again later.';
      case 'network-request-failed': return 'No internet connection.';
      default:                    return 'Authentication failed. Please try again.';
    }
  }
}
