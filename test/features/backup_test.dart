import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/core/database/app_database.dart';
import 'package:my_accounts_manager/core/database/database_provider.dart';
import 'package:my_accounts_manager/core/time/today_provider.dart';
import 'package:my_accounts_manager/features/accounts/data/accounts_repository.dart';
import 'package:my_accounts_manager/features/backup/backup_providers.dart';
import 'package:my_accounts_manager/features/backup/data/backup_codec.dart';
import 'package:my_accounts_manager/features/backup/data/backup_repository.dart';
import 'package:my_accounts_manager/features/settings/data/settings_repository.dart';
import 'package:my_accounts_manager/features/transactions/data/transactions_repository.dart';

// Few PBKDF2 rounds keep the tests fast; the format is identical.
const _codec = BackupCodec(iterations: 1000);
const _foodId = '10000000-0000-4000-8000-000000000001';

void main() {
  final nov5 = DateTime.utc(2026, 11, 5).millisecondsSinceEpoch;

  // Restore tests copy between two in-memory databases on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<String> seed(AppDatabase db, {String name = 'Wallet'}) async {
    final accountId = await AccountsRepository(db).createAccount(name: name);
    await TransactionsRepository(db).createTransaction(
      accountId: accountId,
      categoryId: _foodId,
      type: 'expense',
      amountPaise: 45050,
      transactionDate: nov5,
      note: 'Lunch',
    );
    await SettingsRepository(db).setValue('appearance.theme_mode', 'dark');
    return accountId;
  }

  group('BackupCodec', () {
    final snapshot = BackupSnapshot(
      schemaVersion: 4,
      createdAt: nov5,
      tables: const {
        'accounts': [
          {'id': 'a1', 'name': 'Wallet', 'opening_balance_paise': 100},
        ],
      },
    );

    test('round-trips with the right password', () async {
      final bytes = await _codec.encode(snapshot, 'secret-1');
      final decoded = await _codec.decode(bytes, 'secret-1');
      expect(decoded.schemaVersion, 4);
      expect(decoded.createdAt, nov5);
      expect(decoded.tables, snapshot.tables);
    });

    test('keeps data unreadable without the password', () async {
      final bytes = await _codec.encode(snapshot, 'secret-1');
      expect(utf8.decode(bytes), isNot(contains('Wallet')));
      await expectLater(
        _codec.decode(bytes, 'wrong-pass'),
        throwsA(isA<BackupPasswordException>()),
      );
    });

    test('rejects foreign, damaged and newer-format files', () async {
      await expectLater(
        _codec.decode(utf8.encode('Date,Amount\n'), 'secret-1'),
        throwsA(isA<BackupFormatException>()),
      );
      final envelope =
          jsonDecode(utf8.decode(await _codec.encode(snapshot, 'secret-1')))
              as Map<String, Object?>;
      final tampered = {
        ...envelope,
        'payload': base64Encode([1, 2, 3, 4]),
      };
      await expectLater(
        _codec.decode(utf8.encode(jsonEncode(tampered)), 'secret-1'),
        throwsA(isA<BackupPasswordException>()),
      );
      final newer = {...envelope, 'version': 99};
      await expectLater(
        _codec.decode(utf8.encode(jsonEncode(newer)), 'secret-1'),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });

  group('BackupRepository', () {
    test('restores every table exactly, including Trash', () async {
      final accountId = await seed(database);
      final trashed = await TransactionsRepository(database).createTransaction(
        accountId: accountId,
        categoryId: _foodId,
        type: 'expense',
        amountPaise: 999,
        transactionDate: nov5,
      );
      await TransactionsRepository(database).softDeleteTransaction(trashed);
      final snapshot = await BackupRepository(database).snapshot();
      final decoded = await _codec.decode(
        await _codec.encode(snapshot, 'secret-1'),
        'secret-1',
      );

      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      await seed(target, name: 'Old phone data');
      await BackupRepository(target).restore(decoded);

      final restored = await BackupRepository(target).snapshot();
      expect(restored.tables, snapshot.tables);
      final accounts = await target.select(target.accounts).get();
      expect(accounts.single.name, 'Wallet');
      final transactions = await target.select(target.transactions).get();
      expect(transactions, hasLength(2));
      expect(transactions.where((row) => row.deletedAt != null), hasLength(1));
    });

    test('a bad row leaves the current data untouched', () async {
      await seed(database);
      final before = await BackupRepository(database).snapshot();
      final broken = BackupSnapshot(
        schemaVersion: 4,
        createdAt: nov5,
        tables: const {
          'transactions': [
            {'id': 't1', 'account_id': 'missing-account'},
          ],
        },
      );
      await expectLater(
        BackupRepository(database).restore(broken),
        throwsA(anything),
      );
      expect(
        (await BackupRepository(database).snapshot()).tables,
        before.tables,
      );
    });

    test('rejects unknown tables, columns and newer schemas', () {
      final repository = BackupRepository(database);
      for (final snapshot in [
        BackupSnapshot(
          schemaVersion: 4,
          createdAt: nov5,
          tables: const {'secrets': []},
        ),
        BackupSnapshot(
          schemaVersion: 4,
          createdAt: nov5,
          tables: const {
            'accounts': [
              {'id': 'a1', 'hacked': 1},
            ],
          },
        ),
        BackupSnapshot(schemaVersion: 99, createdAt: nov5, tables: const {}),
      ]) {
        expect(
          () => repository.validate(snapshot),
          throwsA(isA<BackupFormatException>()),
        );
      }
    });
  });

  group('BackupService', () {
    late ProviderContainer container;
    late Directory directory;
    late _MemoryFiles files;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('backup_test');
      files = _MemoryFiles();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          backupCodecProvider.overrideWithValue(_codec),
          backupFilesProvider.overrideWithValue(files),
          recoveryDirectoryProvider.overrideWith((ref) async => directory),
          todayProvider.overrideWithValue(nov5),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await directory.delete(recursive: true);
    });

    test('save, restore and undo through the recovery snapshot', () async {
      await seed(database);
      final service = container.read(backupServiceProvider);
      expect(await service.saveToDevice('secret-1'), isTrue);
      expect(files.saved.single.$1, endsWith('.khata'));
      final lastBackup = await SettingsRepository(
        database,
      ).watchValue(lastBackupSettingKey).first;
      expect(lastBackup, isNotNull);

      // Change the data, then restore the backup over it.
      await AccountsRepository(database).createAccount(name: 'Added later');
      final snapshot = await service.open(files.saved.single.$2, 'secret-1');
      expect(snapshot.count('accounts'), 1);
      await service.restore(snapshot);
      var names = (await database.select(database.accounts).get()).map(
        (row) => row.name,
      );
      expect(names, ['Wallet']);
      expect(await service.recoveryCreatedAt(), isNotNull);
      expect(
        await SettingsRepository(
          database,
        ).watchValue(lastBackupSettingKey).first,
        lastBackup,
      );

      // Undo brings back the data the restore replaced.
      await service.restoreRecovery();
      names = (await database.select(database.accounts).get()).map(
        (row) => row.name,
      );
      expect(names, containsAll(['Wallet', 'Added later']));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a cancelled save does not count as a backup', () async {
      files.accept = false;
      final service = container.read(backupServiceProvider);
      expect(await service.saveToDevice('secret-1'), isFalse);
      expect(
        await SettingsRepository(
          database,
        ).watchValue(lastBackupSettingKey).first,
        isNull,
      );
    });
  });
}

class _MemoryFiles implements BackupFiles {
  final saved = <(String, Uint8List)>[];
  var accept = true;

  @override
  Future<Uint8List?> pick() async => saved.lastOrNull?.$2;

  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    if (!accept) return false;
    saved.add((fileName, bytes));
    return true;
  }
}
