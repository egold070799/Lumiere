import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:lumiere/constants/version.dart';
import 'package:lumiere/extensions/l10n.dart';
import 'package:lumiere/main.dart';
import 'package:lumiere/services/data_manager.dart';
import 'package:lumiere/services/router_service.dart';
import 'package:lumiere/services/settings_manager.dart';
import 'package:lumiere/utilities/flutter_toast.dart';
import 'package:lumiere/utilities/platform_utils.dart';
import 'package:lumiere/widgets/auto_format_text.dart';
import 'package:path_provider/path_provider.dart';

const String checkUrl =
    'https://raw.githubusercontent.com/egold070799/Lumiere/main/update/check.json';
const String releasesUrl =
    'https://api.github.com/repos/egold070799/Lumiere/releases/latest';
const String downloadUrlKey = 'url';
const String downloadUrlArm64Key = 'arm64url';
const MethodChannel _updateChannel = MethodChannel(
  'com.egold070799.lumiere/app_update',
);

Future<void> checkAppUpdates() async {
  // This updater installs Android APKs. Other platforms use their own
  // distribution channels.
  if (!isAndroidPlatform) return;
  try {
    final response = await http.get(Uri.parse(checkUrl));

    if (response.statusCode != 200) {
      logger.log(
        'Fetch update API (checkUrl) call returned status code ${response.statusCode}',
      );
      return;
    }

    final map = json.decode(response.body) as Map<String, dynamic>;
    announcementURL.value = map['announcementurl'];
    final latestVersion = map['version'].toString();

    if (!isLatestVersionHigher(appVersion, latestVersion)) {
      return;
    }

    final releasesRequest = await http.get(Uri.parse(releasesUrl));

    if (releasesRequest.statusCode != 200) {
      logger.log(
        'Fetch update API (releasesUrl) call returned status code ${releasesRequest.statusCode}',
      );
      return;
    }

    final releasesResponse =
        json.decode(releasesRequest.body) as Map<String, dynamic>;

    await showDialog(
      context: NavigationManager().context,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;

        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  FluentIcons.arrow_download_24_regular,
                  color: colorScheme.onPrimaryContainer,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n!.appUpdateIsAvailable,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'V$latestVersion',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height / 2.5,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SingleChildScrollView(
                  child: AutoFormatText(text: releasesResponse['body']),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colorScheme.outline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(context.l10n!.cancel),
            ),
            FilledButton.icon(
              onPressed: () async {
                final url = await getDownloadUrl(map);
                Navigator.pop(context);
                await _downloadAndInstallUpdate(url, latestVersion);
              },
              icon: const Icon(FluentIcons.arrow_download_20_regular),
              label: Text(context.l10n!.download),
            ),
          ],
        );
      },
    );
  } catch (e, stackTrace) {
    logger.log('Error in checkAppUpdates', error: e, stackTrace: stackTrace);
  }
}

