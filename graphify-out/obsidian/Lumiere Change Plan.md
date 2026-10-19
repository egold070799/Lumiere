---
title: Lumiere Change Plan
tags: [lumiere, plan, migration, ui]
---

# Lumiere change plan

## Working decisions and current baseline

Lumiere is a separate music app based on this codebase. The current visual direction is a dark, deep-green graphite interface with warm brass and slate accents, serif display headings, a neutral Roboto interface, compact component shapes, and a paper-like light theme as an option. Lumiere display labels, the Android ID `com.egold070799.lumiere`, and the GitHub updater target `egold070799/Lumiere` are in place. Existing Lumiere playlist links remain accepted for compatibility. The update feed and release assets still need to be added to that repository before in-app updates can install releases.

The current UI implementation establishes separate light/dark color schemes, makes dark mode the default for new installs, keeps dynamic system colors mapped to the matching brightness, adds a home-to-search shortcut, constrains home content on wide displays, and replaces the mini-player's wavy progress ring with a clean circular indicator. See [[Dark UI and Design System]] for the implementation map.

Implemented in the current workspace: adaptive launcher foreground monogram, Android/Windows/Linux labels, Android and Linux IDs, Lumiere share links, compatibility handling for old playlist links, GitHub-flavor run/build instructions, replacement of decorative cookie/clover artwork shapes with compact rounded-rectangle tiles, and decode-size limits for song and playlist artwork.

## Layout plan

### App shell

Keep the existing adaptive shell behavior: compact screens use a bottom navigation bar; widths of 600 px and above use a navigation rail with a restrained Lumiere mark. Keep the mini-player anchored above the navigation/content inset so it remains reachable across tabs. Apply the graphite, brass and steel palette with firmer typography and compact component radii.

### Suggested information architecture

Use four primary destinations, subject to product confirmation:

1. **Home** — personalized/recent listening, recommendations and radio entry points.
2. **Explore** — search, artists, albums and discovery.
3. **Library** — liked music, playlists/folders, downloads and listening history.
4. **Settings** — playback, appearance, offline behavior, imports and app details.

Map existing `HomePage`, `SearchPage`, `LibraryPage`, `RadioStationsPage`, and settings flows into these destinations. Keep Now Playing as a full-screen route/sheet reachable from the mini-player, not as a permanent fifth primary tab. Keep playlist, artist, album, recap, equalizer and import pages as contextual routes. In offline mode, make unavailable Explore content visibly unavailable and direct the user to downloaded/library content.

### Screen composition

- **Home:** Lumiere wordmark/header; prominent search affordance; one featured/recent listening section; horizontally browsable recommendation shelves; compact radio entry; consistent loading/empty states.
- **Explore:** search field at top; recent searches and suggestion state before query; results grouped by songs/artists/playlists; clear offline state.
- **Library:** filterable tabs or chips for playlists, liked songs, downloads and history; create/import action; folders visible in the playlist collection.
- **Now Playing:** large artwork, title/artist, progress and queue controls; secondary actions below; lyrics and queue as clear secondary panels. Reuse existing playback state and queue logic.
- **Settings:** grouped sections for playback, appearance, downloads/offline, data/import-export, and about. Use existing settings state unless a product decision requires new preferences.

## Code change layout

Keep a small brand/config layer around the existing feature architecture instead of renaming every Dart library import:

```text
lib/
  constants/
    app_constants.dart      # Lumiere display name and deep-link scheme
  theme/
    lumiere_tokens.dart     # palette, typography and shape tokens
    app_colors.dart         # user-selectable accent palette
    app_themes.dart         # shared theme assembly
  screens/                  # existing feature destinations, revised presentation
  services/                 # preserve playback, data, download and integration logic
```

Later, if both apps must ship from one repository, split brand-specific entry points/configuration from shared feature/core packages. Avoid scattering `if (isLumiere)` conditionals through feature widgets; choose identity/theme at the app boundary.

## Implementation phases

1. **Refine the visual system:** tune screens against the dark graphite palette, serif display headings, and sans-serif controls; preserve the light theme as an accessible option.
2. **Finish brand assets:** replace legacy raster launcher icons and check splash/store artwork across platforms.
3. **Wire releases:** add `update/check.json`, publish an APK release asset, and verify the updater against the Lumiere repo.
4. **Review data separation:** decide whether imported Lumiere data should be offered; Android already uses a distinct package sandbox.
5. **Review platform packaging:** confirm desktop install data paths, build flavors, F-Droid behavior, and release metadata.

## Compatibility-sensitive files

- Identity/build: `pubspec.yaml`, `lib/main.dart`, `lib/main_fdroid.dart`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, platform runner metadata, `fastlane/`.
- Shell and visual system: `lib/screens/bottom_navigation_page.dart`, `lib/services/router_service.dart`, `lib/theme/`, `lib/constants/app_constants.dart`, `lib/widgets/`.
- Persisted user state: `lib/services/data_manager.dart`, `settings_manager.dart`, `playlists_manager.dart`, `common_services.dart`, `io_service.dart`.
- Playback integrations: `lib/services/audio_service.dart`, `audio_service_android_auto.dart`, `lib/constants/clients.dart`.

## Decisions required before implementation

- Should existing Lumiere libraries/settings migrate, start clean, or offer an import choice?
- Should Lumiere keep every current feature, or is this a curated subset?

## Related notes

- [[Technologies and Files]]
- [[Performance and Optimization]]
- [[System Overview]]
- [[Startup and Navigation]]
- [[Playback Flow]]
