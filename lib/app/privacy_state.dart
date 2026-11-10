import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared presentation-only privacy preference for monetary values.
final amountsHiddenProvider = StateProvider<bool>((ref) => false);
