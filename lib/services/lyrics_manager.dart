import 'dart:convert';

import 'package:lumiere/constants/version.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:lumiere/models/lyrics_track.dart';

class LyricsManager {
  static const _lrclibBaseUrl = 'https://lrclib.net';
  static const _lrclibUserAgent =
      'Lumiere/$appVersion (https://github.com/egold070799/Lumiere)';

  Future<LyricsTrack?> fetchLyrics(
    String artistName,
    String title, {
    String? albumName,
    Duration? duration,
  }) async {
    title = _cleanTitle(title);

    // Validate title is not empty after sanitization
    if (title.isEmpty || artistName.trim().isEmpty) {
      return null;
    }

    final lrclibLyrics = await _fetchFromLrclib(
      artistName: artistName,
      title: title,
      albumName: albumName,
      duration: duration,
    );
    if (lrclibLyrics != null) return lrclibLyrics;

    final lyricsFromLyricsOvh = await _fetchLyricsFromLyricsOvh(
      artistName,
      title,
    );
    if (lyricsFromLyricsOvh != null) {
      return LyricsTrack.plain(lyricsFromLyricsOvh, source: 'lyrics.ovh');
    }

    final lyricsFromParolesNet = await _fetchLyricsFromParolesNet(
      artistName.split(',')[0],
      title,
    );
    if (lyricsFromParolesNet != null) {
      return LyricsTrack.plain(lyricsFromParolesNet, source: 'paroles.net');
    }

    final lyricsFromLyricsMania1 = await _fetchLyricsFromLyricsMania1(
      artistName,
      title,
    );
    if (lyricsFromLyricsMania1 == null) return null;
    return LyricsTrack.plain(lyricsFromLyricsMania1, source: 'lyricsmania.com');
  }

  Future<LyricsTrack?> _fetchFromLrclib({
    required String artistName,
    required String title,
    String? albumName,
    Duration? duration,
  }) async {
    final primaryArtist = artistName.split(',').first.trim();
    final durationSeconds = duration?.inSeconds;
    final parameters = <String, String>{
      'track_name': title,
      'artist_name': primaryArtist,
      if (albumName?.trim().isNotEmpty == true) 'album_name': albumName!.trim(),
      if (durationSeconds != null &&
          durationSeconds > 0 &&
          durationSeconds <= 3600)
        'duration': durationSeconds.toString(),
    };

    final headers = {'User-Agent': _lrclibUserAgent};
    try {
      final exactResponse = await http
          .get(
            Uri.https('lrclib.net', '/api/get', parameters),
            headers: headers,
          )
          .timeout(const Duration(seconds: 12));
      if (exactResponse.statusCode == 200) {
        final lyrics = _trackFromLrclibRecord(
          jsonDecode(exactResponse.body),
          artistName: primaryArtist,
          title: title,
        );
        if (lyrics != null) return lyrics;
      }
      if (exactResponse.statusCode == 429 || exactResponse.statusCode == 503) {
        return null;
      }

      // The signature lookup is strict about duration. Search is a second,
      // still metadata-checked method for recordings with slightly different
      // duration metadata (music video vs. album track, for example).
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final searchResponse = await http
          .get(
            Uri.https('lrclib.net', '/api/search', {
              'track_name': title,
              'artist_name': primaryArtist,
            }),
            headers: headers,
          )
          .timeout(const Duration(seconds: 12));
      if (searchResponse.statusCode != 200) return null;

      final results = jsonDecode(searchResponse.body);
      if (results is! List) return null;
      final candidates = results
          .whereType<Map<String, dynamic>>()
          .where(
            (record) =>
                _recordMatches(record, artistName: primaryArtist, title: title),
          )
          .toList();
      candidates.sort((a, b) {
        final expected = durationSeconds?.toDouble();
        final aDifference = expected == null
            ? 0.0
            : ((a['duration'] as num?)?.toDouble() ?? expected) - expected;
        final bDifference = expected == null
            ? 0.0
            : ((b['duration'] as num?)?.toDouble() ?? expected) - expected;
        return aDifference.abs().compareTo(bDifference.abs());
      });

      for (final candidate in candidates) {
        final lyrics = _trackFromLrclibRecord(
          candidate,
          artistName: primaryArtist,
          title: title,
        );
        if (lyrics != null) return lyrics;
      }
    } catch (_) {
      // Continue to existing plain-lyrics providers when the timed source is
      // unavailable, rate-limited, or returns a malformed response.
    }
    return null;
  }

