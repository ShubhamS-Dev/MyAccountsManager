import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Every row of every table, as plain column maps keyed by SQL column name.
class BackupSnapshot {
  const BackupSnapshot({
    required this.schemaVersion,
    required this.createdAt,
    required this.tables,
  });

  final int schemaVersion;

  /// UTC epoch milliseconds.
  final int createdAt;
  final Map<String, List<Map<String, Object?>>> tables;

  int count(String table) => tables[table]?.length ?? 0;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'createdAt': createdAt,
    'tables': tables,
  };

  static BackupSnapshot fromJson(Object? json) {
    if (json is! Map<String, Object?>) throw const BackupFormatException();
    final schemaVersion = json['schemaVersion'];
    final createdAt = json['createdAt'];
    final tables = json['tables'];
    if (schemaVersion is! int || createdAt is! int || tables is! Map) {
      throw const BackupFormatException();
    }
    final parsed = <String, List<Map<String, Object?>>>{};
    for (final MapEntry(:key, :value) in tables.entries) {
      if (key is! String || value is! List) {
        throw const BackupFormatException();
      }
      parsed[key] = [
        for (final row in value)
          row is Map<String, Object?>
              ? row
              : throw const BackupFormatException(),
      ];
    }
    return BackupSnapshot(
      schemaVersion: schemaVersion,
      createdAt: createdAt,
      tables: parsed,
    );
  }
}

/// The file is not a MyAccountsManager backup, or it is damaged.
class BackupFormatException implements Exception {
  const BackupFormatException([this.message = 'Not a valid backup file.']);
  final String message;
  @override
  String toString() => message;
}

/// The password does not open this backup.
class BackupPasswordException implements Exception {
  const BackupPasswordException();
}

/// Reads and writes password-encrypted `.khata` backup files.
///
/// The file is a small JSON envelope: PBKDF2-SHA256 derives an AES-256-GCM
/// key from the password, and the payload is the gzipped [BackupSnapshot]
/// JSON. GCM's tag rejects both a wrong password and a tampered file.
class BackupCodec {
  const BackupCodec({this.iterations = defaultIterations});

  static const defaultIterations = 120000;
  static const format = 'my-accounts-manager-backup';
  static const formatVersion = 1;
  static const extension = 'khata';
  static const minPasswordLength = 6;

  final int iterations;

  static final _cipher = AesGcm.with256bits();

  Future<Uint8List> encode(BackupSnapshot snapshot, String password) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final key = await _deriveKey(password, salt, iterations);
    final plain = gzip.encode(utf8.encode(jsonEncode(snapshot.toJson())));
    final box = await _cipher.encrypt(
      plain,
      secretKey: key,
      nonce: _cipher.newNonce(),
    );
    final envelope = {
      'format': format,
      'version': formatVersion,
      'createdAt': snapshot.createdAt,
      'kdf': {
        'name': 'pbkdf2-sha256',
        'iterations': iterations,
        'salt': base64Encode(salt),
      },
      'cipher': 'aes-256-gcm',
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'payload': base64Encode(box.cipherText),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  /// Throws [BackupFormatException] for a foreign or damaged file and
  /// [BackupPasswordException] when the password is wrong.
  Future<BackupSnapshot> decode(List<int> bytes, String password) async {
    final Map<String, Object?> envelope;
    try {
      envelope = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    } catch (_) {
      throw const BackupFormatException();
    }
    if (envelope['format'] != format) throw const BackupFormatException();
    if (envelope['version'] case final int version
        when version > formatVersion) {
      throw const BackupFormatException(
        'This backup was made by a newer version of the app. Update the app '
        'and try again.',
      );
    }
    final List<int> salt, nonce, mac, payload;
    final int rounds;
    try {
      final kdf = envelope['kdf'] as Map<String, Object?>;
      rounds = kdf['iterations'] as int;
      salt = base64Decode(kdf['salt'] as String);
      nonce = base64Decode(envelope['nonce'] as String);
      mac = base64Decode(envelope['mac'] as String);
      payload = base64Decode(envelope['payload'] as String);
    } catch (_) {
      throw const BackupFormatException();
    }
    final key = await _deriveKey(password, salt, rounds);
    final List<int> plain;
    try {
      plain = await _cipher.decrypt(
        SecretBox(payload, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
    } on SecretBoxAuthenticationError {
      throw const BackupPasswordException();
    }
    try {
      return BackupSnapshot.fromJson(
        jsonDecode(utf8.decode(gzip.decode(plain))),
      );
    } on BackupFormatException {
      rethrow;
    } catch (_) {
      throw const BackupFormatException();
    }
  }

  static Future<SecretKey> _deriveKey(
    String password,
    List<int> salt,
    int iterations,
  ) {
    return Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
  }
}
