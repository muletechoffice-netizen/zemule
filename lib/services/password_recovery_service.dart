import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class PasswordRecoveryService extends ChangeNotifier {
  PasswordRecoveryService._();

  static final PasswordRecoveryService instance = PasswordRecoveryService._();

  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _linkSubscription;
  bool _isRecoveryPending = false;

  bool get isRecoveryPending => _isRecoveryPending;

  Future<void> initialize() async {
    final initialLink = await _safeGetInitialLink();
    if (_isResetPasswordLink(initialLink)) {
      _setRecoveryPending(true);
    }

    _linkSubscription ??= _appLinks.uriLinkStream.listen((uri) {
      if (_isResetPasswordLink(uri)) {
        _setRecoveryPending(true);
      }
    });
  }

  void clearPending() {
    _setRecoveryPending(false);
  }

  bool _isResetPasswordLink(Uri? uri) {
    if (uri == null) {
      return false;
    }

    if (uri.scheme != 'myapp') {
      return false;
    }

    return uri.host == 'reset-password' ||
        uri.path == '/reset-password' ||
        uri.pathSegments.contains('reset-password');
  }

  Future<Uri?> _safeGetInitialLink() async {
    try {
      return await _appLinks.getInitialLink();
    } catch (_) {
      return null;
    }
  }

  void _setRecoveryPending(bool value) {
    if (_isRecoveryPending == value) {
      return;
    }
    _isRecoveryPending = value;
    notifyListeners();
  }
}
