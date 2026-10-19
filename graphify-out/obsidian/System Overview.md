---
title: System Overview
tags: [lumiere, architecture]
---

# System overview

Lumiere is a Flutter music app derived from Lumiere. `pubspec.yaml` identifies the application package and its Flutter dependencies. The app is primarily under `lib/`, with platform runners under `android/`, `windows/`, and `linux/`, and several local Dart packages under `packages/`.

## Runtime layers

1. **Composition and lifecycle** — [main.dart](../../lib/main.dart) opens storage, creates the audio handler, initializes navigation and link handling, then mounts `Lumiere`.
2. **Navigation and screens** — [router_service.dart](../../lib/services/router_service.dart) creates a `GoRouter` with a stateful tab shell. Screen widgets live in `lib/screens/`.
3. **Domain and integration services** — `lib/services/` contains playback, playlists, remote discovery, downloads, settings, proxying, lyrics, updates, and listening statistics.
4. **Persistence and shared state** — Hive boxes are opened at startup. Service modules expose `ValueNotifier`s and persist through [data_manager.dart](../../lib/services/data_manager.dart) or their direct box access.
5. **Presentation building blocks** — reusable controls and layouts live under `lib/widgets/`; shared formatting, filtering, platform and media helpers live in `lib/utilities/`.

## Key runtime relationships

- `main.dart` imports and wires `LumiereAudioHandler`, `NavigationManager`, settings, playlists, listening stats, link handling, and file paths.
- Screens generally consume state from services and compose reusable widgets; services can call other services and utilities.
- `LumiereAudioHandler` wraps `just_audio` and exposes audio-service state/controls for the OS and UI.
- Hive provides persisted settings/user/cache boxes; offline media files are stored under app document directories.
- Online metadata and streams are resolved through the local YouTube Explode packages and shared client setup.

## Important design consequence

The project uses shared module-level services and notifiers rather than a single injected application container. When following a feature, trace both the screen and the service state it reads or mutates. Startup ordering matters because settings and playlist managers read already-open Hive boxes during initialization.

## Related notes

- [[Startup and Navigation]]
- [[Playback Flow]]
- [[Persistence and State]]
- [[Feature and Package Map]]
