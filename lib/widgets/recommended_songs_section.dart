import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lumiere/main.dart';
import 'package:lumiere/utilities/app_utils.dart';
import 'package:lumiere/widgets/section_header.dart';
import 'package:lumiere/widgets/song_bar.dart';

/// Shared titled list of recommended songs with an optional "play all" button.
class RecommendedSongsSection extends StatelessWidget {
  const RecommendedSongsSection({
    super.key,
    required this.title,
    required this.songs,
    required this.listKeyPrefix,
    this.showPlayButton = true,
    this.onAddSong,
  });

  final String title;
  final List<dynamic> songs;

  /// Scope passed to [listItemKey] so each usage keeps stable, distinct keys.
  final String listKeyPrefix;
  final bool showPlayButton;

  /// When set, each row shows an add button instead of the overflow menu.
  final void Function(Map song)? onAddSong;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 6),
            child: SectionHeader(
              title: title,
              icon: FluentIcons.sparkle_24_filled,
              actionButton: showPlayButton
                  ? IconButton(
                      onPressed: songs.isEmpty
                          ? null
                          : () async {
                              await audioHandler.playPlaylistSong(
                                playlist: {'title': title, 'list': songs},
                                songIndex: 0,
                                shuffle: false,
                              );
                            },
                      icon: Icon(
                        FluentIcons.play_circle_24_filled,
                        color: colorScheme.primary,
                        size: 30,
                      ),
                    )
                  : null,
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: songs.length,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            itemBuilder: (context, index) {
              final song = songs[index];
              final borderRadius = getItemBorderRadius(index, songs.length);
              return RepaintBoundary(
                key: listItemKey(listKeyPrefix, index, song),
                child: SongBar(
                  song,
                  true,
                  barPadding: const EdgeInsetsDirectional.only(
                    top: 10,
                    bottom: 10,
                    start: 12,
                  ),
                  borderRadius: borderRadius,
                  onAdd: onAddSong != null && song is Map
                      ? () => onAddSong!(song)
                      : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
