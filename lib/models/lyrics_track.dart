class TimedLyricLine {
  const TimedLyricLine({required this.timestamp, required this.text});

  final Duration timestamp;
  final String text;
}

class LyricsTrack {
  const LyricsTrack({
    required this.plainLyrics,
    required this.syncedLines,
    required this.source,
  });

  factory LyricsTrack.plain(String text, {required String source}) =>
      LyricsTrack(plainLyrics: text, syncedLines: const [], source: source);

  factory LyricsTrack.fromLrc({
    required String lrc,
    String? plainLyrics,
    required String source,
  }) {
    final lines = parseLrc(lrc);
    return LyricsTrack(
      plainLyrics: plainLyrics?.trim().isNotEmpty == true
          ? plainLyrics!.trim()
          : lines.map((line) => line.text).join('\n'),
      syncedLines: lines,
      source: source,
    );
  }

  final String plainLyrics;
  final List<TimedLyricLine> syncedLines;
  final String source;

  bool get isSynced => syncedLines.isNotEmpty;
  bool get hasLyrics => plainLyrics.trim().isNotEmpty || isSynced;

  int activeLineAt(Duration position) {
    var low = 0;
    var high = syncedLines.length - 1;
    var active = -1;

    while (low <= high) {
      final middle = (low + high) ~/ 2;
      if (syncedLines[middle].timestamp <= position) {
        active = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return active;
  }

  static List<TimedLyricLine> parseLrc(String lrc) {
    final timestampPattern = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
    final offsetMatch = RegExp(
      r'\[offset:([+-]?\d+)\]',
      caseSensitive: false,
    ).firstMatch(lrc);
    final offset = int.tryParse(offsetMatch?.group(1) ?? '') ?? 0;
    final parsed = <TimedLyricLine>[];

    for (final rawLine in lrc.split(RegExp(r'\r?\n'))) {
      final matches = timestampPattern.allMatches(rawLine).toList();
      if (matches.isEmpty) continue;

      final text = rawLine.replaceAll(timestampPattern, '').trim();
      if (text.isEmpty) continue;

      for (final match in matches) {
        final minutes = int.tryParse(match.group(1)!) ?? 0;
        final seconds = int.tryParse(match.group(2)!) ?? 0;
        final fractionText = match.group(3) ?? '';
        final fractionMs = switch (fractionText.length) {
          0 => 0,
          1 => (int.parse(fractionText) * 100),
          2 => (int.parse(fractionText) * 10),
          _ => int.parse(fractionText.substring(0, 3)),
        };
        final timestampMs =
            (minutes * 60 + seconds) * 1000 + fractionMs + offset;
        parsed.add(
          TimedLyricLine(
            timestamp: Duration(
              milliseconds: timestampMs.clamp(0, 1 << 62).toInt(),
            ),
            text: text,
          ),
        );
      }
    }

    parsed.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return List.unmodifiable(parsed);
  }
}
