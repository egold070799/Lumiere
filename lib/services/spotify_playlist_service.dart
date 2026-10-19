import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const spotifyRedirectUri = 'lumiere-spotify://callback';

class SpotifyPlaylistTrack {
  const SpotifyPlaylistTrack({required this.title, required this.artist});

  final String title;
  final String artist;
}

class SpotifyPlaylistData {
  const SpotifyPlaylistData({required this.name, required this.tracks});

  final String name;
  final List<SpotifyPlaylistTrack> tracks;
}

class SpotifyPlaylistImportException implements Exception {
  const SpotifyPlaylistImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Fetches playlist metadata through Spotify's Web API using mobile PKCE OAuth.
/// Spotify's client ID is public configuration; a client secret is never used.
class SpotifyPlaylistService {
  static Completer<Uri>? _pendingAuthorization;

  /// Called by the app-wide deep-link listener for the dedicated OAuth scheme.
  static bool handleAuthorizationRedirect(Uri? uri) {
    if (uri == null ||
        uri.scheme != 'lumiere-spotify' ||
        uri.host != 'callback') {
      return false;
    }

    final pending = _pendingAuthorization;
    if (pending != null && !pending.isCompleted) pending.complete(uri);
    return true;
  }

  Future<SpotifyPlaylistData> loadPlaylist({
    required String playlistLink,
    required String clientId,
  }) async {
    final playlistId = parsePlaylistId(playlistLink);
    if (playlistId == null) {
      throw const SpotifyPlaylistImportException(
        'Enter a valid Spotify playlist link or Spotify playlist URI.',
      );
    }
    if (clientId.trim().isEmpty) {
      throw const SpotifyPlaylistImportException(
        'Enter your Spotify Developer app Client ID first.',
      );
    }

    final token = await _authorize(clientId.trim());
    final headers = {'Authorization': 'Bearer $token'};
    final playlistResponse = await _getJson(
      Uri.https('api.spotify.com', '/v1/playlists/$playlistId'),
      headers,
    );
    final playlistName = playlistResponse['name']?.toString().trim();

    final tracks = <SpotifyPlaylistTrack>[];
    const pageSize = 50;
    var offset = 0;
    while (true) {
      final response = await _getJson(
        Uri.https('api.spotify.com', '/v1/playlists/$playlistId/items', {
          'limit': '$pageSize',
          'offset': '$offset',
        }),
        headers,
      );
      final items = response['items'];
      if (items is! List || items.isEmpty) break;

      for (final entry in items) {
        if (entry is! Map) continue;
        final item = entry['item'] ?? entry['track'];
        if (item is! Map || item['type'] == 'episode') continue;

        final title = item['name']?.toString().trim() ?? '';
        final artists = item['artists'];
        if (title.isEmpty || artists is! List) continue;
        final artistNames = artists
            .whereType<Map>()
            .map((artist) => artist['name']?.toString().trim() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
        if (artistNames.isEmpty) continue;
        tracks.add(
          SpotifyPlaylistTrack(title: title, artist: artistNames.join(', ')),
        );
      }

      offset += items.length;
      if (response['next'] == null || items.length < pageSize) break;
    }

    if (tracks.isEmpty) {
      throw const SpotifyPlaylistImportException(
        'Spotify returned no tracks. The playlist may be empty or your account may not have access to its tracks.',
      );
    }

    return SpotifyPlaylistData(
      name: playlistName == null || playlistName.isEmpty
          ? 'Spotify Playlist'
          : playlistName,
      tracks: tracks,
    );
  }

  static String? parsePlaylistId(String input) {
    final value = input.trim();
    final uriMatch = RegExp(
      r'^spotify:playlist:([A-Za-z0-9]+)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (uriMatch != null) return uriMatch.group(1);

    final uri = Uri.tryParse(value);
    if (uri == null ||
        !{
          'open.spotify.com',
          'www.open.spotify.com',
        }.contains(uri.host.toLowerCase())) {
      return null;
    }
    final segments = uri.pathSegments;
    final playlistIndex = segments.indexOf('playlist');
    if (playlistIndex == -1 || playlistIndex + 1 >= segments.length) {
      return null;
    }
    final id = segments[playlistIndex + 1];
    return RegExp(r'^[A-Za-z0-9]+$').hasMatch(id) ? id : null;
  }

  Future<String> _authorize(String clientId) async {
    if (_pendingAuthorization != null) {
      throw const SpotifyPlaylistImportException(
        'Spotify sign-in is already waiting for a response.',
      );
    }

    final verifier = _randomString(64);
    final state = _randomString(32);
    final challenge = base64Url
        .encode(sha256.convert(ascii.encode(verifier)).bytes)
        .replaceAll('=', '');
    final callback = Completer<Uri>();
    _pendingAuthorization = callback;

    try {
      final authorizationUri = Uri.https('accounts.spotify.com', '/authorize', {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': spotifyRedirectUri,
        'code_challenge_method': 'S256',
        'code_challenge': challenge,
        'state': state,
        'scope': 'playlist-read-private playlist-read-collaborative',
      });
      final opened = await launchUrl(
        authorizationUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw const SpotifyPlaylistImportException(
          'Could not open Spotify sign-in in your browser.',
        );
      }

      final redirect = await callback.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () => throw const SpotifyPlaylistImportException(
          'Spotify sign-in timed out. Return to Lumiere and try again.',
        ),
      );
      if (redirect.queryParameters['state'] != state) {
        throw const SpotifyPlaylistImportException(
          'Spotify sign-in could not be verified. Please try again.',
        );
      }
      final error = redirect.queryParameters['error'];
      if (error != null) {
        throw const SpotifyPlaylistImportException(
          'Spotify sign-in was cancelled or denied.',
        );
      }
      final code = redirect.queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw const SpotifyPlaylistImportException(
          'Spotify sign-in did not return an authorization code.',
        );
      }

      final tokenResponse = await http
          .post(
            Uri.https('accounts.spotify.com', '/api/token'),
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {
              'grant_type': 'authorization_code',
              'code': code,
              'redirect_uri': spotifyRedirectUri,
              'client_id': clientId,
              'code_verifier': verifier,
            },
          )
          .timeout(const Duration(seconds: 25));
      if (tokenResponse.statusCode != 200) {
        throw const SpotifyPlaylistImportException(
          'Spotify could not complete sign-in. Check your Client ID and redirect URI.',
        );
      }
      final tokenBody = jsonDecode(tokenResponse.body);
      final token = tokenBody is Map ? tokenBody['access_token'] : null;
      if (token is! String || token.isEmpty) {
        throw const SpotifyPlaylistImportException(
          'Spotify sign-in returned no access token.',
        );
      }
      return token;
    } on TimeoutException {
      throw const SpotifyPlaylistImportException(
        'Spotify sign-in timed out. Return to Lumiere and try again.',
      );
    } finally {
      if (identical(_pendingAuthorization, callback)) {
        _pendingAuthorization = null;
      }
    }
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri,
    Map<String, String> headers,
  ) async {
    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 25));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) return body;
      throw const SpotifyPlaylistImportException(
        'Spotify returned an unexpected playlist response.',
      );
    }
    if (response.statusCode == 403) {
      throw const SpotifyPlaylistImportException(
        'Spotify could not provide this playlist’s tracks. In Spotify Developer settings, allowlist your account; Spotify may also limit tracks to playlists you own or collaborate on.',
      );
    }
    if (response.statusCode == 404) {
      throw const SpotifyPlaylistImportException(
        'Spotify playlist was not found or is not available to this account.',
      );
    }
    if (response.statusCode == 429) {
      throw const SpotifyPlaylistImportException(
        'Spotify is temporarily rate limiting requests. Try again later.',
      );
    }
    throw SpotifyPlaylistImportException(
      'Spotify playlist request failed (${response.statusCode}). Check access and try again.',
    );
  }

  String _randomString(int length) {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}
