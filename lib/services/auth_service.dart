import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zemule/services/supabase_service.dart';

class AppUser {
  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
}

class AppUserCredential {
  const AppUserCredential({required this.user});

  final AppUser? user;
}

class AuthService {
  AuthService({SupabaseService? supabase})
    : _supabase = supabase ?? SupabaseService.instance;

  final SupabaseService _supabase;
  static const String _recentSearchesKey = 'recent_searches';
  static final RegExp _pinRegex = RegExp(r'^\d{6}$');

  Stream<AppUser?> get userChanges async* {
    yield currentUser;
    yield* _supabase.authStateChanges.map(
      (state) => _mapUser(state.session?.user),
    );
  }

  AppUser? get currentUser => _mapUser(_supabase.currentAuthUser);

  bool get isLoggedIn => currentUser != null;

  Future<AppUserCredential> signInWithEmailPin(String email, String pin) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail == null || !_isValidPin(pin)) {
      throw 'Enter a valid email and 6-digit PIN';
    }

    try {
      final response = await _signInWithPinPassword(
        normalizedEmail,
        pin,
      );

      final user = response.user ?? _supabase.currentAuthUser;

      if (user != null) {
        await _supabase.upsertUser(<String, dynamic>{
          'id': user.id,
          'email': user.email,
          'last_login': DateTime.now().toUtc().toIso8601String(),
        });
      }

      await _recordLoginAttempt(normalizedEmail, true);
      return AppUserCredential(user: _mapUser(user));
    } on AuthException catch (error) {
      await _recordLoginAttempt(normalizedEmail, false);
      throw _mapAuthError(error);
    } catch (error) {
      await _recordLoginAttempt(normalizedEmail, false);
      final message = error.toString();
      throw message.isNotEmpty ? message : 'Invalid email or PIN';
    }
  }

  Future<AppUserCredential> signUpWithEmailPin({
    required String name,
    required String email,
    required String pin,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final trimmedName = name.trim();
    final traceId = 'email-pin-signup-${DateTime.now().microsecondsSinceEpoch}';

    void logStage(String stage, [Map<String, Object?> details = const <String, Object?>{}]) {
      _logPinSignup(stage, <String, Object?>{'traceId': traceId, ...details});
    }

    logStage('start', <String, Object?>{
      'email': normalizedEmail,
      'nameLength': trimmedName.length,
      'pinLength': pin.length,
    });

    if (normalizedEmail == null || !_isValidPin(pin) || trimmedName.isEmpty) {
      logStage('validation_failed', <String, Object?>{
        'emailValid': normalizedEmail != null,
        'pinValid': _isValidPin(pin),
        'nameProvided': trimmedName.isNotEmpty,
      });
      throw 'Provide your full name, email, and 6-digit PIN';
    }

    final authEmail = normalizedEmail;
    final pinHash = _derivePinHash(authEmail, pin);

    var stage = 'auth_signup';

    try {
      logStage('auth_signup_call', <String, Object?>{
        'authEmail': authEmail,
        'pinLength': pin.length,
      });

      final response = await _supabase.signUpWithEmail(
        email: authEmail,
        password: pin,
      );

      final user = response.user;
      logStage('auth_signup_response', <String, Object?>{
        'userReturned': user != null,
        'sessionReturned': response.session != null,
        'userId': user?.id,
        'authEmail': user?.email,
      });

      if (user == null) {
        throw 'Something went wrong. Try again.';
      }

      if (response.session == null) {
        stage = 'ensure_session_login';
        await _supabase.signInWithEmail(
          email: authEmail,
          password: pin,
        );
        logStage('ensure_session_login_success', <String, Object?>{'userId': user.id});
      }

      stage = 'update_auth_user';
      await _supabase.updateAuthUser(
        data: <String, dynamic>{'name': trimmedName},
      );
      logStage('update_auth_user_success', <String, Object?>{'userId': user.id});

      stage = 'profile_upsert';
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await _supabase.upsertUser(<String, dynamic>{
        'id': user.id,
        'name': trimmedName,
        'email': authEmail,
        'pin_hash': pinHash,
        'pin_enabled': true,
        'created_at': nowIso,
        'last_login': nowIso,
      });
      logStage('profile_upsert_success', <String, Object?>{'userId': user.id});

      return AppUserCredential(
        user: _mapUser(_supabase.currentAuthUser ?? user),
      );
    } on AuthException catch (error) {
      logStage('auth_exception', <String, Object?>{
        'statusCode': error.statusCode,
        'message': error.message,
      });
      throw _mapAuthError(error);
    } on PostgrestException catch (error, stackTrace) {
      logStage(
        'postgrest_exception',
        <String, Object?>{
          'code': error.code,
          'message': error.message,
          'details': error.details,
        },
        );
      developer.log(
        'signUpWithPhonePin postgrest error',
        error: error,
        stackTrace: stackTrace,
      );
      throw error.message.isNotEmpty
          ? error.message
          : 'Something went wrong. Try again.';
    } catch (error, stackTrace) {
      logStage('unexpected_exception', <String, Object?>{
        'error': error.toString(),
      });
      developer.log(
        'signUpWithPhonePin unexpected error',
        error: error,
        stackTrace: stackTrace,
      );
      throw 'Something went wrong. Try again.';
    }
  }

  Future<void> updateUserProfile(String displayName) async {
    final user = _supabase.currentAuthUser;
    if (user == null) {
      throw 'Something went wrong. Try again.';
    }
    await _supabase.updateAuthUser(
      data: <String, dynamic>{'name': displayName.trim()},
    );
    await _supabase.upsertUser(<String, dynamic>{
      'id': user.id,
      'name': displayName.trim(),
    });
  }

  Future<AppUserCredential> signInWithOTP(
    String verificationId,
    String smsCode,
  ) async {
    throw 'Phone OTP login is disabled. Use email + PIN.';
  }

  Future<void> signOut() async {
    await _clearCachedUserData();
    await _supabase.signOut();
  }

  Future<String> sendPasswordReset(String email) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail == null) {
      throw 'Enter a valid email address';
    }

    await _supabase.client.auth.resetPasswordForEmail(
      normalizedEmail,
      redirectTo: 'myapp://reset-password',
    );
    return 'Password reset email sent.';
  }

  Future<String> completePasswordRecovery(String newPin) async {
    if (!_isValidPin(newPin)) {
      throw 'PIN must be exactly 6 digits';
    }

    final user = _supabase.currentAuthUser;
    if (user == null) {
      throw 'Your reset session is still loading. Reopen the email link and try again.';
    }

    await _supabase.updateAuthUser(password: newPin);
    await _supabase.upsertUser(<String, dynamic>{
      'id': user.id,
      'email': user.email,
      'pin_hash': _derivePinHash(user.email ?? '', newPin),
      'pin_enabled': true,
      'last_login': DateTime.now().toUtc().toIso8601String(),
    });

    try {
      await _clearCachedUserData();
      await _supabase.signOut();
    } catch (_) {
      // Best-effort session cleanup after a successful reset.
    }

    return 'PIN reset successfully.';
  }

  Future<AuthResponse> _signInWithPinPassword(String email, String pin) async {
    try {
      return await _supabase.signInWithEmail(
        email: email,
        password: pin,
      );
    } on AuthException catch (error) {
      if (!_isInvalidLoginError(error)) {
        rethrow;
      }

      final response = await _supabase.signInWithEmail(
        email: email,
        password: _deriveLegacyPassword(email, pin),
      );

      try {
        await _supabase.updateAuthUser(password: pin);
      } catch (_) {
        // Best-effort migration from the legacy derived password format.
      }

      return response;
    }
  }

  bool _isInvalidLoginError(AuthException error) {
    return error.message.toLowerCase().contains('invalid login credentials');
  }

  String _deriveLegacyPassword(String email, String pin) {
    final payload = 'zemule-auth|v2|${email.trim().toLowerCase()}|$pin';
    final digest = sha256.convert(utf8.encode(payload)).toString();
    return 'Zemule!$digest';
  }

  Future<void> _clearCachedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }

  AppUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }
    return AppUser(
      uid: user.id,
      email: user.email,
      displayName: user.userMetadata?['name'] as String?,
      photoURL: (user.userMetadata?['avatar_url'] as String?)?.trim(),
    );
  }

  String _mapAuthError(AuthException error) {
    final code = error.statusCode?.toString() ?? '';
    final message = error.message.toLowerCase();
    if (message.contains('already registered') || code == '422') {
      return 'Account already exists for this email';
    }
    if (message.contains('invalid login credentials')) {
      return 'Invalid email or PIN';
    }
    return error.message.isNotEmpty
        ? error.message
        : 'Something went wrong. Try again.';
  }

  bool _isValidPin(String pin) => _pinRegex.hasMatch(pin);

  String? _normalizeEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return null;
    return RegExp(r"^[\w.!#%&'*+/=?`{|}~-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")
            .hasMatch(trimmed)
        ? trimmed.toLowerCase()
        : null;
  }

  String _derivePinHash(String email, String pin) {
    final payload = 'zemule-pin|v2|${email.trim().toLowerCase()}|$pin';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  Future<void> _recordLoginAttempt(String email, bool success) async {
    try {
      await _supabase.insertLoginAttempt(email: email, success: success);
    } catch (_) {
      // Best-effort telemetry.
    }
  }

  void _logPinSignup(
    String stage, [
    Map<String, Object?> details = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  ]) {
    developer.log(
      'PIN_SIGNUP::$stage ${_safeJson(details)}',
      name: 'AuthService',
      error: error,
      stackTrace: stackTrace,
    );
  }

  String _safeJson(Map<String, Object?> details) {
    try {
      return jsonEncode(details);
    } catch (_) {
      final fallback = details.map(
        (key, value) => MapEntry(key, value?.toString()),
      );
      return jsonEncode(fallback);
    }
  }
}
