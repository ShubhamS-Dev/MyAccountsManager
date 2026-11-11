import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../settings/settings_providers.dart';
import '../data/notification_gateway.dart';
import '../data/notification_preferences.dart';
import '../notifications_providers.dart';

/// Keeps the OS notification schedule in step with the database, opens the
/// right screen when a notification is tapped, and asks for permission once.
class ReminderSync extends ConsumerStatefulWidget {
  const ReminderSync({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ReminderSync> createState() => _ReminderSyncState();
}

class _ReminderSyncState extends ConsumerState<ReminderSync>
    with WidgetsBindingObserver {
  late final NotificationGateway _gateway = ref.read(
    notificationGatewayProvider,
  );

  @override
  void initState() {
    super.initState();
    if (!_gateway.supported) return;
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    await _gateway.initialize(onOpen: appRouter.push);
    if (!mounted) return;
    ref.listenManual(reminderPlanProvider, (_, plan) {
      plan.whenData(_gateway.replaceSchedule);
    }, fireImmediately: true);

    final launchRoute = await _gateway.launchRoute();
    if (launchRoute != null) appRouter.push(launchRoute);
    await _askPermissionOnce();
  }

  Future<void> _askPermissionOnce() async {
    final settings = ref.read(settingsRepositoryProvider);
    final asked = await settings.watchValue(permissionAskedKey).first;
    if (asked != null || !mounted) return;
    final status = await _gateway.status();
    if (!status.permitted) await _gateway.requestPermission();
    await settings.setValue(permissionAskedKey, 'true');
    if (mounted) ref.invalidate(notificationStatusProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Permissions or the clock may have changed while the app was away.
    ref.invalidate(notificationStatusProvider);
    ref.read(reminderPlanProvider).whenData(_gateway.replaceSchedule);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
