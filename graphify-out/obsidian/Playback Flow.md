---
title: Playback Flow
tags: [lumiere, audio, playback]
---

# Playback flow

## Core owner

[LumiereAudioHandler](../../lib/services/audio_service.dart) extends `BaseAudioHandler` and implements the Android Auto host interface. It owns a `just_audio` `AudioPlayer`, the active queue, original queue entries, history, loading/transition coordination, preload bookkeeping, sleep timer state, and optional Android equalizer integration.

The handler exposes playback-state and position streams (including a combined `PositionData` stream) and a queue stream. These streams are the bridge between the player engine and presentation/OS integrations.

## Typical online playback path

1. A screen or widget asks the shared `audioHandler` to play or enqueue song metadata.
2. The handler coordinates queue selection and track transitions, then requests a playable source through common media services.
3. The common service resolves a YouTube stream using the local YouTube Explode client, selects quality, and caches stream metadata/URLs where applicable.
4. `just_audio` loads and plays the resolved source; the handler publishes metadata and playback state through audio_service.
5. UI such as the mini player, now-playing page, and queue widgets observe handler state and invoke handler controls.

## Offline playback and downloads

Offline downloads are implemented in `common_services.dart`: audio and optional artwork are written to app-managed paths, song metadata is added to the offline-song list in `userNoBackup`, and SponsorBlock segments can be cached with the download. The library/offline screens read this registry and the handler can play the local file path.

## Supporting modules

- [Player handler](../../lib/services/audio_service.dart) — queue, controls, state streams and player lifecycle.
- [Common media services](../../lib/services/common_services.dart) — stream resolution, metadata, lyrics, offline download and related media helpers.
- [Android Auto adapter](../../lib/services/audio_service_android_auto.dart) — browse/search integration.
- [Queue identity helpers](../../lib/utilities/queue_entry_utils.dart) — queue-entry IDs and related operations.
- [Player UI controls](../../lib/widgets/now_playing/now_playing_controls.dart)
- [Queue presentation](../../lib/widgets/queue_list_view.dart)
- [[Persistence and State]]

## Operational detail

The handler explicitly coordinates transitions, retries, stream preloading and playback-state updates. When debugging a skip, stuck load, or incorrect queue item, inspect the handler’s transition/index logic and queue-entry identity helpers before looking only at the widgets.
