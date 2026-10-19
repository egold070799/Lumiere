---
title: Technologies and Files
tags: [lumiere, technology, source-map]
---

# Technologies and files

Versions below are the constraints in `pubspec.yaml` (`^` means a compatible range); `pubspec.lock` records the resolved package versions for this checkout.

## Platform and language

- Flutter app, Dart SDK constraint `>=3.13.0 <4.0.0`, Flutter constraint `^3.47.7`.
- App package currently named `lumiere`, version `10.5.3+185`.
- Android, Windows, and Linux runners are present. Shared app code lives in `lib/`.
- UI is built with Flutter Material widgets plus `material_ui`; routing uses `go_router`.

## Main technologies

| Concern | Technology | Where used |
| --- | --- | --- |
| UI and app lifecycle | Flutter / Dart | `lib/main.dart`, `lib/screens/`, `lib/widgets/` |
| Navigation | `go_router ^18.1.0` | `lib/services/router_service.dart`, `lib/screens/bottom_navigation_page.dart` |
| Audio engine | `just_audio ^0.10.6` | Owned by `lib/services/audio_service.dart` |
| OS media controls/background audio | `audio_service ^0.18.19`, `audio_session ^0.2.4` | `lib/services/audio_service.dart`, `lib/services/audio_service_android_auto.dart` |
| Desktop audio backend | local `just_audio_media_kit` plus `media_kit` | `packages/just_audio_media_kit/`, startup in `lib/main.dart` |
| Persistence | `hive ^2.2.3`, `hive_flutter ^1.1.0` | `lib/services/data_manager.dart`, settings and feature services |
| Reactive stream composition | `rxdart ^0.28.0` | `lib/services/audio_service.dart` |
| Media catalog/stream resolution | local `youtube_explode_dart`, `youtube_music_explode_dart` | `packages/`, clients in `lib/constants/clients.dart`, helpers in `lib/services/common_services.dart` |
| Artwork/networking | `cached_network_image ^4.0.4`, `http ^1.6.0` | widgets, proxy and common services |
| Links and sharing | `app_links ^7.2.2`, local `receive_sharing_intent` | `lib/main.dart`, `lib/utilities/sharing_intent.dart`, Android manifest |
| Theming and colors | Flutter Material, `dynamic_color ^2.1.0`, `material_ui ^1.7.0` | `lib/theme/`, `lib/services/settings_manager.dart` |
| Localization | Flutter localization / generated ARB pipeline | `lib/localization/*.arb`, `lib/extensions/l10n.dart`, `l10n.yaml` |

Other direct dependencies are listed in [pubspec.yaml](../../pubspec.yaml); exact resolved versions are in [pubspec.lock](../../pubspec.lock).

## File map by change type

### App identity and startup

- `pubspec.yaml` — package name, version, dependencies and assets.
- `lib/main.dart`, `lib/main_fdroid.dart` — app startup and build variant.
- `android/app/build.gradle.kts`, Android manifests — Android package IDs, app metadata, intent filters and media service declaration.
- `assets/`, `fastlane/metadata/` — icons/resources and store metadata.

### Brand and design system

- `lib/theme/app_themes.dart`, `lib/theme/app_colors.dart` — theme construction and accent palette.
- `lib/constants/app_constants.dart` — app-level labels/constants.
- `lib/screens/bottom_navigation_page.dart` — responsive shell, navigation and mini-player placement.
- `lib/widgets/` — reusable component styling; `widgets/now_playing/` and `widgets/playlist_page/` are feature groups.

### Feature behavior

- Pages: `lib/screens/`.
- Core services: `lib/services/`.
- Data/value objects: `lib/models/`.
- Shared transformations: `lib/utilities/`.
- Bundled catalogs: `lib/database/`.
- Localization source: `lib/localization/*.arb`.

## Current main page set

`home_page.dart`, `search_page.dart`, `library_page.dart`, `radio_stations_page.dart`, `user_songs_page.dart`, `playlist_page.dart`, `playlist_folder_page.dart`, `artist_page.dart`, `now_playing_page.dart`, `time_machine_page.dart`, `settings_page.dart`, `equalizer_page.dart`, `import_spotify_playlist_page.dart`, and `about_page.dart`.

For how these pieces connect, see [[System Overview]] and [[Lumiere Change Plan]].
