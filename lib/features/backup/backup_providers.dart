import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/database/database_provider.dart';
import '../../core/time/today_provider.dart';
import '../export/export_providers.dart';
import '../recurring/recurring_providers.dart';
import '../settings/settings_providers.dart';
import 'data/backup_codec.dart';
import 'data/backup_repository.dart';

const lastBackupSettingKey = 'backup.last_at';

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => BackupRepository(ref.watch(appDatabaseProvider)),
);

final backupCodecProvider = Provider<BackupCodec>((ref) => const BackupCodec());

/// When this device last saved or shared a backup (UTC epoch ms).
final lastBackupAtProvider = StreamProvider<int?>((ref) {
  return ref
      .watch(settingsRepositoryProvider)
      .watchValue(lastBackupSettingKey)
      .map((value) => value == null ? null : int.tryParse(value));
});

/// Device file pickers. Overridden in tests.
abstract interface class BackupFiles {
  /// Lets the user choose where to save; false if they cancel.
  Future<bool> save(String fileName, Uint8List bytes);

  /// Lets the user choose a backup file; null if they cancel.
  Future<Uint8List?> pick();
}

class PlatformBackupFiles implements BackupFiles {
  const PlatformBackupFiles();

  @override
  Future<bool> save(String fileName, Uint8List bytes) async =>
      await FilePicker.saveFile(fileName: fileName, bytes: bytes) != null;

  @override
  Future<Uint8List?> pick() async {
    // Android has no MIME type for .khata, so the picker cannot filter by it.
    final file = await FilePicker.pickFile(dialogTitle: 'Choose a backup');
    return file?.readAsBytes();
  }
}

final backupFilesProvider = Provider<BackupFiles>(
  (ref) => const PlatformBackupFiles(),
);

/// App-private folder for the automatic pre-restore snapshot.
final recoveryDirectoryProvider = FutureProvider<Directory>((ref) async {
  final base = await getApplicationDocumentsDirectory();
  return Directory(p.join(base.path, 'backups')).create(recursive: true);
});

final backupServiceProvider = Provider<BackupService>(BackupService.new);

/// Backup and restore flows used by More > Backup & Restore.
class BackupService {
  BackupService(this._ref);

  final Ref _ref;

  static const _recoveryFileName = 'before_restore.json.gz';

  BackupRepository get _repository => _ref.read(backupRepositoryProvider);

  /// Encrypts the current data. Key derivation is CPU heavy, so it runs off
  /// the UI isolate.
  Future<Uint8List> create(String password) async {
    final snapshot = await _repository.snapshot();
    final codec = _ref.read(backupCodecProvider);
    return Isolate.run(() => codec.encode(snapshot, password));
  }

  String fileName(DateTime now) {
    String two(int value) => value.toString().padLeft(2, '0');
    return 'MyAccountsManager_${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}.${BackupCodec.extension}';
  }

  /// Returns false when the user cancels the save dialog.
  Future<bool> saveToDevice(String password) async {
    final bytes = await create(password);
    final saved = await _ref
        .read(backupFilesProvider)
        .save(fileName(DateTime.now()), bytes);
    if (saved) await _markBackedUp();
    return saved;
  }

  Future<void> share(String password) async {
    final bytes = await create(password);
    final directory = await _ref.read(exportDirectoryProvider.future);
    final file = await File(
      p.join(directory.path, fileName(DateTime.now())),
    ).writeAsBytes(bytes);
    await _ref.read(fileSharerProvider)([file], 'MyAccountsManager backup');
    await _markBackedUp();
  }

  Future<void> _markBackedUp() => _ref
      .read(settingsRepositoryProvider)
      .setValue(
        lastBackupSettingKey,
        '${DateTime.now().toUtc().millisecondsSinceEpoch}',
      );

  /// Decrypts and checks [bytes] without touching the database.
  Future<BackupSnapshot> open(Uint8List bytes, String password) async {
    final codec = _ref.read(backupCodecProvider);
    final snapshot = await Isolate.run(() => codec.decode(bytes, password));
    _repository.validate(snapshot);
    return snapshot;
  }

  /// Saves a recovery snapshot of the current data, then replaces it all
  /// with [snapshot].
  Future<void> restore(BackupSnapshot snapshot) async {
    final current = await _repository.snapshot();
    final lastBackup = await _ref
        .read(settingsRepositoryProvider)
        .watchValue(lastBackupSettingKey)
        .first;
    await (await _recoveryPath()).writeAsBytes(
      gzip.encode(utf8.encode(jsonEncode(current.toJson()))),
      flush: true,
    );
    await _replace(snapshot);
    // "Last backup" describes this device, not the restored data.
    if (lastBackup != null) {
      await _ref
          .read(settingsRepositoryProvider)
          .setValue(lastBackupSettingKey, lastBackup);
    }
  }

  /// When the pre-restore snapshot was taken, or null if there is none.
  Future<int?> recoveryCreatedAt() async {
    final file = await _recoveryPath();
    if (!await file.exists()) return null;
    try {
      return (await _readRecovery(file)).createdAt;
    } catch (_) {
      return null;
    }
  }

  /// Puts back the data from before the last restore. The data it replaces
  /// becomes the new recovery snapshot, so this can be undone the same way.
  Future<void> restoreRecovery() async {
    final file = await _recoveryPath();
    final snapshot = await _readRecovery(file);
    await restore(snapshot);
  }

  Future<BackupSnapshot> _readRecovery(File file) async =>
      BackupSnapshot.fromJson(
        jsonDecode(utf8.decode(gzip.decode(await file.readAsBytes()))),
      );

  Future<File> _recoveryPath() async {
    final directory = await _ref.read(recoveryDirectoryProvider.future);
    return File(p.join(directory.path, _recoveryFileName));
  }

  Future<void> _replace(BackupSnapshot snapshot) async {
    await _repository.restore(snapshot);
    try {
      // Bring restored recurring rules up to date right away.
      await _ref
          .read(recurringRepositoryProvider)
          .materializeDue(today: _ref.read(todayProvider));
    } catch (_) {
      // RecurringSync retries on the next resume.
    }
  }
}
