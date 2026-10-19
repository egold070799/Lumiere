import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lumiere/extensions/l10n.dart';
import 'package:lumiere/main.dart' show logger;
import 'package:lumiere/services/artist_service.dart' show ytMusicClient;
import 'package:lumiere/services/data_manager.dart';
import 'package:lumiere/services/playlists_manager.dart';
import 'package:lumiere/services/spotify_playlist_service.dart';
import 'package:lumiere/utilities/flutter_toast.dart';
import 'package:lumiere/utilities/formatter.dart';
import 'package:lumiere/utilities/platform_utils.dart';
import 'package:lumiere/utilities/url_launcher.dart';
import 'package:lumiere/widgets/mini_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A CSV row and its original position, used to preserve playlist order.
typedef _ImportRow = ({int index, String title, String artist});

class ImportSpotifyPlaylistPage extends StatefulWidget {
  const ImportSpotifyPlaylistPage({super.key});

  @override
  State<ImportSpotifyPlaylistPage> createState() =>
      _ImportSpotifyPlaylistPageState();
}

class _ImportSpotifyPlaylistPageState extends State<ImportSpotifyPlaylistPage> {
  // Shared across page instances so navigating away and reopening the page
  // can't spawn a second import running concurrently with the first.
  static bool _importRunning = false;

  // Limit concurrency and leave a short pause between batches.
  static const _batchSize = 12;
  static const _batchPause = Duration(milliseconds: 150);

