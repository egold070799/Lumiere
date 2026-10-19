---
title: Performance and Optimization
tags: [lumiere, performance, optimization]
---

# Performance and optimization

These are optimizations already visible in the checked-in code, with their likely purpose. They are not benchmark claims.

## Playback responsiveness

- **Upcoming stream preloading:** `audio_service.dart` preloads upcoming songs, bounded by `_queueLookahead = 3` and `_maxConcurrentPreloads = 2`; sets track in-progress/completed IDs and are pruned when the queue changes.
- **Selected stream reuse:** `common_services.dart` keeps a bounded in-memory cache of selected audio stream manifests (up to 50, keyed by song and quality) to avoid resolving the manifest twice during one playback flow.
- **URL cache with validity checks:** resolved stream URLs are stored in Hive with a three-hour cache duration, and stale/dead URLs can be validated and invalidated.
- **Deduplicated state notifications:** player streams use `distinct`; position updates suppress changes under 250 ms, and playback-state updates are debounced by 150 ms to reduce redundant UI updates.
- **Broadcast stream reuse:** derived position and playback state streams are made broadcast streams for multiple UI listeners.

## Data and UI efficiency

- **Two-level cache:** `data_manager.dart` checks a bounded in-memory cache before Hive; cached keys have category-aware TTLs and old entries are cleaned up.
- **Cached song ID sets:** `common_services.dart` maintains sets for liked/offline IDs to avoid repeated list scans for common membership checks.
- **Parallel independent startup work:** Hive boxes are opened with `Future.wait` in `main.dart`; related independent file operations also use `Future.wait`.
- **Lazy presentation:** Flutter builders and stream/listenable builders let widgets rebuild from the state they subscribe to. `bottom_navigation_page.dart` uses an indexed stateful route shell, retaining tab navigation state.

## Network and storage behavior

- **Proxy client reuse and parallel fetching:** `proxy_manager.dart` shares client resources and batches independent candidate checks.
- **Offline-first capabilities:** songs and artwork are downloaded to app-managed files and represented by metadata in `userNoBackup`; offline mode also changes route availability and skips stream preloading.
- **Background, non-blocking side work:** some cache writes and session flushes are deliberately launched with `unawaited`; lifecycle changes trigger listening-stat persistence.
- **Rate-limited SponsorBlock lookups:** offline downloads serialize lookup calls with spacing to avoid burst requests.

## Lumiere guidance

Artwork widgets now pass target-pixel dimensions to Flutter's image decoder and cap decode size at 1600 px, including local art and cached network art. This reduces decoded bitmap memory for small list/mini-player artwork while retaining sufficient resolution for large artwork surfaces.

Preserve the existing stream/cache behavior while changing presentation. Treat cache keys, Hive box names, persisted schemas, player transition coordination, Android service configuration, and platform identifiers as compatibility-sensitive. See [[Lumiere Change Plan]].
