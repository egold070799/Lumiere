---
title: Feature and Package Map
tags: [lumiere, modules, packages]
---

# Feature and package map

## Application source (`lib/`)

| Directory | Responsibility |
| --- | --- |
| `screens/` | Full pages and navigation destinations: home, search, library, playlists, artists, settings, offline songs, and recaps. |
| `services/` | Shared application behavior and integrations: audio, playlists, settings, networking/proxy, lyrics, updates, sharing, downloads, and listening stats. |
| `widgets/` | Reusable visual components, including song/playlist rows, artwork, mini player, queue, and now-playing controls. |
| `utilities/` | Focused helpers for formatting, filtering, media-item conversion, paths/launching, platform behavior, queue entries, and dialogs. |
| `models/` | Small app-specific data types, including radio stations, position data, proxy info, and full-player state. |
| `database/` | Bundled seed data for playlists, albums, and radio stations. |
| `constants/` | Shared constants and client configuration. |
| `theme/` and `localization/` | Theme/color definitions and source translation files. |

## Local packages (`packages/`)

`pubspec.yaml` wires local packages by path:

- `just_audio_media_kit` — desktop media_kit backend integration for just_audio.
- `receive_sharing_intent` — local sharing-intent package.
- `youtube_explode_dart` and `youtube_music_explode_dart` — local media discovery/client packages used for metadata and stream access.

The application also depends on the published Flutter packages listed in `pubspec.yaml` (including audio_service, just_audio, Hive, go_router, and Flutter UI/localization packages).

## Platform runners and build variants

`android/`, `windows/`, and `linux/` contain platform-specific integration. `main_fdroid.dart` selects the F-Droid build behavior before delegating to the shared app startup. `assets/` contains app resources, while `fastlane/` contains release-store metadata and screenshots.

## Good entry points by task

- Startup or route issue → [[Startup and Navigation]]
- Queue/player issue → [[Playback Flow]]
- Data not persisting or cache behaving oddly → [[Persistence and State]]
- Locating a feature or dependency → this map and [[System Overview]]
