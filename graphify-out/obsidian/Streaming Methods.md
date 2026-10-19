---
title: Streaming Methods
tags: [lumiere, streaming, playback]
---

# Streaming methods

Lumiere performs playback on the client with `just_audio`. The checked-in code does not implement a Lumiere audio-origin server or relay. Online media URLs are resolved by the YouTube client packages, then handed to `just_audio` as URI audio sources.

## 1. YouTube on-demand audio

1. `playSong()` asks `_resolvePlaybackSource()` for the source.
2. `_getPlaybackUrl()` calls `fetchSongStreamUrl(songId, isLive: false)`.
3. `fetchSongStreamUrl()` checks the Hive URL cache (keyed by song ID and selected audio quality). If needed, `fetchBestAudioStream()` obtains a manifest and chooses an audio-only stream according to `audioQualitySetting`.
4. `getManifestWithFallback()` tries the VisionOS YouTube client first and Android second, using a 30-second manifest timeout. It records which client produced the stream URL.
5. `buildAudioSource()` creates an `AudioSource.uri`. For non-live Google Video URLs it attaches matching client headers, including the User-Agent, because the URL can reject a mismatched client identity.
6. `audioPlayer.setAudioSource()` loads it and the handler starts playback.

The selected `AudioOnlyStreamInfo` is cached in memory for the current song/quality (bounded to 50 entries); the URL is cached in Hive. Old URL cache entries are checked for validity before reuse, and a failed cached stream may trigger cache invalidation and one fresh-URL retry.

## 2. YouTube live streams

For song metadata marked `isLive`, `fetchSongStreamUrl()` calls `ytClient.videos.streamsClient.getHttpLiveStreamUrl(VideoId(songId))`. This bypasses the on-demand audio-only manifest selection and the persistent VOD URL cache. Playback still goes through `AudioSource.uri`; the Google Video client-header handling is intentionally disabled for live items.

## 3. Radio station URLs

`playRadioStream()` accepts a station's `streamUrl` directly, creates live-style metadata with no duration, builds an online URI source, and plays it without normal song-queue management. The app does not transcode or host this radio audio; supported URL/protocol behavior depends on the source URL and audio backend.

## 4. Downloaded/offline audio

`makeSongOffline()` selects an audio-only YouTube stream and copies its bytes into an app-managed local file. `audioPath` is saved in the offline song record. Playback resolves that path and builds `AudioSource.file`, so offline playback does not depend on a network stream URL. Missing files do not fall back online while offline mode is enabled. SponsorBlock can wrap online/offline sources with clipped audio-source segments when applicable.

## 5. Proxy-assisted resolution

With proxy mode enabled, `_fetchStreamManifest()` asks `ProxyManager.getSongManifest()` to resolve the YouTube manifest using a proxy-backed YouTube client. The resulting media URL is still passed to `just_audio`; the code path here does not demonstrate that the audio-byte request itself is routed through the app's proxy. `ProxyManager` also exposes proxied HTTP requests for other remote fetches.

## Where to trace

- [Quality/fallback clients and playback headers](../../lib/constants/clients.dart)
- [Manifest, stream selection, URL cache, and offline download](../../lib/services/common_services.dart)
- [Queue-to-source handoff and retries](../../lib/services/audio_service.dart)
- [Proxy implementation](../../lib/services/proxy_manager.dart)
- [[Playback Flow]]
- [[Performance and Optimization]]
