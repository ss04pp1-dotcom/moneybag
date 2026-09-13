import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show TableUpdate;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../state/app_state.dart';
import 'backup_service.dart';
import 'drive_service.dart';

/// Outcome of the automatic restore-on-login check.
enum MbAutoRestoreStatus {
  notConfigured, // Web Client ID placeholder — Google features off
  notSignedIn, // user did not sign in with Google
  localDataPresent, // this device already has data — auto-restore skipped
  noBackup, // Drive has no backup file
  needsPassphrase, // backup found — one passphrase needed to decrypt
  restored, // downloaded + decrypted + restored into SQLite
  failed, // network/decrypt error (error text captured)
}

class MbAutoRestoreResult {
  final MbAutoRestoreStatus status;
  final MbRestoreStats? stats;
  final String? error;
  const MbAutoRestoreResult(this.status, {this.stats, this.error});
}

/// Auto Google Drive sync — the hands-free backup layer.
///
/// ১ AUTO-BACKUP: a listener on the Drift database. Every transaction /
/// budget / goal change arms a 5-second debounce; when it expires the latest
/// data is encrypted (AES-256-GCM, same `.mbbak` envelope) and uploaded to
/// the account's hidden Drive app folder. Extra guards: minimum 60 s between
/// uploads, flush on app-pause, everything silent — a failed upload never
/// disturbs the user (the next change retries).
///
/// ২ AUTO-RESTORE on login: right after Google Sign-In, if this device has
/// NO local data and Drive HAS a backup, it is downloaded, decrypted and
/// restored into SQLite with zero taps. When the passphrase is not yet
/// known (fresh install) the login screen asks for it ONCE inline — never a
/// trip to the backup screen.
///
/// The passphrase is remembered locally (obfuscated in SharedPreferences)
/// so both directions stay automatic afterwards.
class MbAutoSyncService extends ChangeNotifier {
  MbAutoSyncService._();
  static final MbAutoSyncService instance = MbAutoSyncService._();

  static const String _autoOnKey = 'driveAutoSyncOn';
  static const String _passKey = 'driveBackupPassphrase';
  static const String _lastBackupKey = 'lastAutoBackupAt';
  static const String _autoFileName = 'moneybag-auto-latest.mbbak';
  static const String _autoPrevName = 'moneybag-auto-prev.mbbak';

  static const Duration _debounceDelay = Duration(seconds: 5);
  static const Duration _minInterval = Duration(seconds: 60);

  MbAppState? _state;
  StreamSubscription<Set<TableUpdate>>? _sub;
  Timer? _debounce;
  bool _uploading = false;
  bool _restoring = false;
  bool _dirty = false;
  DateTime? _lastUploadAt;
  DateTime? _lastAutoBackupAt;
  String? _lastError;

  bool _autoOn = true;

  /// Whether the user wants auto sync (toggle in the backup screen).
  bool get autoSyncOn => _autoOn;
  DateTime? get lastAutoBackupAt => _lastAutoBackupAt;
  String? get lastError => _lastError;
  bool get hasRememberedPassphrase => _passCached != null;
  bool get uploading => _uploading;

  SharedPreferences? _prefs;
  String? _passCached;

