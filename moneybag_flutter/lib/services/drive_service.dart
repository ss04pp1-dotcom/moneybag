import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';

/// Real Google Drive backup over Drive v3 REST.
///
/// Auth: Google Sign-In with the `drive.appdata` scope — backups live in
/// the account's hidden `appDataFolder` (invisible in the Drive UI, not
/// readable by Google or other apps). Every byte uploaded is the existing
/// AES-256-GCM encrypted `.mbbak` envelope, so Drive only ever stores
/// ciphertext.
class MbDriveService {
  MbDriveService._();
  static final MbDriveService instance = MbDriveService._();

  GoogleSignIn? _signIn;

  GoogleSignIn get _client => _signIn ??= GoogleSignIn(
        scopes: const ['https://www.googleapis.com/auth/drive.appdata'],
        serverClientId: MbConfig.googleWebClientId,
      );

  GoogleSignInAccount? _account;
  GoogleSignInAccount? get account => _account;

  /// True when a Web OAuth Client ID has been configured in MbConfig.
  bool get configured => MbConfig.driveConfigured;

  // ── auth ────────────────────────────────────────────────────────────────
  Future<GoogleSignInAccount?> signIn() async {
    if (!configured) {
      throw const MbDriveException(MbDriveError.notConfigured);
    }
    try {
      if (await _client.isSignedIn()) {
        _account = await _client.signInSilently();
      }
      _account ??= await _client.signIn();
      if (_account != null) {
        // Make sure we hold a fresh Drive-scoped token.
        final auth = await _account!.authentication;
        if (auth.accessToken == null) {
          _account = await _client.signIn();
        }
      }
      return _account;
    } on MbDriveException {
      rethrow;
    } catch (e) {
      throw MbDriveException._raw('sign-in failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _client.signOut();
    } catch (_) {}
    _account = null;
  }

  Future<bool> tryRestoreSession() async {
    if (!configured) return false;
    try {
      _account = await _client.signInSilently();
      return _account != null;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final acc = _account;
    if (acc == null) throw const MbDriveException(MbDriveError.notSignedIn);
    final headers = await acc.authHeaders;
    return headers;
  }

  // ── REST helpers ────────────────────────────────────────────────────────
  static const String _base = 'https://www.googleapis.com/drive/v3';
  static const String _upload =
      'https://www.googleapis.com/upload/drive/v3/files';

  /// v2.2.0: every Drive call previously had NO timeout — one stalled
  /// socket left the auto-sync `_uploading` flag stuck ON forever (no more
  /// auto-backups until an app restart).
  static const Duration _httpTimeout = Duration(seconds: 30);

  Map<String, String> _jsonHeaders(Map<String, String> auth) =>
      {...auth, 'Content-Type': 'application/json; charset=UTF-8'};

  void _throwIfError(http.Response res, String what) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    String msg = what;
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['error'] is Map) {
        final e = body['error'] as Map;
        msg = '${e['message'] ?? what}';
      }
    } catch (_) {}
    throw MbDriveException._raw('$msg (${res.statusCode})');
  }

  // ── operations ──────────────────────────────────────────────────────────
  /// Uploads [bytes] (the encrypted .mbbak envelope) as [name]. If a file
  /// with the same name already exists it is PATCHed in place, so the Drive
  /// app folder holds one rolling backup per calendar stamp.
  Future<void> uploadBackup({
    required String name,
    required List<int> bytes,
  }) async {
    final auth = await _authHeaders();

    // Look for an existing file with the same name in appDataFolder.
    final existing = await listBackups();
    final old = existing.where((f) => f.name == name).toList();
    final isUpdate = old.isNotEmpty;

    final boundary = 'mb3a${DateTime.now().millisecondsSinceEpoch}';
    final metadata = jsonEncode({
      'name': name,
      if (!isUpdate) 'parents': ['appDataFolder'],
    });

    final body = Uint8List.fromList([
      ...ascii.encode('--$boundary\r\n'
          'Content-Type: application/json; charset=UTF-8\r\n\r\n'
          '$metadata\r\n'
          '--$boundary\r\n'
          'Content-Type: application/octet-stream\r\n\r\n'),
      ...bytes,
      ...ascii.encode('\r\n--$boundary--'),
    ]);

    final uri = Uri.parse(isUpdate
        ? '$_upload/${old.first.id}?uploadType=multipart'
        : '$_upload?uploadType=multipart');
    final headers = {
      ...auth,
      'Content-Type': 'multipart/related; boundary=$boundary',
    };
    final res = isUpdate
        ? await http
            .patch(uri, headers: headers, body: body)
            .timeout(_httpTimeout)
        : await http
            .post(uri, headers: headers, body: body)
            .timeout(_httpTimeout);
    _throwIfError(res, 'upload failed');
  }

  /// v2.2.0: renames a file in the hidden app folder (PATCH metadata only —
  /// no content re-upload). Used to rotate the rolling auto backup so one
  /// bad upload can never destroy the ONLY remote copy.
  Future<void> renameFile(String id, String newName) async {
    final auth = await _authHeaders();
    final res = await http
        .patch(
          Uri.parse('$_base/files/$id'),
          headers: _jsonHeaders(auth),
          body: jsonEncode({'name': newName}),
        )
        .timeout(_httpTimeout);
    _throwIfError(res, 'rename failed');
  }

  /// Lists MoneyBag backups in the hidden app folder, newest first.
  Future<List<MbDriveFile>> listBackups() async {
    final auth = await _authHeaders();
    final q = Uri.encodeQueryComponent(
        "name contains 'moneybag-' and trashed = false");
    final uri = Uri.parse('$_base/files'
        '?spaces=appDataFolder'
        '&q=$q'
        '&orderBy=modifiedTime desc'
        '&pageSize=25'
        '&fields=files(id,name,mimeType,size,modifiedTime)');
    final res = await http
        .get(uri, headers: _jsonHeaders(auth))
        .timeout(_httpTimeout);
    _throwIfError(res, 'listing failed');
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final files = (data['files'] as List? ?? const []);
    return [
      for (final f in files)
        MbDriveFile(
          id: f['id'] as String,
          name: f['name'] as String? ?? '',
          sizeBytes: int.tryParse('${f['size'] ?? ''}') ?? 0,
          modified: DateTime.tryParse('${f['modifiedTime'] ?? ''}') ??
              DateTime.fromMillisecondsSinceEpoch(0),
        ),
    ];
  }

  /// Downloads a backup's raw (still encrypted) bytes.
  Future<Uint8List> downloadFile(String id) async {
    final auth = await _authHeaders();
    final res = await http
        .get(
          Uri.parse('$_base/files/$id?alt=media'),
          headers: auth,
        )
        .timeout(const Duration(seconds: 120));
    _throwIfError(res, 'download failed');
    return res.bodyBytes;
  }

  Future<void> deleteFile(String id) async {
    final auth = await _authHeaders();
    final res = await http
        .delete(
          Uri.parse('$_base/files/$id'),
          headers: auth,
        )
        .timeout(_httpTimeout);
    _throwIfError(res, 'delete failed');
  }
}

class MbDriveFile {
  final String id;
  final String name;
  final int sizeBytes;
  final DateTime modified;

  const MbDriveFile({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.modified,
  });
}

enum MbDriveError { notConfigured, notSignedIn }

class MbDriveException implements Exception {
  final MbDriveError? code;
  final String message;
  const MbDriveException(this.code) : message = '';
  MbDriveException._raw(this.message) : code = null;

  @override
  String toString() => message.isEmpty ? 'Drive: $code' : 'Drive: $message';
}
