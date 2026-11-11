import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/today_provider.dart';
import '../recurring_providers.dart';

/// Saves due recurring occurrences when the app starts, resumes, and rolls
/// over midnight.
class RecurringSync extends ConsumerStatefulWidget {
  const RecurringSync({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RecurringSync> createState() => _RecurringSyncState();
}

class _RecurringSyncState extends ConsumerState<RecurringSync>
    with WidgetsBindingObserver {
  Future<void>? _running;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(todayProvider, (_, _) => _sync(), fireImmediately: true);
  }

  Future<void> _sync() {
    // Coalesce overlapping triggers; the repository is safe either way.
    return _running ??= () async {
      try {
        await ref
            .read(recurringRepositoryProvider)
            .materializeDue(today: ref.read(todayProvider));
      } catch (_) {
        // Retried on the next resume; never block the app.
      } finally {
        _running = null;
      }
    }();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