  /// Attach after the app state boots. Idempotent.
  Future<void> attach(MbAppState state) async {
    if (_state != null) return;
    _state = state;
    _prefs ??= await SharedPreferences.getInstance();
    _autoOn = _prefs!.getBool(_autoOnKey) ?? true;
    final ms = _prefs!.getInt(_lastBackupKey);
    _lastAutoBackupAt = ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms);
    _passCached = _decodePass(_prefs!.getString(_passKey));
    _sub = state.db.tableUpdates().listen((_) => _onDbChange());
  }

  Future<void> setAutoSync(bool on) async {
    _autoOn = on;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_autoOnKey, on);
    if (!on) {
      _debounce?.cancel();
      _dirty = false;
    }
    notifyListeners();
  }

  // ── passphrase (obfuscated at rest, local-only) ──────────────────────────

  String? _decodePass(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final bytes = base64Decode(raw);
      return utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<void> rememberPassphrase(String pass) async {
    _passCached = pass;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_passKey, base64Encode(utf8.encode(pass)));
    notifyListeners();
  }

  Future<void> forgetPassphrase() async {
    _passCached = null;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_passKey);
    notifyListeners();
  }

  // ── ১ auto-backup listener ───────────────────────────────────────────────

  void _onDbChange() {
    if (_restoring || !_autoOn || !_eligible()) return;
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, _backupNow);
  }

  bool _eligible() {
    final state = _state;
    if (state == null) return false;
    return state.googleLinked && MbConfig.driveConfigured;
  }

  /// Silent background upload. Called by the debounce timer and by
  /// [flushOnPause]. Never throws.
  Future<void> _backupNow() async {
    if (_uploading || !_dirty) return;
    final state = _state;
    if (state == null) return;
    final pass = _passCached;
    if (pass == null || pass.length < 6) return; // nothing to encrypt with

    // Rate-limit: at most one upload per minute.
    final last = _lastUploadAt;
    if (last != null && DateTime.now().difference(last) < _minInterval) {
      // Too soon — schedule a retry instead of dropping the change.
      _debounce?.cancel();
      _debounce = Timer(
        _minInterval - DateTime.now().difference(last),
        _backupNow,
      );
      return;
    }

    _uploading = true;
    try {
      final state2 = _state!;
      // v2.2.0 guard: never auto-upload a worthless (fully empty) snapshot —
      // a fresh device with a failed restore used to overwrite the good
      // remote backup with an empty DB seconds after login.
      if (state2.transactions.isEmpty &&
          state2.budgets.isEmpty &&
          state2.goals.isEmpty &&
          state2.contributions.isEmpty) {
        _dirty = false;
        return;
      }

      final drive = MbDriveService.instance;
      // Silent auth only during background backups (never a popup).
      if (drive.account == null) {
        final ok = await drive.tryRestoreSession();
        if (!ok) return;
      }

      // v2.2.0 rotation: keep the previous good copy as *-prev.mbbak before
      // the rolling *-latest.mbbak is overwritten — a truncated/failed PATCH
      // can no longer destroy the only remote backup.
      try {
        final remote = await drive.listBackups();
        final prev = remote.where((f) => f.name == _autoPrevName).toList();
        final latest = remote.where((f) => f.name == _autoFileName).toList();
        for (final p in prev) {
          await drive.deleteFile(p.id);
        }
        if (latest.isNotEmpty) {
          await drive.renameFile(latest.first.id, _autoPrevName);
        }
      } catch (_) {
        // rotation is best-effort — the upload itself must proceed
      }

      final backup = MbBackupService(state2.db);
      final path = await backup.createBackup(passphrase: pass);
      final bytes = await File(path).readAsBytes();
      await drive.uploadBackup(name: _autoFileName, bytes: bytes);

      // v2.2.0: the local .mbbak was never deleted — months of use left
      // hundreds of full encrypted snapshots in <documents>/backups/.
      try {
        await File(path).delete();
      } catch (_) {}

      _dirty = false;
      _lastUploadAt = DateTime.now();
      _lastAutoBackupAt = _lastUploadAt;
      _lastError = null;
      await state2.markBackupDone();
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setInt(
          _lastBackupKey, _lastAutoBackupAt!.millisecondsSinceEpoch);
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      debugPrint('MbAutoSyncService._backupNow: $e');
      notifyListeners();
    } finally {
      _uploading = false;
    }
  }

  /// App went to background — push pending changes NOW (if any).
  Future<void> flushOnPause() async {
    if (_debounce?.isActive ?? false) {
      _debounce?.cancel();
    }
    if (_dirty) {
      await _backupNow();
    }
  }

  /// Manual "sync now" (backup screen).
  Future<bool> syncNow() async {
    _dirty = true;
    await _backupNow();
    return _lastError == null && !_dirty;
  }

  // ── ২ auto-restore on login ─────────────────────────────────────────────

  /// v2.2.0: any local financial data — not just transactions. The old
  /// guard only checked `transactions.isNotEmpty`, so a user with only
  /// goals/budgets/contributions (no transactions yet) who signed into
  /// Google had them silently WIPED by the auto-restore's replaceAll.
  bool _hasLocalData(MbAppState state) =>
      state.transactions.isNotEmpty ||
      state.budgets.isNotEmpty ||
      state.goals.isNotEmpty ||
      state.contributions.isNotEmpty;

  /// Checks Drive for a backup right after Google Sign-In and restores it
  /// automatically when possible. See [MbAutoRestoreStatus] for outcomes.
  Future<MbAutoRestoreResult> maybeAutoRestoreOnLogin() async {
    final state = _state;
    if (state == null) {
      return const MbAutoRestoreResult(MbAutoRestoreStatus.failed);
    }
    if (!MbConfig.driveConfigured) {
      return const MbAutoRestoreResult(MbAutoRestoreStatus.notConfigured);
    }
    if (!state.googleLinked) {
      return const MbAutoRestoreResult(MbAutoRestoreStatus.notSignedIn);
    }
    if (_hasLocalData(state)) {
      // Local data wins — auto-restore only fills an empty device.
      return const MbAutoRestoreResult(MbAutoRestoreStatus.localDataPresent);
    }

    try {
      final drive = MbDriveService.instance;
      if (drive.account == null) {
        // In-app native popup (Google's own chooser/consent) — allowed here
        // because the user just performed a login.
        await drive.signIn();
        // v2.2.0: cancelling the account picker is NOT an error — return
        // silently (the old code fell through to listBackups() → notSignedIn
        // exception → “restore failed” toast for a deliberate cancel).
        if (drive.account == null) {
          return const MbAutoRestoreResult(MbAutoRestoreStatus.notSignedIn);
        }
      }
      final files = await drive.listBackups();
      if (files.isEmpty) {
        return const MbAutoRestoreResult(MbAutoRestoreStatus.noBackup);
      }

      final pass = _passCached;
      if (pass == null || pass.length < 6) {
        // Backup exists, but this install doesn't know the passphrase yet.
        return const MbAutoRestoreResult(MbAutoRestoreStatus.needsPassphrase);
      }
      return await restoreNewestWith(pass);
    } catch (e) {
      return MbAutoRestoreResult(MbAutoRestoreStatus.failed, error: '$e');
    }
  }

  /// Restore the newest remote backup with the given passphrase (used by
  /// the one-tap inline prompt). Optionally remembers it for future
  /// auto-backups.
  Future<MbAutoRestoreResult> restoreNewestWith(
    String pass, {
    bool remember = true,
  }) async {
    final state = _state;
    if (state == null) {
      return const MbAutoRestoreResult(MbAutoRestoreStatus.failed);
    }
    _restoring = true; // don't let the change-listener react to restore writes
    try {
      final drive = MbDriveService.instance;
      if (drive.account == null) {
        await drive.signIn();
        if (drive.account == null) {
          // v2.2.0: user cancelled the account picker — not an error.
          return const MbAutoRestoreResult(MbAutoRestoreStatus.notSignedIn);
        }
      }
      final files = await drive.listBackups();
      if (files.isEmpty) {
        return const MbAutoRestoreResult(MbAutoRestoreStatus.noBackup);
      }
      final bytes = await drive.downloadFile(files.first.id);
      final payload = await MbBackupService.decryptBackup(
        passphrase: pass,
        bytes: bytes,
      );
      final stats = await MbBackupService(state.db).replaceAll(payload);
      await state.init(); // re-read everything + notify listeners
      if (remember) {
        await rememberPassphrase(pass);
      }
      return MbAutoRestoreResult(MbAutoRestoreStatus.restored, stats: stats);
    } on MbBackupException catch (e) {
      return MbAutoRestoreResult(MbAutoRestoreStatus.failed, error: '$e');
    } on MbDriveException catch (e) {
      return MbAutoRestoreResult(MbAutoRestoreStatus.failed, error: e.message);
    } catch (e) {
      return MbAutoRestoreResult(MbAutoRestoreStatus.failed, error: '$e');
    } finally {
      _restoring = false;
      _dirty = false;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
