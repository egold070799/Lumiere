---
title: Persistence and State
tags: [lumiere, persistence, state]
---

# Persistence and state

## Hive boxes

`initialisation()` in [main.dart](../../lib/main.dart) opens four Hive boxes before `runApp`:

| Box | Main purpose |
| --- | --- |
| `settings` | Preferences such as theme, language, quality, offline mode, and playback behavior. |
| `user` | User-owned library data such as playlists, likes, history, and other account-local state. |
| `userNoBackup` | Data intentionally kept outside ordinary backup behavior, including offline song metadata. |
| `cache` | Expiring fetched data and stream URL cache entries. |

The specific values are spread across service modules. [settings_manager.dart](../../lib/services/settings_manager.dart) initializes preference `ValueNotifier`s from `settings`. [playlists_manager.dart](../../lib/services/playlists_manager.dart) initializes playlist notifiers from `user`.

## Data manager and cache policy

[data_manager.dart](../../lib/services/data_manager.dart) centralizes generic box access through `addOrUpdateData`, `getData`, and `deleteData`. Cache entries also receive a timestamp, are validated with a key-specific duration, and may be held in a bounded in-memory cache for faster repeated reads. The module also contains cleanup and file/export helpers.

## State propagation pattern

Many services expose `ValueNotifier`s as the live in-process state and persist changes to Hive. Widgets subscribe with Flutter listenable builders or read values directly. Thus there are two related representations: persisted Hive values and live notifier values. Look for explicit reload/update functions when a settings or library operation changes the stored data.

## Files and offline media

App file paths are initialized after resolving the documents directory. Offline audio/artwork live in files; Hive stores their metadata and paths. Download/removal logic is in `common_services.dart`, and app paths are coordinated by `io_service.dart`.

## Related source

- [Startup and box initialization](../../lib/main.dart)
- [Generic storage/cache manager](../../lib/services/data_manager.dart)
- [Settings state](../../lib/services/settings_manager.dart)
- [Playlist state](../../lib/services/playlists_manager.dart)
- [Application file paths](../../lib/services/io_service.dart)
- [[Startup and Navigation]]
- [[Playback Flow]]
