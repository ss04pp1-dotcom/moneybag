import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';

/// Minimal Google profile returned after sign-in.
class MbGoogleProfile {
  final String id;
  final String displayName;
  final String email;
  final String? photoUrl;

  const MbGoogleProfile({
    required this.id,
    required this.displayName,
    required this.email,
    this.photoUrl,
  });
}

/// Google Sign-In (login) — the ONLY login method in MoneyBag.
///
/// Uses the same Web OAuth Client ID as the Drive backup, so configuring it
/// once enables both. No extra scopes are requested: just the account's
/// basic profile (name, email, photo) which Google shows on the consent
/// screen.
class MbAuthService {
  MbAuthService._();
  static final MbAuthService instance = MbAuthService._();

  GoogleSignIn? _client;

  GoogleSignIn get _signIn => _client ??= GoogleSignIn(
        serverClientId: MbConfig.googleWebClientId,
      );

  /// True once the Web OAuth Client ID placeholder has been replaced.
  bool get configured => MbConfig.driveConfigured;

  MbGoogleProfile _profileOf(GoogleSignInAccount a) => MbGoogleProfile(
        id: a.id,
        displayName: a.displayName ?? '',
        email: a.email,
        photoUrl: a.photoUrl,
      );

  /// Interactive sign-in. Returns null when the user cancels the dialog.
  /// Throws when not configured or the flow fails.
  Future<MbGoogleProfile?> signIn() async {
    if (!configured) {
      throw StateError('google sign-in not configured');
    }
    final account = await _signIn.signIn();
    if (account == null) return null;
    return _profileOf(account);
  }

  /// Silent restore of a previous session (no UI). Returns null when there
  /// is no session to restore.
  Future<MbGoogleProfile?> tryRestoreSession() async {
    if (!configured) return null;
    try {
      final account = await _signIn.signInSilently();
      return account == null ? null : _profileOf(account);
    } catch (e) {
      debugPrint('MbAuthService.tryRestoreSession: $e');
      return null;
    }
  }

  Future<void> signOut() => _signIn.signOut();

  /// Downloads the account photo (JPEG bytes) or null.
  Future<List<int>?> fetchPhotoBytes(String url) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
          );
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return res.bodyBytes;
      }
    } catch (e) {
      debugPrint('MbAuthService.fetchPhotoBytes: $e');
    }
    return null;
  }
}
