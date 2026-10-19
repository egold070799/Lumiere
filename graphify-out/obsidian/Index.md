---
title: Lumiere Architecture Map
tags: [lumiere, architecture, map]
---

# Lumiere architecture map

This vault is a source-oriented guide to the Flutter application. It is organized around runtime flows and responsibilities, with links back to the implementation.

Open [[Lumiere Architecture.canvas]] for the visual overview.

## Start here

- [[System Overview]] — the main layers and how they interact.
- [[Startup and Navigation]] — process startup, platform initialization, routes, and offline redirects.
- [[Playback Flow]] — audio handler, queue, streaming, playback state, and UI.
- [[Streaming Methods]] — on-demand, live, radio, offline, and proxy-assisted resolution paths.
- [[Persistence and State]] — Hive boxes, settings, user libraries, caching, and files.
- [[Feature and Package Map]] — where screens, services, widgets, utilities, and local packages fit.
- [[Technologies and Files]] — stack inventory and source-file map by change type.
- [[Performance and Optimization]] — existing performance techniques and preservation guidance.
- [[Lumiere Change Plan]] — proposed app shell, screen layout, code organization, and migration phases.
- [[Dark UI and Design System]] — current palette, theme flow, and UI implementation map.
- [[Graphify Status]] — what Graphify could and could not generate in this environment.

## Main code landmarks

- [Application entry point](../../lib/main.dart)
- [Audio handler](../../lib/services/audio_service.dart)
- [Router](../../lib/services/router_service.dart)
- [Data manager](../../lib/services/data_manager.dart)
- [Playlist manager](../../lib/services/playlists_manager.dart)
- [Dependency manifest](../../pubspec.yaml)

## Reading path

Follow [[Startup and Navigation]] into [[Persistence and State]], then [[Playback Flow]]. Use [[Feature and Package Map]] to locate other feature areas.

## Scope and confidence

These notes summarize the checked-in source. They are not generated Graphify output. The repository contains platform shells and bundled/local Dart packages as well as `lib/`; this map focuses on the shared Flutter application and names platform/package boundaries where they matter.
