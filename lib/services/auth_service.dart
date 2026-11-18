import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';

/// Handles login, registration and the current user's profile + role.
/// One unified login: the role ('user' / 'admin') is read from Firestore.
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<User?>? _sub;
  AppUser? _user;
  bool _loading = true;
  int _seq = 0; // makes sure only the latest profile load wins

  AuthService() {
    _sub = _auth.authStateChanges().listen(_load);
  }

  AppUser? get user => _user;
  bool get isLoading => _loading;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;

  Future<void> _load(User? fbUser) async {
    final seq = ++_seq;
    AppUser? result;

    if (fbUser != null) {
      final fallback = AppUser(
        uid: fbUser.uid,
        name: fbUser.email?.split('@').first ?? 'User',
        email: fbUser.email ?? '',
        phone: '',
        role: 'user',
        isActive: true,
      );
      try {
        final doc = await _db.collection('users').doc(fbUser.uid).get();
        result = doc.exists ? AppUser.fromDoc(doc) : fallback;
      } catch (_) {
        result = fallback;
      }

      // Disabled accounts are signed out immediately.
      if (result?.isActive == false) {
        await _auth.signOut();
        result = null;
      }
    }

    if (seq != _seq) return;
    _user = result;
    _loading = false;
    notifyListeners();
  }

  /// Returns null on success, or an error message.
  Future<String?> login(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final doc = await _db.collection('users').doc(cred.user!.uid).get();
      if (doc.exists && doc.data()?['isActive'] == false) {
        await _auth.signOut();
        return 'This account has been disabled. Please contact the admin.';
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e);
    } catch (e) {
      return 'Something went wrong: $e';
    }
  }

  /// New accounts are always created with role 'user'.
  Future<String?> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = AppUser(
        uid: cred.user!.uid,
        name: name,
        email: email,
        phone: phone,
        role: 'user',
        isActive: true,
      );
      await _db.collection('users').doc(user.uid).set({
        ...user.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _load(cred.user);
      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e);
    } catch (e) {
      return 'Something went wrong: $e';
    }
  }

  Future<void> logout() => _auth.signOut();

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Wrong email or password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
