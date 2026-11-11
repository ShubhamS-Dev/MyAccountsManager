import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/time/today_provider.dart';
import '../my_khata/khata_providers.dart';
import '../transactions/transactions_providers.dart';
import 'data/csv_export.dart';

/// Hands finished files to the Android share sheet. Overridden in tests.
typedef FileSharer = Future<void> Function(List<File> files, String subject);

final fileSharerProvider = Provider<FileSharer>(
  (ref) =>
      (files, subject) => SharePlus.instance.share(
        ShareParams(
          files: [
            for (final file in files) XFile(file.path, mimeType: 'text/csv'),
          ],
          subject: subject,
        ),
      ),
);

/// Where export files are written before sharing; the OS may clear it.
final exportDirectoryProvider = FutureProvider<Directory>((ref) async {
  final base = await getTemporaryDirectory();
  return Directory(p.join(base.path, 'exports')).create(recursive: true);
});

/// Reads a provider; `ref.read` from a widget or a ProviderContainer.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// Writes the selected CSV files and opens the share sheet. Returns the
/// number of files shared.
Future<int> exportCsv(
  ProviderReader read, {
  required bool transactions,
  required bool khata,
}) async {
  final today = read(todayProvider);
  final stamp = CsvExport.isoDate(today).replaceAll('-', '');
  final directory = await read(exportDirectoryProvider.future);
  final files = <File>[];
  if (transactions) {
    final items = await read(
      transactionsRepositoryProvider,
    ).watchHistory().first;
    files.add(
      await File(
        p.join(directory.path, 'transactions_$stamp.csv'),
      ).writeAsString(CsvExport.transactions(items, today)),
    );
  }
  if (khata) {
    final repository = read(khataRepositoryProvider);
    final entries = await repository.watchEntries().first;
    final repayments = await repository.activeRepayments();
    files.add(
      await File(
        p.join(directory.path, 'mykhata_$stamp.csv'),
      ).writeAsString(CsvExport.khata(entries, repayments, today)),
    );
  }
  if (files.isEmpty) return 0;
  await read(fileSharerProvider)(files, 'MyAccountsManager export');
  return files.length;
}