Future<void> _downloadAndInstallUpdate(String url, String version) async {
  final context = NavigationManager().context;
  try {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host != 'github.com') {
      throw const FormatException('The update URL is not a trusted HTTPS URL.');
    }

    final canInstall =
        await _updateChannel.invokeMethod<bool>('canInstallPackages') ?? false;
    if (!canInstall) {
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final colors = Theme.of(dialogContext).colorScheme;
          return AlertDialog(
            title: Text(dialogContext.l10n!.updateInstallPermissionTitle),
            content: Text(
              dialogContext.l10n!.updateInstallPermissionDescription,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(dialogContext.l10n!.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(dialogContext.l10n!.openSettings),
              ),
            ],
          );
        },
      );
      if (openSettings == true) {
        await _updateChannel.invokeMethod<void>(
          'openInstallPermissionSettings',
        );
      }
      return;
    }

    final progress = ValueNotifier<double?>(0);
    final status = ValueNotifier<String>(context.l10n!.updateDownloading);
    final client = http.Client();
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: ValueListenableBuilder<String>(
            valueListenable: status,
            builder: (context, value, _) => Text(value),
          ),
          content: ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (context, value, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: value),
                if (value != null) ...[
                  const SizedBox(height: 12),
                  Text('${(value * 100).round()}%'),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    File? apkFile;
    try {
      final temporaryDirectory = await getTemporaryDirectory();
      final safeVersion = version.replaceAll(RegExp(r'[^0-9.]'), '_');
      apkFile = File(
        '${temporaryDirectory.path}/lumiere-update-$safeVersion.apk',
      );
      if (await apkFile.exists()) await apkFile.delete();

      final response = await client
          .send(http.Request('GET', uri))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('APK download returned ${response.statusCode}.');
      }

      final totalBytes = response.contentLength;
      var receivedBytes = 0;
      final sink = apkFile.openWrite();
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 30),
        )) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes != null && totalBytes > 0) {
            progress.value = receivedBytes / totalBytes;
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (receivedBytes < 1024 * 1024 ||
          (totalBytes != null && receivedBytes != totalBytes)) {
        throw const FormatException('The downloaded APK is incomplete.');
      }
      final signature = await apkFile.openRead(0, 4).first;
      if (signature.length < 4 ||
          signature[0] != 0x50 ||
          signature[1] != 0x4b) {
        throw const FormatException('The downloaded file is not an APK.');
      }

      status.value = context.l10n!.updatePreparingInstall;
      progress.value = null;
      await _updateChannel.invokeMethod<void>('installApk', <String, Object>{
        'path': apkFile.path,
      });
    } finally {
      client.close();
      progress.dispose();
      status.dispose();
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (apkFile != null && await apkFile.exists()) {
        await apkFile.delete();
      }
    }
  } catch (error, stackTrace) {
    logger.log(
      'Failed to download or install app update',
      error: error,
      stackTrace: stackTrace,
    );
    if (context.mounted) {
      showToast(
        context,
        '${context.l10n!.updateDownloadFailed}\n$error',
        duration: const Duration(seconds: 8),
      );
    }
  }
}

void showUpdateCheckDialog(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        icon: Icon(
          FluentIcons.arrow_sync_circle_24_regular,
          color: colorScheme.primary,
          size: 40,
        ),
        title: Text(
          context.l10n!.checkForUpdates,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          context.l10n!.enableUpdateChecksDescription,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () {
              shouldWeCheckUpdates.value = false;
              addOrUpdateData<bool>('settings', 'shouldWeCheckUpdates', false);
              Navigator.of(context).pop();
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: colorScheme.outline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(context.l10n!.no),
          ),
          FilledButton(
            onPressed: () {
              shouldWeCheckUpdates.value = true;
              addOrUpdateData<bool>('settings', 'shouldWeCheckUpdates', true);
              if (!isFdroidBuild && kReleaseMode && !offlineMode.value) {
                checkAppUpdates();
                isUpdateChecked = true;
              }
              Navigator.of(context).pop();
            },
            child: Text(context.l10n!.yes),
          ),
        ],
      );
    },
  );
}

bool isLatestVersionHigher(String appVersion, String latestVersion) {
  final parsedAppVersion = appVersion.split('.');
  final parsedAppLatestVersion = latestVersion.split('.');
  final length = parsedAppVersion.length > parsedAppLatestVersion.length
      ? parsedAppVersion.length
      : parsedAppLatestVersion.length;
  for (var i = 0; i < length; i++) {
    final value1 = i < parsedAppVersion.length
        ? int.parse(parsedAppVersion[i])
        : 0;
    final value2 = i < parsedAppLatestVersion.length
        ? int.parse(parsedAppLatestVersion[i])
        : 0;
    if (value2 > value1) {
      return true;
    } else if (value2 < value1) {
      return false;
    }
  }

  return false;
}

Future<String> getDownloadUrl(Map<String, dynamic> map) async {
  final url = map[downloadUrlKey] ?? map[downloadUrlArm64Key];
  if (url is! String || url.isEmpty) {
    throw const FormatException('No Android APK URL is configured.');
  }
  return url;
}

/// Fetch only the announcement URL from the `check.json` file and set the
/// global `announcementURL` ValueNotifier. This does not trigger releases
/// fetching or any update dialogs/downloads and is safe to call for F‑Droid
/// builds where update prompts are not allowed.
Future<void> fetchAnnouncementOnly() async {
  try {
    final response = await http.get(Uri.parse(checkUrl));

    if (response.statusCode != 200) {
      logger.log(
        'Fetch announcement (checkUrl) call returned status code ${response.statusCode}',
      );
      return;
    }

    final map = json.decode(response.body) as Map<String, dynamic>;
    final ann = map['announcementurl'];
    if (ann != null) {
      announcementURL.value = ann.toString();
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error in fetchAnnouncementOnly',
      error: e,
      stackTrace: stackTrace,
    );
  }
}
