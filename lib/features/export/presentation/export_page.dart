import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../export_providers.dart';

/// More > Export data: CSV files shared through the Android share sheet.
class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  var _transactions = true;
  var _khata = true;
  var _busy = false;

  Future<void> _share() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await exportCsv(ref.read, transactions: _transactions, khata: _khata);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Export failed. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final note = AppTypography.supporting.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Export data')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          Text(
            'Creates CSV files you can open in Sheets or Excel, then lets you '
            'pick where to send or save them.',
            style: note,
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  value: _transactions,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _transactions = value),
                  secondary: const Icon(Icons.receipt_long_outlined),
                  title: const Text('Transactions'),
                  subtitle: const Text(
                    'All dates, every Account. Scheduled ones are marked; '
                    'Trash is left out.',
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _khata,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _khata = value),
                  secondary: const Icon(Icons.handshake_outlined),
                  title: const Text('MyKhata'),
                  subtitle: const Text(
                    'Entries and repayments, in a separate file.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Amounts are always included, even with Hide amounts on. Files '
            'stay on this device until you share them.',
            style: note,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Share CSV',
            icon: Icons.ios_share_rounded,
            loading: _busy,
            onPressed: (_transactions || _khata) && !_busy ? _share : null,
          ),
        ],
      ),
    );
  }
}
