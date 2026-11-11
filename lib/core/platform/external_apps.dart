import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [uri] in another app (dialer, WhatsApp). False when nothing can
/// handle it. Overridden in tests.
final externalLauncherProvider = Provider<Future<bool> Function(Uri uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Shares plain text through the Android share sheet. Overridden in tests.
final textSharerProvider =
    Provider<Future<void> Function(String text, {String? subject})>(
      (ref) =>
          (text, {subject}) => SharePlus.instance.share(
            ShareParams(text: text, subject: subject),
          ),
    );
