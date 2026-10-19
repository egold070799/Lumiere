/*
 *     Copyright (C) 2026 Valeri Gokadze
 *     Modified for Lumiere by egold070799, 2026
 *
 *     Lumiere is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Lumiere is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Lumiere, including how to contribute,
 *     please visit: https://github.com/egold070799/Lumiere
 */

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:audio_service/audio_service.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lumiere/constants/app_constants.dart';
import 'package:lumiere/extensions/l10n.dart';
import 'package:lumiere/localization/app_localizations.dart';
import 'package:lumiere/services/audio_service.dart';
import 'package:lumiere/services/data_manager.dart';
import 'package:lumiere/services/io_service.dart';
import 'package:lumiere/services/listening_stats_service.dart';
import 'package:lumiere/services/logger_service.dart';
import 'package:lumiere/services/playlist_sharing.dart';
import 'package:lumiere/services/playlists_manager.dart';
import 'package:lumiere/services/router_service.dart';
import 'package:lumiere/services/settings_manager.dart';
import 'package:lumiere/services/update_manager.dart';
import 'package:lumiere/theme/app_themes.dart';
import 'package:lumiere/utilities/flutter_toast.dart';
import 'package:lumiere/utilities/language_utils.dart';
import 'package:lumiere/utilities/platform_utils.dart';
import 'package:lumiere/utilities/playlist_utils.dart';
import 'package:lumiere/utilities/sharing_intent.dart';
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

late LumiereAudioHandler audioHandler;
StreamSubscription<String?>? sharingIntentSubscription;
StreamSubscription<Uri?>? appLinksSubscription;

final logger = Logger();
final appLinks = AppLinks();

bool isFdroidBuild = false;
bool isUpdateChecked = false;

class Lumiere extends StatefulWidget {
  const Lumiere({super.key});

  static Future<void> updateAppState(
    BuildContext context, {
    ThemeMode? newThemeMode,
    Locale? newLocale,
    Color? newAccentColor,
    bool? useSystemColor,
  }) async {
    context.findAncestorStateOfType<_LumiereState>()!.changeSettings(
      newThemeMode: newThemeMode,
      newLocale: newLocale,
      newAccentColor: newAccentColor,
      systemColorStatus: useSystemColor,
    );
  }

  @override
  _LumiereState createState() => _LumiereState();
}

