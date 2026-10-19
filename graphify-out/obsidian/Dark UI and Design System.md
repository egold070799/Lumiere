---
title: Dark UI and Design System
tags: [lumiere, ui, theme, design-system]
---

# Dark UI and design system

## Visual direction

Lumiere defaults to a deep green-black dark theme with warm brass and quiet slate accents. The optional light mode keeps its warm paper surfaces. Both modes use the same serif display and neutral sans-serif interface typography, compact rounded controls, and reusable theme tokens.

## Theme flow

`settings_manager.dart` loads the saved `ThemeMode`, defaulting new installs to dark. `main.dart` applies a one-time migration to dark for existing installs, then respects later user selections. It builds light and dark schemes independently, including the corresponding dynamic system scheme when enabled, then passes both themes to `MaterialApp.router`. `app_themes.dart` assembles each Material theme from `lumiere_tokens.dart`; the pure-black option remains a user preference for OLED screens.

```text
settings_manager.dart ── ThemeMode / accent / display options
          │
          ▼
main.dart ── light + dark ColorScheme ── MaterialApp.router
          │                                  │
          ▼                                  ▼
app_themes.dart ◀──────────────────── lumiere_tokens.dart
          │
          ├── screens/ and reusable widgets
          ├── responsive navigation shell
          └── mini-player and now-playing surface
```

## Current UI refinements

- `lib/theme/lumiere_tokens.dart` — shared light/dark palette and shape tokens.
- `lib/theme/app_themes.dart` — brightness-specific schemes, independent light/dark themes, navigation shapes and shared component styling.
- `lib/services/settings_manager.dart` — dark default for users without a saved theme choice.
- `lib/main.dart` — separate light and dark themes; system dynamic color feeds each matching brightness.
- `lib/screens/bottom_navigation_page.dart` — adaptive bottom bar/rail with a small Lumiere mark on wide layouts; mini-player stays above the content inset.
- `lib/screens/home_page.dart` — fast search action and a 1240 px content width cap on large screens.
- `lib/widgets/mini_player.dart` — restrained outlined surface and smooth circular playback progress.

Playback, routing, persistence, download and streaming services are unchanged by this visual refactor. For their dependencies and route flow, see [[System Overview]], [[Startup and Navigation]], and [[Playback Flow]].
