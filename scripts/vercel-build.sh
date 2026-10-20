#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="3.47.7"
FLUTTER_ROOT="${FLUTTER_ROOT:-$HOME/flutter}"

if ! command -v "$FLUTTER_ROOT/bin/flutter" >/dev/null 2>&1; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"
flutter config --enable-web
flutter pub get
flutter build web --release