class _LumiereState extends State<Lumiere> with WidgetsBindingObserver {
  void changeSettings({
    ThemeMode? newThemeMode,
    Locale? newLocale,
    Color? newAccentColor,
    bool? systemColorStatus,
  }) {
    setState(() {
      if (newThemeMode != null) {
        themeMode = newThemeMode;
        brightness = getBrightnessFromThemeMode(newThemeMode);
      }
      if (newLocale != null) {
        languageSetting = newLocale;
      }
      if (newAccentColor != null) {
        if (systemColorStatus != null &&
            useSystemColor.value != systemColorStatus) {
          useSystemColor.value = systemColorStatus;
          addOrUpdateData<bool>(
            'settings',
            'useSystemColor',
            systemColorStatus,
          );
        }
        primaryColorSetting = newAccentColor;
      }
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    if (isMobilePlatform) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    final platformDispatcher = PlatformDispatcher.instance;

    // This callback is called every time the brightness changes.
    platformDispatcher.onPlatformBrightnessChanged = () {
      if (themeMode == ThemeMode.system) {
        setState(() {
          brightness = platformDispatcher.platformBrightness;
        });
      }
    };

    offlineMode.addListener(_onOfflineModeChanged);

    if (isMobilePlatform) {
      sharingIntentSubscription = ReceiveSharingIntent.getTextStream().listen(
        (String? value) async {
          await consumeYoutubeSharedTextIntent(
            value,
            audioHandler: audioHandler,
            onError: (error, stackTrace) {
              logger.log(
                'Error while playing shared song:',
                error: error,
                stackTrace: stackTrace,
              );
            },
          );
        },
        onError: (err) {
          logger.log('getTextStream error:', error: err);
        },
      );
    }

    if (!isFdroidBuild && isMobilePlatform) {
      if (shouldWeCheckUpdates.value == true) {
        if (!isUpdateChecked && kReleaseMode) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (!offlineMode.value) {
              checkAppUpdates();
            }
            isUpdateChecked = true;
          });
        }
      } else {
        if (shouldWeCheckUpdates.value == null) {
          // show dialog that asks user if they want to enable update checks
          SchedulerBinding.instance.addPostFrameCallback((_) {
            showUpdateCheckDialog(NavigationManager().context);
          });
        } else {
          SchedulerBinding.instance.addPostFrameCallback((_) async {
            if (!offlineMode.value) {
              await fetchAnnouncementOnly();
            }
          });
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Persist listening stats when the app leaves the foreground. This is the
    // reliable moment to snapshot and flush: unlike widget dispose, these
    // callbacks are delivered before the OS suspends or terminates the process.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      listeningStatsService.recordListeningSessionProgress(
        wasPlaying: audioHandler.audioPlayer.playing,
      );
      unawaited(listeningStatsService.flush());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    offlineMode.removeListener(_onOfflineModeChanged);
    PlatformDispatcher.instance.onPlatformBrightnessChanged = null;

    Hive.close();
    unawaited(sharingIntentSubscription?.cancel());
    unawaited(appLinksSubscription?.cancel());
    super.dispose();
  }

  void _onOfflineModeChanged() {
    // Force rebuild when offline mode changes
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (systemLightColorScheme, systemDarkColorScheme) {
        final lightColorScheme = getAppColorScheme(
          systemLightColorScheme,
          systemDarkColorScheme,
          targetBrightness: Brightness.light,
        );
        final darkColorScheme = getAppColorScheme(
          systemLightColorScheme,
          systemDarkColorScheme,
          targetBrightness: Brightness.dark,
        );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: true,
            statusBarBrightness: brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
            statusBarIconBrightness: brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarIconBrightness: brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: MaterialApp.router(
            themeMode: themeMode,
            darkTheme: getAppTheme(darkColorScheme),
            theme: getAppTheme(lightColorScheme),
            localizationsDelegates: [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: appSupportedLocales,
            locale: languageSetting,
            routerConfig: NavigationManager.router,
          ),
        );
      },
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initialisation();

  runApp(const Lumiere());
}

Future<void> initialisation() async {
  try {
    await Hive.initFlutter();

    await Future.wait([
      Hive.openBox('settings'),
      Hive.openBox('user'),
      Hive.openBox('userNoBackup'),
      Hive.openBox('cache'),
    ]);

    // Apply Lumiere's dark visual direction once for existing installs too.
    // After this migration, the user's theme selection is left untouched.
    final settings = Hive.box('settings');
    const darkThemeMigrationKey = 'lumiereDarkThemeMigrationV1';
    if (settings.get(darkThemeMigrationKey, defaultValue: false) != true) {
      await settings.put('themeIndex', ThemeMode.dark.index);
      await settings.put(darkThemeMigrationKey, true);
    }

    if (isMobilePlatform) {
      audioHandler = await AudioService.init(
        builder: LumiereAudioHandler.new,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.egold070799.lumiere.playback',
          androidNotificationChannelName: appDisplayName,
          androidNotificationIcon: 'drawable/ic_launcher_foreground',
          androidShowNotificationBadge: true,
          androidStopForegroundOnPause: false,
          // Handed to Android Auto on the browsable root. Without the search
          // flag the car never offers a search box, and without the content
          // style keys it falls back to an undifferentiated list of everything.
          androidBrowsableRootExtras: {
            AndroidContentStyle.supportedKey: true,
            AndroidContentStyle.browsableHintKey:
                AndroidContentStyle.gridItemHintValue,
            AndroidContentStyle.playableHintKey:
                AndroidContentStyle.listItemHintValue,
            'android.media.browse.SEARCH_SUPPORTED': true,
          },
        ),
      );
    } else {
      // Use the desktop audio backend without mobile service plugins.
      JustAudioMediaKit.title = appDisplayName;
      JustAudioMediaKit.ensureInitialized();
      audioHandler = LumiereAudioHandler();
    }

    // Init router
    NavigationManager.instance;

    try {
      // Listen to incoming links while app is running
      appLinksSubscription = appLinks.uriLinkStream.listen(
        handleIncomingLink,
        onError: (err) {
          logger.log('URI link error:', error: err);
        },
      );
    } on PlatformException {
      logger.log('Failed to get initial uri');
    }

    if (isFdroidBuild && !offlineMode.value) {
      await fetchAnnouncementOnly();
    }
  } catch (e, stackTrace) {
    logger.log('Initialization Error', error: e, stackTrace: stackTrace);
  }

  applicationDirPath = (await getApplicationDocumentsDirectory()).path;
  await FilePaths.ensureDirectoriesExist();
}

void handleIncomingLink(Uri? uri) async {
  if (uri == null ||
      uri.scheme != appLinkScheme ||
      uri.host != 'playlist') {
    return;
  }

  if (uri.pathSegments.length < 2 || uri.pathSegments[0] != 'custom') return;

  try {
    final encodedPlaylist = uri.pathSegments[1];
    final playlist = await PlaylistSharingService.decodeAndExpandPlaylist(
      encodedPlaylist,
    );

    if (playlist == null) {
      _showPlaylistError();
      return;
    }

    // Ensure the incoming playlist has a unique id so it can be removed later
    if (playlist['ytid'] == null || playlist['ytid'].toString().isEmpty) {
      playlist['ytid'] = PlaylistUtils.generateCustomPlaylistId();
    }

    // Check for duplicate by title and song ytids
    final incomingYtids = (playlist['list'] as List<dynamic>)
        .map((s) => s['ytid'].toString())
        .toList();

    final isDuplicate = PlaylistUtils.playlistExists(
      playlist,
      incomingYtids,
      userCustomPlaylists.value,
    );

    if (isDuplicate) {
      showToast(
        NavigationManager().context,
        NavigationManager().context.l10n!.playlistAlreadyExists,
      );
    } else {
      userCustomPlaylists.value = [...userCustomPlaylists.value, playlist];
      unawaited(
        addOrUpdateData<List>(
          'user',
          'customPlaylists',
          userCustomPlaylists.value,
        ),
      );
      showToast(
        NavigationManager().context,
        '${NavigationManager().context.l10n!.addedSuccess}!',
      );
    }
  } catch (e) {
    _showPlaylistError();
  }
}

void _showPlaylistError() {
  showToast(
    NavigationManager().context,
    NavigationManager().context.l10n!.failedToLoadPlaylist,
  );
}
