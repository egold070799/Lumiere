---
title: Startup and Navigation
tags: [lumiere, startup, routing]
---

# Startup and navigation

## Startup sequence

The public `main()` in [main.dart](../../lib/main.dart) ensures Flutter bindings, awaits `initialisation()`, then calls `runApp(const Lumiere())`.

`initialisation()` performs these steps:

1. Initializes Hive and opens `settings`, `user`, `userNoBackup`, and `cache` boxes.
2. Initializes `LumiereAudioHandler` through `AudioService.init` on mobile. On desktop it initializes the media_kit backend and creates the handler directly.
3. Forces `NavigationManager.instance` creation, which constructs the router.
4. Subscribes to incoming app links; `main.dart` handles custom shared-playlist links.
5. Performs build-specific announcement work, determines the app document directory, and ensures application directories exist.

The F-Droid entry point [main_fdroid.dart](../../lib/main_fdroid.dart) sets `isFdroidBuild` and delegates to `main()`.

## Root widget and lifecycle

`Lumiere` (the Lumiere root widget) builds a `MaterialApp.router`, applies theme and locale state, listens to platform brightness changes, and watches offline-mode changes. On lifecycle transitions away from the foreground, it records and flushes listening-session progress. Sharing intents are subscribed on mobile and routed to the audio handler.

## Routes

[router_service.dart](../../lib/services/router_service.dart) uses `GoRouter` with `StatefulShellRoute.indexedStack`. It defines separate navigator keys for Home, Search, Library, and Settings tabs; the shell is rendered by `BottomNavigationPage`.

Offline mode affects route behavior: search and listening recap/time-machine routes redirect home; album routes redirect home; artist routes are allowed only when that artist playlist is downloaded. The home route itself swaps between `HomePage` and offline `UserSongsPage`.

## Follow the code

- [Entry point and initialization](../../lib/main.dart)
- [F-Droid entry point](../../lib/main_fdroid.dart)
- [Navigation manager](../../lib/services/router_service.dart)
- [Bottom navigation shell](../../lib/screens/bottom_navigation_page.dart)
- [[Persistence and State]]
- [[Playback Flow]]