  final _csvController = TextEditingController();
  final _spotifyLinkController = TextEditingController();
  final _spotifyClientIdController = TextEditingController();
  final _playlistNameController = TextEditingController();
  bool _isImporting = false;
  String? _fileName;
  int _processedCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSpotifyClientId());
  }

  Future<void> _loadSpotifyClientId() async {
    final savedClientId = await getData('settings', 'spotifyClientId');
    if (savedClientId is String && mounted) {
      _spotifyClientIdController.text = savedClientId;
    }
  }

  @override
  void dispose() {
    _csvController.dispose();
    _spotifyLinkController.dispose();
    _spotifyClientIdController.dispose();
    _playlistNameController.dispose();
    super.dispose();
  }

  Future<void> _chooseFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result.isEmpty || !mounted) return;

    final file = result.single;
    final path = file.path;
    if (path == null) return;
    _csvController.text = await File(path).readAsString();
    if (!mounted) return;
    setState(() => _fileName = file.name);
  }

  Future<void> _importPlaylist() async {
    if (_isImporting) return;
    if (_importRunning) {
      showToast(context, context.l10n!.spotifyPlaylistAlreadyImporting);
      return;
    }
    final playlistName = _playlistNameController.text.trim();
    if (playlistName.isEmpty) {
      showToast(context, context.l10n!.enterPlaylistName);
      return;
    }
    final records = _parseCsv(_csvController.text);
    if (records.length < 2) {
      showToast(context, context.l10n!.spotifyPlaylistEmpty);
      return;
    }

    final headers = records.first
        .map((header) => header.replaceFirst('\ufeff', '').trim().toLowerCase())
        .toList();
    bool isNameColumn(String header) =>
        !header.contains('id') &&
        !header.contains('uri') &&
        !header.contains('url') &&
        !header.contains('genre');
    final songIndex = headers.indexWhere(
      (header) =>
          (header.contains('song') || header.contains('track')) &&
          isNameColumn(header),
    );
    final artistIndex = headers.indexWhere(
      (header) => header.contains('artist') && isNameColumn(header),
    );
    if (songIndex == -1 || artistIndex == -1) {
      showToast(context, context.l10n!.spotifyPlaylistInvalid);
      return;
    }

    final songs = records.skip(1).where((row) {
      return row.length > songIndex &&
          row.length > artistIndex &&
          row[songIndex].trim().isNotEmpty;
    }).toList();
    if (songs.isEmpty) {
      showToast(context, context.l10n!.spotifyPlaylistEmpty);
      return;
    }

    final rows = songs.indexed
        .map(
          (entry) => (
            index: entry.$1,
            title: entry.$2[songIndex].trim(),
            artist: entry.$2[artistIndex].trim(),
          ),
        )
        .toList();

    await _runImport(rows: rows, playlistName: playlistName);
  }

  Future<void> _importFromSpotifyLink() async {
    if (_isImporting) return;
    final link = _spotifyLinkController.text.trim();
    final clientId = _spotifyClientIdController.text.trim();
    if (SpotifyPlaylistService.parsePlaylistId(link) == null) {
      showToast(
        context,
        'Enter a valid Spotify playlist link or Spotify playlist URI.',
      );
      return;
    }
    if (clientId.isEmpty) {
      showToast(context, 'Enter your Spotify Developer app Client ID first.');
      return;
    }

    await addOrUpdateData<String>('settings', 'spotifyClientId', clientId);
    await _runImport(
      playlistName: _playlistNameController.text.trim(),
      loadSpotify: () => SpotifyPlaylistService().loadPlaylist(
        playlistLink: link,
        clientId: clientId,
      ),
    );
  }

  Future<void> _runImport({
    List<_ImportRow>? rows,
    required String playlistName,
    Future<SpotifyPlaylistData> Function()? loadSpotify,
  }) async {
    if (_isImporting) return;
    if (_importRunning) {
      showToast(context, context.l10n!.spotifyPlaylistAlreadyImporting);
      return;
    }

    _importRunning = true;
    setState(() {
      _isImporting = true;
      _processedCount = 0;
      _totalCount = rows?.length ?? 0;
    });

    try {
      var effectiveRows = rows;
      var effectivePlaylistName = playlistName;
      if (loadSpotify != null) {
        final playlist = await loadSpotify();
        effectiveRows = playlist.tracks.indexed
            .map(
              (entry) => (
                index: entry.$1,
                title: entry.$2.title,
                artist: entry.$2.artist,
              ),
            )
            .toList();
        if (effectivePlaylistName.isEmpty) {
          effectivePlaylistName = playlist.name;
          _playlistNameController.text = playlist.name;
        }
        if (mounted) setState(() => _totalCount = effectiveRows!.length);
      }

      if (effectiveRows == null || effectiveRows.isEmpty) {
        throw const SpotifyPlaylistImportException(
          'The playlist does not contain any tracks to import.',
        );
      }
      if (effectivePlaylistName.isEmpty) {
        throw SpotifyPlaylistImportException(context.l10n!.enterPlaylistName);
      }

      // Keep results keyed by the source position to preserve playlist order.
      final foundByIndex = <int, Map>{};
      final firstPass = await _searchBatch(
        effectiveRows,
        onProgress: (n) {
          if (mounted) setState(() => _processedCount += n);
        },
      );
      foundByIndex.addAll(firstPass.found);
      var missingRows = firstPass.missing;
      var rateLimited = firstPass.rateLimited;

      // Retry misses once, unless the service is actively rate-limiting us.
      if (!rateLimited && missingRows.isNotEmpty) {
        if (mounted) setState(() => _totalCount += missingRows.length);
        final retryPass = await _searchBatch(
          missingRows,
          onProgress: (n) {
            if (mounted) setState(() => _processedCount += n);
          },
        );
        foundByIndex.addAll(retryPass.found);
        missingRows = retryPass.missing;
        rateLimited = retryPass.rateLimited;
      }

      final foundSongs = [
        for (final row in effectiveRows)
          if (foundByIndex[row.index] case final song?) song,
      ];

      if (!mounted) return;
      if (foundSongs.isNotEmpty) {
        final (_, playlistId) = createCustomPlaylist(
          effectivePlaylistName,
          null,
          context,
        );
        addSongsInCustomPlaylist(context, playlistId, foundSongs);
      }

      final resultText = rateLimited
          ? '${context.l10n!.spotifyPlaylistImportFailed}\n${context.l10n!.spotifyPlaylistImportResult(foundSongs.length, effectiveRows.length)}'
          : context.l10n!.spotifyPlaylistImportResult(
              foundSongs.length,
              effectiveRows.length,
            );
      if (missingRows.isNotEmpty) {
        final missingText = missingRows
            .map((row) => '${row.title} - ${row.artist}')
            .join('\n');
        await Clipboard.setData(ClipboardData(text: missingText));
        if (mounted) {
          showToastWithButton(
            context,
            '$resultText\n${context.l10n!.spotifyPlaylistMissingSongs}',
            context.l10n!.copy,
            () => Clipboard.setData(ClipboardData(text: missingText)),
            duration: const Duration(seconds: 8),
            icon: FluentIcons.warning_24_regular,
          );
        }
      } else {
        showToast(context, resultText);
      }
    } on SpotifyPlaylistImportException catch (error) {
      if (mounted) showToast(context, error.message);
    } catch (error, stackTrace) {
      logger.log(
        'Spotify playlist import failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        showToast(context, context.l10n!.spotifyPlaylistImportFailed);
      }
    } finally {
      _importRunning = false;
      if (mounted) setState(() => _isImporting = false);
    }
  }

  /// Resolves [rows] in batches and stops when rate limiting is detected.
  /// Results are keyed by the rows' original positions for retry merging.
  Future<({Map<int, Map> found, List<_ImportRow> missing, bool rateLimited})>
  _searchBatch(
    List<_ImportRow> rows, {
    required void Function(int processedCount) onProgress,
  }) async {
    final found = <int, Map>{};
    final missing = <_ImportRow>[];
    for (var i = 0; i < rows.length; i += _batchSize) {
      final batch = rows.skip(i).take(_batchSize).toList();
      final batchResults = await Future.wait(
        batch.map((row) async {
          final (match, wasRateLimited) = await _findSongWithRetry(
            '${row.title} ${row.artist}',
            expectedArtist: row.artist,
            expectedTitle: row.title,
          );
          return (row, match, wasRateLimited);
        }),
      );
      var batchRateLimited = false;
      for (final (row, match, wasRateLimited) in batchResults) {
        if (wasRateLimited) batchRateLimited = true;
        if (match == null) {
          missing.add(row);
        } else {
          found[row.index] = match;
        }
      }
      onProgress(batchResults.length);
      if (batchRateLimited) {
        missing.addAll(rows.skip(i + _batchSize));
        return (found: found, missing: missing, rateLimited: true);
      }
      await Future.delayed(_batchPause);
    }
    return (found: found, missing: missing, rateLimited: false);
  }

  /// Returns the best match for [query], or `null` if none was found.
  /// The second value is `true` when YouTube is actively rate-limiting this
  /// device, so the caller can stop the whole import instead of retrying
  /// every remaining song for minutes on end.
  Future<(Map<String, dynamic>?, bool)> _findSongWithRetry(
    String query, {
    String? expectedArtist,
    String? expectedTitle,
  }) async {
    const maxAttempts = 2;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final video = await ytMusicClient.music.searchSong(
          query,
          expectedArtist: expectedArtist,
          expectedTitle: expectedTitle,
        );
        if (video == null) return (null, false);
        return (Map<String, dynamic>.from(returnSongLayout(0, video)), false);
      } on RequestLimitExceededException {
        // A single short retry for a transient hiccup; a second hit means
        // it's a genuine, sustained block.
        if (attempt == maxAttempts - 1) return (null, true);
        await Future.delayed(const Duration(seconds: 2));
      } catch (e, stackTrace) {
        if (attempt == maxAttempts - 1) {
          logger.log(
            'Error searching Spotify import match for "$query"',
            error: e,
            stackTrace: stackTrace,
          );
          return (null, false);
        }
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    return (null, false);
  }

  List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;

    for (var index = 0; index < input.length; index++) {
      final character = input[index];
      if (character == '"') {
        if (quoted && index + 1 < input.length && input[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (character == ',' && !quoted) {
        row.add(field.toString());
        field = StringBuffer();
      } else if ((character == '\n' || character == '\r') && !quoted) {
        if (character == '\r' &&
            index + 1 < input.length &&
            input[index + 1] == '\n') {
          index++;
        }
        row.add(field.toString());
        field = StringBuffer();
        if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
        row = <String>[];
      } else {
        field.write(character);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n!.importSpotifyPlaylistTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n!.importSpotifyPlaylistInstructions),
            if (isAndroidPlatform) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _spotifyLinkController,
                enabled: !_isImporting,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: context.l10n!.spotifyPlaylistLinkLabel,
                  hintText: context.l10n!.spotifyPlaylistLinkHint,
                  prefixIcon: const Icon(FluentIcons.link_24_regular),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _spotifyClientIdController,
                enabled: !_isImporting,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: context.l10n!.spotifyClientIdLabel,
                  hintText: context.l10n!.spotifyClientIdHint,
                  prefixIcon: const Icon(FluentIcons.key_24_regular),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n!.spotifyClientIdHelp,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: spotifyRedirectUri),
                    );
                    if (context.mounted) {
                      showToast(context, 'Spotify redirect URI copied');
                    }
                  },
                  icon: const Icon(FluentIcons.copy_24_regular),
                  label: const Text('Copy redirect URI'),
                ),
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: _isImporting ? null : _importFromSpotifyLink,
                icon: _isImporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(FluentIcons.arrow_download_24_regular),
                label: Text(
                  _isImporting
                      ? context.l10n!.spotifyPlaylistImporting
                      : context.l10n!.spotifyImportFromLink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n!.spotifyPlaylistImportUnavailable,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              Center(child: Text(context.l10n!.spotifyImportOrCsv)),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => launchURL(
                Uri.parse('https://www.chosic.com/spotify-playlist-exporter/'),
              ),
              icon: const Icon(FluentIcons.open_24_regular),
              label: Text(context.l10n!.openChosicExporter),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isImporting ? null : _chooseFile,
              icon: const Icon(FluentIcons.document_add_24_regular),
              label: Text(_fileName ?? context.l10n!.chooseCsvFile),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _playlistNameController,
              enabled: !_isImporting,
              decoration: InputDecoration(
                labelText: '${context.l10n!.playlistName} *',
                hintText: context.l10n!.spotifyPlaylistNameHint,
                filled: true,
                fillColor: colorScheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _csvController,
              enabled: !_isImporting,
              minLines: 10,
              maxLines: 18,
              decoration: InputDecoration(
                labelText: context.l10n!.pasteCsv,
                hintText: context.l10n!.spotifyCsvHint,
                alignLabelWithHint: true,
                filled: true,
                fillColor: colorScheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isImporting ? null : _importPlaylist,
              icon: _isImporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(FluentIcons.arrow_upload_24_regular),
              label: Text(
                _isImporting
                    ? context.l10n!.spotifyPlaylistImporting
                    : context.l10n!.importPlaylist,
              ),
            ),
            if (_isImporting && _totalCount > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _processedCount / _totalCount,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n!.spotifyPlaylistProgress(
                  _processedCount,
                  _totalCount,
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: MiniPlayer.playerHeight + 24),
          ],
        ),
      ),
    );
  }
}
