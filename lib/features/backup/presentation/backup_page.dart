import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../backup_providers.dart';
import '../data/backup_codec.dart';

const _accent = Color(0xFF0EA5E9);

/// Local date and time of a UTC epoch-millisecond instant.
String formatBackupInstant(int timestamp) {
  final local = DateTime.fromMillisecondsSinceEpoch(timestamp);
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '${AuditTimestamp.formatLocalDate(timestamp)}, $hour:$minute $period';
}

/// More > Backup & Restore: password-encrypted `.khata` files.
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  /// What is running, shown under the buttons; null when idle.
  String? _busy;
  int? _recoveryAt;

  @override
  void initState() {
    super.initState();
    _loadRecovery();
  }

  Future<void> _loadRecovery() async {
    try {
      final at = await ref.read(backupServiceProvider).recoveryCreatedAt();
      if (mounted) setState(() => _recoveryAt = at);
    } catch (_) {
      // No recovery snapshot to offer.
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(String label, Future<void> Function() work) async {
    setState(() => _busy = label);
    try {
      await work();
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _backup({required bool share}) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordDialog(create: true),
    );
    if (password == null || !mounted) return;
    await _run('Encrypting your data…', () async {
      final service = ref.read(backupServiceProvider);
      try {
        if (share) {
          await service.share(password);
          if (mounted) _toast('Backup ready to share');
        } else if (await service.saveToDevice(password)) {
          if (mounted) _toast('Backup saved');
        }
      } catch (_) {
        if (mounted) _toast('Backup failed. Try again.');
      }
    });
  }

  Future<void> _restoreFromFile() async {
    final service = ref.read(backupServiceProvider);
    final bytes = await ref.read(backupFilesProvider).pick();
    if (bytes == null || !mounted) return;
    BackupSnapshot? snapshot;
    String? error;
    // Ask again after a wrong password instead of starting over.
    while (snapshot == null) {
      if (!mounted) return;
      final password = await showDialog<String>(
        context: context,
        builder: (_) => _PasswordDialog(create: false, error: error),
      );
      if (password == null || !mounted) return;
      await _run('Opening backup…', () async {
        try {
          snapshot = await service.open(bytes, password);
        } on BackupPasswordException {
          error = 'Wrong password, or the file is damaged.';
        } on BackupFormatException catch (exception) {
          error = null;
          if (mounted) _toast(exception.message);
        } catch (_) {
          error = null;
          if (mounted) _toast('Could not read that file.');
        }
      });
      if (error == null && snapshot == null) return;
    }
    if (snapshot == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _RestorePreviewDialog(snapshot: snapshot!),
    );
    if (confirmed != true || !mounted) return;
    await _replaceData(() => service.restore(snapshot!), 'Backup restored');
  }

  Future<void> _undoRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Undo last restore?'),
        content: Text(
          'Brings back your data as it was on '
          '${formatBackupInstant(_recoveryAt!)}, just before the last '
          'restore. What is on the phone now is kept as the new undo point.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Undo restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _replaceData(
      () => ref.read(backupServiceProvider).restoreRecovery(),
      'Previous data restored',
    );
  }

  Future<void> _replaceData(Future<void> Function() work, String done) {
    return _run('Restoring…', () async {
      try {
        await work();
        if (mounted) _toast(done);
      } catch (_) {
        if (mounted) {
          _toast('Restore failed. Your data has not changed.');
        }
      }
      await _loadRecovery();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final note = AppTypography.supporting.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final lastBackup = ref.watch(lastBackupAtProvider).valueOrNull;
    final busy = _busy != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          _StatusCard(lastBackup: lastBackup),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Create a backup'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Point(
                  icon: Icons.inventory_2_outlined,
                  text:
                      'Everything: Accounts, transactions and Trash, '
                      'categories, MyKhata, recurring, budget and settings.',
                ),
                const _Point(
                  icon: Icons.lock_outline_rounded,
                  text:
                      'Encrypted with a password you choose. Without it, '
                      'nobody can open the file, including you.',
                ),
                const _Point(
                  icon: Icons.save_alt_rounded,
                  text:
                      'Save it to Downloads or Drive, or share it to '
                      'yourself. Keep it off this phone.',
                ),
                const SizedBox(height: AppSpacing.sm),
                PrimaryButton(
                  label: 'Save to device',
                  icon: Icons.download_rounded,
                  onPressed: busy ? null : () => _backup(share: false),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _backup(share: true),
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('Share backup'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Restore'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replaces all data on this phone with a .khata backup. '
                  'You see what is inside before anything changes, and the '
                  'current data is kept so you can undo.',
                  style: note,
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _restoreFromFile,
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Restore from file'),
                  ),
                ),
              ],
            ),
          ),
          if (_recoveryAt != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                enabled: !busy,
                onTap: _undoRestore,
                leading: Icon(Icons.undo_rounded, color: scheme.primary),
                title: const Text('Undo last restore'),
                subtitle: Text(
                  'Data from ${formatBackupInstant(_recoveryAt!)}',
                  style: note,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          ],
          if (busy) ...[
            const SizedBox(height: AppSpacing.lg),
            const LinearProgressIndicator(),
            const SizedBox(height: AppSpacing.sm),
            Text(_busy!, style: note, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.lastBackup});

  final int? lastBackup;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final none = lastBackup == null;
    final color = none ? const Color(0xFFF59E0B) : _accent;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              none ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  none ? 'No backup yet' : 'Last backup',
                  style: AppTypography.fieldValue.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  none
                      ? 'Your data lives only on this phone. Make a backup '
                            'so a lost or reset phone does not take it with it.'
                      : formatBackupInstant(lastBackup!),
                  style: AppTypography.supporting.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: _accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.supporting.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks for a backup password. [create] adds a confirm field and the
/// minimum length rule; returns the password, or null on cancel.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.create, this.error});

  final bool create;
  final String? error;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final toggle = IconButton(
      tooltip: _obscure ? 'Show password' : 'Hide password',
      onPressed: () => setState(() => _obscure = !_obscure),
      icon: Icon(
        _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
      ),
    );
    return AlertDialog(
      title: Text(widget.create ? 'Set a backup password' : 'Enter password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.create
                  ? 'You need this password to restore. It cannot be '
                        'recovered if you forget it.'
                  : 'The password used when this backup was made.',
              style: AppTypography.supporting.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _password,
              autofocus: true,
              obscureText: _obscure,
              enableSuggestions: false,
              autocorrect: false,
              textInputAction: widget.create
                  ? TextInputAction.next
                  : TextInputAction.done,
              onFieldSubmitted: widget.create ? null : (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: toggle,
                errorText: widget.error,
              ),
              validator: (value) {
                final text = value ?? '';
                if (text.isEmpty) return 'Enter the password';
                if (widget.create &&
                    text.length < BackupCodec.minPasswordLength) {
                  return 'Use at least ${BackupCodec.minPasswordLength} '
                      'characters';
                }
                return null;
              },
            ),
            if (widget.create) ...[
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
                validator: (value) =>
                    value == _password.text ? null : 'Passwords do not match',
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.create ? 'Create backup' : 'Open'),
        ),
      ],
    );
  }
}

class _RestorePreviewDialog extends StatelessWidget {
  const _RestorePreviewDialog({required this.snapshot});

  final BackupSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = [
      ('Accounts', snapshot.count('accounts')),
      ('Transactions', snapshot.count('transactions')),
      ('Categories', snapshot.count('categories')),
      ('MyKhata people', snapshot.count('khata_people')),
      ('MyKhata entries', snapshot.count('khata_entries')),
      ('Recurring rules', snapshot.count('recurring_rules')),
    ];
    return AlertDialog(
      title: const Text('Restore this backup?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Made on ${formatBackupInstant(snapshot.createdAt)}',
            style: AppTypography.supporting.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (label, count) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(child: Text(label)),
                  Text(
                    '$count',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'All data on this phone will be replaced. You can undo this '
            'from Backup & Restore.',
            style: AppTypography.supporting.copyWith(color: scheme.error),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Replace my data'),
        ),
      ],
    );
  }
}
