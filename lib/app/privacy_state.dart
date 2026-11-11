import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/settings_providers.dart';

const amountsHiddenSettingKey = 'privacy.amounts_hidden';

final storedAmountsHiddenProvider = StreamProvider<bool>((ref) {
  return ref
      .watch(settingsRepositoryProvider)
      .watchValue(amountsHiddenSettingKey)
      .map((value) => value == 'true');
});

/// Presentation-only privacy preference for monetary values, saved on the
/// device so it survives restarts.
final amountsHiddenProvider = NotifierProvider<AmountsHiddenNotifier, bool>(
  AmountsHiddenNotifier.new,
);

class AmountsHiddenNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(storedAmountsHiddenProvider).valueOrNull ?? false;

  Future<void> set(bool hidden) {
    state = hidden;
    return ref
        .read(settingsRepositoryProvider)
        .setValue(amountsHiddenSettingKey, '$hidden');
  }
}