  LyricsTrack? _trackFromLrclibRecord(
    dynamic record, {
    required String artistName,
    required String title,
  }) {
    if (record is! Map<String, dynamic> ||
        !_recordMatches(record, artistName: artistName, title: title)) {
      return null;
    }

    final syncedLyrics = record['syncedLyrics'] as String?;
    if (syncedLyrics?.trim().isNotEmpty == true) {
      final track = LyricsTrack.fromLrc(
        lrc: syncedLyrics!,
        plainLyrics: record['plainLyrics'] as String?,
        source: 'LRCLIB',
      );
      if (track.isSynced) return track;
    }

    final plainLyrics = record['plainLyrics'] as String?;
    if (plainLyrics?.trim().isNotEmpty == true) {
      return LyricsTrack.plain(plainLyrics!, source: 'LRCLIB');
    }
    return null;
  }

  bool _recordMatches(
    Map<String, dynamic> record, {
    required String artistName,
    required String title,
  }) {
    final foundTitle = record['trackName'] ?? record['name'];
    final foundArtist = record['artistName'];
    return foundTitle is String &&
        foundArtist is String &&
        _normalize(foundTitle) == _normalize(title) &&
        _normalize(foundArtist).contains(_normalize(artistName));
  }

  String _normalize(String value) => value.toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{N}]', unicode: true),
    '',
  );

  String _cleanTitle(String input) {
    var title = input.trim();
    title = title.replaceFirst(
      RegExp(
        r'\s*[-–—]\s*(official audio|official lyrics?|lyrics? video)$',
        caseSensitive: false,
      ),
      '',
    );
    title = title.replaceFirst(
      RegExp(r'\s+(lyrics|karaoke)$', caseSensitive: false),
      '',
    );
    return title.trim();
  }

  Future<String?> _fetchLyricsFromLyricsOvh(
    String artistName,
    String title,
  ) async {
    try {
      final artistFormatted = _lyricsUrl(artistName.split(',')[0]);
      final titleFormatted = _lyricsUrl(title);
      final uri = Uri.parse(
        'https://api.lyrics.ovh/v1/$artistFormatted/$titleFormatted',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final lyrics = json['lyrics'] as String?;
        if (lyrics != null && lyrics.isNotEmpty) {
          return addCopyright(lyrics, 'lyrics.ovh');
        }
      }
    } catch (e) {
      // Silently fail and return null to try next source
      return null;
    }
    return null;
  }

  Future<String?> _fetchLyricsFromParolesNet(
    String artistName,
    String title,
  ) async {
    try {
      final uri = Uri.parse(
        'https://www.paroles.net/${_lyricsUrl(artistName)}/paroles-${_lyricsUrl(title)}',
      );
      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => http.Response('', 408),
          );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final songTextElements = document.querySelectorAll('.song-text');

        if (songTextElements.isNotEmpty) {
          final lyricsLines = songTextElements.first.text.split('\n');
          if (lyricsLines.length > 1) {
            lyricsLines.removeAt(0);

            final finalLyrics = addCopyright(
              lyricsLines.join('\n'),
              'www.paroles.net',
            );
            return _removeSpaces(finalLyrics);
          }
        }
      }
    } catch (e) {
      // Silently fail and return null to try next source
      return null;
    }

    return null;
  }

  Future<String?> _fetchLyricsFromLyricsMania1(
    String artistName,
    String title,
  ) async {
    try {
      final uri = Uri.parse(
        'https://www.lyricsmania.com/${_lyricsManiaUrl(title)}_lyrics_${_lyricsManiaUrl(artistName)}.html',
      );
      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => http.Response('', 408),
          );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final lyricsBodyElements = document.querySelectorAll('.lyrics-body');

        if (lyricsBodyElements.isNotEmpty) {
          return addCopyright(
            lyricsBodyElements.first.text,
            'www.lyricsmania.com',
          );
        }
      }
    } catch (e) {
      // Silently fail and return null
      return null;
    }

    return null;
  }

  String _lyricsUrl(String input) {
    var result = input.replaceAll(' ', '-').toLowerCase();
    // Remove special characters
    result = result.replaceAll(RegExp('[^a-z0-9-]'), '');
    // Clean up multiple/trailing dashes
    result = result.replaceAll(RegExp('-+'), '-');
    if (result.isNotEmpty && result.endsWith('-')) {
      result = result.substring(0, result.length - 1);
    }
    if (result.isNotEmpty && result.startsWith('-')) {
      result = result.substring(1);
    }
    return result;
  }

  String _lyricsManiaUrl(String input) {
    var result = input.replaceAll(' ', '_').toLowerCase();
    if (result.isNotEmpty && result.startsWith('_')) {
      result = result.substring(1);
    }
    if (result.isNotEmpty && result.endsWith('_')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  String _removeSpaces(String input) {
    return input.replaceAll(RegExp(' {2,}'), ' ');
  }

  String addCopyright(String input, String copyright) {
    return '$input\n\n© $copyright';
  }
}
