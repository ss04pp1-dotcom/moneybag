import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../core/palette.dart';
import '../services/auto_sync_service.dart';
import '../services/backup_service.dart';
import '../services/drive_service.dart';
import '../state/app_state.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';

/// Backup & restore — AES-256 encrypted `.mbbak` files locally, on share,
/// and (after one-time OAuth setup) directly to Google Drive.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MbAppState>();
    final L = context.L;
    final service = MbBackupService(state.db);

    return Scaffold(
      appBar: AppBar(
        title: Text(L.backupTitle),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: L.settingsBackup),
            Tab(text: L.settingsRestore),
            Tab(text: L.driveTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _CreateTab(state: state, service: service),
          _RestoreTab(state: state, service: service),
          _DriveTab(state: state, service: service),
        ],
      ),
    );
  }
}

class _CreateTab extends StatefulWidget {
  final MbAppState state;
  final MbBackupService service;

  const _CreateTab({required this.state, required this.service});

  @override
  State<_CreateTab> createState() => _CreateTabState();
}

class _CreateTabState extends State<_CreateTab> {
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _lastFile;

  @override
  void dispose() {
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final L = context.L;
    if (_pass.text.length < 6) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(L.backupPassShort)));
      return;
    }
    if (_pass.text != _pass2.text) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(L.backupPassMismatch)));
      return;
    }
    setState(() => _busy = true);
    try {
      final path = await widget.service.createBackup(passphrase: _pass.text);
      await widget.state.markBackupDone();
      setState(() => _lastFile = path);
      _pass.clear();
      _pass2.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L.backupCreatedTitle)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${L.error}: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MbAppState>();
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Text(L.backupIntro,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5)),
        const SizedBox(height: 20),
        Text(L.backupPassphrase,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: _pass,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            hintText: L.backupPassphraseHint,
            suffixIcon: IconButton(
              icon: Icon(_obscure
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(L.backupPassphraseRepeat,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: _pass2,
          obscureText: _obscure,
          decoration: InputDecoration(hintText: L.backupPassphraseHint),
        ),
        const SizedBox(height: 22),
        MbPressable(
          onTap: _busy ? null : _create,
          child: FilledButton.icon(
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Icon(Icons.lock_rounded),
            label: Text(_busy ? L.backupCreating : L.backupCreate),
            onPressed: _busy ? null : _create,
          ),
        ),
        const SizedBox(height: 24),
        if (_lastFile != null)
          MbFadeSlideIn(
            child: MbCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(L.backupCreatedTitle,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${L.backupStats}: ${state.transactions.length + state.goals.length + state.budgets.length + state.categories.length} · ${L.settingsVersion} 1',
                    style: TextStyle(
                        fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: Text(L.backupShare),
                    onPressed: () async {
                      await Share.shareXFiles([XFile(_lastFile!)],
                          subject: 'MoneyBag backup');
                    },
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            L.backupFormatNote,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _RestoreTab extends StatefulWidget {
  final MbAppState state;
  final MbBackupService service;

  const _RestoreTab({required this.state, required this.service});

  @override
  State<_RestoreTab> createState() => _RestoreTabState();
}

class _RestoreTabState extends State<_RestoreTab> {
  final _pass = TextEditingController();
  Map<String, dynamic>? _payload;
  String? _fileName;
  bool _replace = true;
  bool _busy = false;

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final L = context.L;
    final res = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    final path = res?.files.single.path;
    if (path == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await File(path).readAsBytes();
      final payload = await widget.service.readBackup(
        passphrase: _pass.text,
        bytes: bytes,
      );
      setState(() {
        _payload = payload;
        _fileName = path.split(Platform.pathSeparator).last;
      });
    } on MbBackupException catch (e) {
      if (!mounted) return;
      final msg = switch (e.error) {
        MbBackupError.wrongPassphrase => L.backupWrongPass,
        MbBackupError.invalid => L.backupInvalidFile,
        MbBackupError.corrupt => L.backupCorruptFile,
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e, stack) {
      debugPrint('Read backup failed: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(L.error)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final L = context.L;
    final p = _payload;
    if (p == null) return;
    setState(() => _busy = true);
    try {
      final stats = await widget.service.restore(p, replace: _replace);
      await widget.state.init();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(L.backupRestoredTitle),
          content: Text(
              '${L.backupRestoredBody}\n\n'
              '${L.txTitle}: ${stats.transactions}\n'
              '${L.categoriesTitle}: ${stats.categories}\n'
              '${L.budgetByCategory}: ${stats.budgets}\n'
              '${L.goalsTitle}: ${stats.goals}'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: Text(L.done),
            ),
          ],
        ),
      );
    } catch (e, stack) {
      debugPrint('Restore failed: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(L.error)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;
    final data = _payload?['data'] as Map<String, dynamic>?;
    final counts = <String, int>{
      if (data != null)
        for (final e in data.entries) e.key: (e.value as List).length,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Text(L.backupRestoreIntro,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5)),
        const SizedBox(height: 20),
        Text(L.backupPassphrase,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: _pass,
          obscureText: true,
          decoration: InputDecoration(hintText: L.backupPassphraseHint),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2))
              : const Icon(Icons.folder_open_rounded, size: 19),
          label: Text(_fileName ?? L.backupPickFile),
          onPressed: _busy ? null : _pick,
        ),
        const SizedBox(height: 20),
        if (_payload != null) ...[
          Text(L.backupRestoreMode,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          RadioListTile<bool>(
            value: true,
            groupValue: _replace,
            onChanged: (v) => setState(() => _replace = v ?? true),
            title: Text(L.backupModeReplace,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(L.backupModeReplaceHelp),
          ),
          RadioListTile<bool>(
            value: false,
            groupValue: _replace,
            onChanged: (v) => setState(() => _replace = v ?? false),
            title: Text(L.backupModeMerge,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(L.backupModeMergeHelp),
          ),
          const SizedBox(height: 8),
          MbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(L.backupStats,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  '${L.txTitle}: ${counts['transactions'] ?? 0}\n'
                  '${L.categoriesTitle}: ${counts['categories'] ?? 0}\n'
                  '${L.budgetByCategory}: ${counts['budgets'] ?? 0}\n'
                  '${L.goalsTitle}: ${counts['goals'] ?? 0}',
                  style: TextStyle(
                      fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: _replace
                ? FilledButton.styleFrom(
                    backgroundColor: MbPalette.danger,
                    foregroundColor: Colors.white)
                : null,
            onPressed: _busy ? null : _restore,
            child: Text(L.backupRestoreCta),
          ),
        ],
      ],
    );
  }
}

// ── Google Drive tab ────────────────────────────────────────────────────────

class _DriveTab extends StatefulWidget {
  final MbAppState state;
  final MbBackupService service;

  const _DriveTab({required this.state, required this.service});

  @override
  State<_DriveTab> createState() => _DriveTabState();
}

class _DriveTabState extends State<_DriveTab> {
  final _drive = MbDriveService.instance;
  final _pass = TextEditingController();
  bool _busy = false;
  bool _signedIn = false;
  GoogleSignInAccount? _account;
  List<MbDriveFile> _files = const [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!_drive.configured) return;
    setState(() => _busy = true);
    try {
      final ok = await _drive.tryRestoreSession();
      if (ok) {
        _account = _drive.account;
        _signedIn = true;
        await _refreshList();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshList() async {
    try {
      _files = await _drive.listBackups();
    } catch (_) {
      _files = const [];
    }
  }

  Future<void> _signIn() async {
    final L = context.L;
    setState(() => _busy = true);
    try {
      final acc = await _drive.signIn();
      if (acc != null) {
        _account = acc;
        _signedIn = true;
        await _refreshList();
      }
    } on MbDriveException catch (e) {
      _snack('${L.error}: ${e.message}');
    } catch (e) {
      _snack('${L.error}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await _drive.signOut();
    setState(() {
      _signedIn = false;
      _account = null;
      _files = const [];
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _backupNow() async {
    final L = context.L;
    if (_pass.text.length < 6) {
      _snack(L.backupPassShort);
      return;
    }
    final pass = _pass.text;
    setState(() => _busy = true);
    try {
      // 1) Create the encrypted envelope locally.
      final path =
          await widget.service.createBackup(passphrase: pass);
      final bytes = await File(path).readAsBytes();
      // 2) Upload ciphertext to the Drive app folder.
      final now = DateTime.now();
      final name =
          'moneybag-${now.year}${_two(now.month)}${_two(now.day)}-${_two(now.hour)}${_two(now.minute)}.mbbak';
      await _drive.uploadBackup(name: name, bytes: bytes);
      await widget.state.markBackupDone();
      await _refreshList();
      _snack(L.driveUploaded);
      _pass.clear();

      // First manual backup: offer to remember the passphrase so future
      // backups/restores become fully automatic (auto sync).
      if (!mounted) return;
      if (pass.length >= 6 &&
          !MbAutoSyncService.instance.hasRememberedPassphrase) {
        final remember = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(L.autoSyncRemember),
            content: Text(
              L.autoSyncRememberHelp,
              style: const TextStyle(
                  fontFamily: 'NotoSansBengali', fontSize: 13, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(L.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(L.ok),
              ),
            ],
          ),
        );
        if (remember == true) {
          await MbAutoSyncService.instance.rememberPassphrase(pass);
        }
      }
    } on MbDriveException catch (e) {
      _snack('${L.error}: ${e.message}');
    } catch (e) {
      _snack('${L.error}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  Future<void> _restoreFrom(MbDriveFile f) async {
    final L = context.L;
    setState(() => _busy = true);
    try {
      final bytes = await _drive.downloadFile(f.id);
      final payload = await widget.service.readBackup(
        passphrase: _pass.text,
        bytes: bytes,
      );
      if (!mounted) return;
      final replace = await _chooseMode();
      if (replace == null) {
        setState(() => _busy = false);
        return;
      }
      final stats = await widget.service.restore(payload, replace: replace);
      await widget.state.init();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(L.backupRestoredTitle),
          content: Text(
              '${L.backupRestoredBody}\n\n'
              '${L.txTitle}: ${stats.transactions}\n'
              '${L.categoriesTitle}: ${stats.categories}\n'
              '${L.budgetByCategory}: ${stats.budgets}\n'
              '${L.goalsTitle}: ${stats.goals}'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(L.done),
            ),
          ],
        ),
      );
      await _refreshList();
    } on MbBackupException catch (e) {
      final msg = switch (e.error) {
        MbBackupError.wrongPassphrase => L.backupWrongPass,
        MbBackupError.invalid => L.backupInvalidFile,
        MbBackupError.corrupt => L.backupCorruptFile,
      };
      _snack(msg);
    } on MbDriveException catch (e, stack) {
      debugPrint('Drive restore failed: $e\n$stack');
      _snack(L.driveRestoreFailed);
    } catch (e, stack) {
      debugPrint('Restore failed: $e\n$stack');
      _snack('${L.error}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Replace / Merge chooser; null = cancelled.
  Future<bool?> _chooseMode() async {
    final L = context.L;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L.backupRestoreMode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(L.backupModeReplace,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(L.backupModeReplaceHelp),
              onTap: () => Navigator.pop(ctx, true),
            ),
            ListTile(
              title: Text(L.backupModeMerge,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(L.backupModeMergeHelp),
              onTap: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(MbDriveFile f) async {
    final L = context.L;
    setState(() => _busy = true);
    try {
      await _drive.deleteFile(f.id);
      await _refreshList();
    } on MbDriveException catch (e) {
      _snack('${L.error}: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareFallback() async {
    final L = context.L;
    // v2.2.0: same minimum length as the primary backup path — this fallback
    // previously allowed an EMPTY passphrase (createBackup now also guards).
    if (_pass.text.trim().length < MbBackupService.minPassphraseLength) {
      _snack(L.backupPassShort);
      return;
    }
    setState(() => _busy = true);
    try {
      final path =
          await widget.service.createBackup(passphrase: _pass.text);
      await widget.state.markBackupDone();
      await Share.shareXFiles([XFile(path)], subject: 'MoneyBag backup');
    } catch (e) {
      _snack('${L.error}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;
    final state = widget.state;

    if (!_drive.configured) {
      // One-time OAuth setup guide + share-to-Drive fallback that works
      // immediately.
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          MbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_off_outlined, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(L.driveSetupNeeded,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(L.driveSetupNeededBody,
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 10),
                _step(context, '1', L.driveSetupStep1),
                _step(context, '2', L.driveSetupStep2),
                _step(context, '3', L.driveSetupStep3),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(L.backupPassphrase,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _pass,
            obscureText: true,
            decoration: InputDecoration(hintText: L.backupPassphraseHint),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4))
                : const Icon(Icons.ios_share_rounded),
            label: Text(L.driveShareAlt),
            onPressed: _busy ? null : _shareFallback,
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              L.driveShareAltHelp,
              style:
                  TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      );
    }

    if (!_signedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cloud_outlined,
                    size: 40, color: scheme.primary),
              ),
              const SizedBox(height: 16),
              Text(L.driveTab,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 17)),
              const SizedBox(height: 8),
              Text(
                L.driveIntro,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              _busy
                  ? const CircularProgressIndicator()
                  : FilledButton.icon(
                      icon: const Icon(Icons.login_rounded),
                      label: Text(L.driveSignIn),
                      onPressed: _signIn,
                    ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        // Account chip.
        MbCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: scheme.surfaceContainerHighest,
                backgroundImage: _account!.photoUrl == null
                    ? null
                    : NetworkImage(_account!.photoUrl!),
                child: _account!.photoUrl == null
                    ? const Icon(Icons.person_rounded)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(L.driveSignedInAs,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.onSurfaceVariant)),
                    if (_account!.displayName != null && _account!.displayName!.isNotEmpty)
                      Text(
                        _account!.displayName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    Text(
                      _account!.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: (_account!.displayName != null && _account!.displayName!.isNotEmpty) ? FontWeight.w400 : FontWeight.w700, 
                          fontSize: (_account!.displayName != null && _account!.displayName!.isNotEmpty) ? 12.5 : 14,
                          color: (_account!.displayName != null && _account!.displayName!.isNotEmpty) ? scheme.onSurfaceVariant : null),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: _signOut, child: Text(L.driveSignOut)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(L.driveIntro,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 16),

        // Backup now.
        Text(L.backupPassphrase,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: _pass,
          obscureText: true,
          decoration: InputDecoration(hintText: L.backupPassphraseHint),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          icon: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4))
              : const Icon(Icons.cloud_upload_rounded),
          label: Text(_busy ? L.driveUploading : L.driveBackupNow),
          onPressed: _busy ? null : _backupNow,
        ),
        const SizedBox(height: 24),

        // Auto sync (v2) — 5s debounced automatic backups on every change.
        _AutoSyncCard(onSynced: () => _snack(L.driveUploaded)),
        const SizedBox(height: 24),

        // Remote backups.
        MbSectionHeader(title: L.driveBackups),
        if (_files.isEmpty)
          MbCard(
            child: MbEmptyState(
              emoji: '☁️',
              title: L.driveNoBackups,
              body: L.driveIntro,
            ),
          )
        else
          for (final f in _files)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MbCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock_rounded,
                            size: 18, color: scheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                        ),
                        Text(
                          '${(f.sizeBytes / 1024).toStringAsFixed(1)} KB',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      MbFormat.relativeDays(
                          DateTime.now().difference(f.modified).inDays,
                          bangla: state.bangla),
                      style: TextStyle(
                          fontSize: 11.5, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.restore_rounded, size: 17),
                          label: Text(L.settingsRestore),
                          onPressed: _busy ? null : () => _restoreFrom(f),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: L.delete,
                          icon: Icon(Icons.delete_outline_rounded,
                              color: scheme.error),
                          onPressed: _busy ? null : () => _delete(f),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _step(BuildContext context, String n, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(n,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// Auto-sync card — the v2 hands-free layer shown on the Drive tab.
///
/// ON: 5 seconds after any save/delete the latest data is encrypted and
/// uploaded to Drive automatically (rate-limited, retried on next change).
/// Also shows the last auto-backup time and a manual "back up now" button.
class _AutoSyncCard extends StatefulWidget {
  final VoidCallback onSynced;
  const _AutoSyncCard({required this.onSynced});

  @override
  State<_AutoSyncCard> createState() => _AutoSyncCardState();
}

class _AutoSyncCardState extends State<_AutoSyncCard> {
  bool _busy = false;

  Future<void> _syncNow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await MbAutoSyncService.instance.syncNow();
      if (mounted && ok) widget.onSynced();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: MbAutoSyncService.instance,
      builder: (context, _) {
        final sync = MbAutoSyncService.instance;
        final last = sync.lastAutoBackupAt;

        return MbCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                secondary: Icon(
                  Icons.sync_rounded,
                  color: sync.autoSyncOn ? MbPalette.greenDeep : null,
                ),
                title: Text(L.autoSyncTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  L.autoSyncHelp,
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 12,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                value: sync.autoSyncOn,
                onChanged: (v) => MbAutoSyncService.instance.setAutoSync(v),
              ),
              Divider(color: scheme.outlineVariant, height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      sync.hasRememberedPassphrase
                          ? Icons.key_rounded
                          : Icons.key_off_rounded,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        last == null ? L.autoSyncLastNever : _lastText(last),
                        style: TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _busy ? null : _syncNow,
                      icon: _busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload_rounded, size: 18),
                      label: Text(sync.autoSyncOn
                          ? L.autoSyncNow
                          : L.autoSyncSyncing),
                    ),
                  ],
                ),
              ),
              if (sync.lastError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    sync.lastError!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _lastText(DateTime last) {
    final d = DateTime.now().difference(last);
    final bn = context.read<MbAppState>().bangla;
    if (d.inMinutes < 1) return bn ? 'এইমাত্র' : 'just now';
    if (d.inHours < 1) {
      return bn ? '${d.inMinutes} মিনিট আগে' : '${d.inMinutes}m ago';
    }
    if (d.inDays < 1) {
      return bn ? '${d.inHours} ঘণ্টা আগে' : '${d.inHours}h ago';
    }
    return bn ? '${d.inDays} দিন আগে' : '${d.inDays}d ago';
  }
}
