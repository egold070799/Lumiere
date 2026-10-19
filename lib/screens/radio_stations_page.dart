
import 'package:material_ui/material_ui.dart';
import 'package:lumiere/constants/app_constants.dart';
import 'package:lumiere/database/radio_stations.db.dart';
import 'package:lumiere/extensions/l10n.dart';
import 'package:lumiere/main.dart';
import 'package:lumiere/models/radio_model.dart';
import 'package:lumiere/services/common_services.dart';
import 'package:lumiere/utilities/flutter_toast.dart';
import 'package:lumiere/widgets/mini_player_bottom_space.dart';
import 'package:lumiere/widgets/radio_station_card.dart';

class RadioStationsPage extends StatelessWidget {
  const RadioStationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n!.radioStations)),
      body: ValueListenableBuilder(
        valueListenable: userLikedRadioStations,
        builder: (context, likedStations, _) {
          final stations = _sortWithLikedFirst(
            radioStationsDB,
            likedStations.toSet(),
          );

          if (stations.isEmpty) {
            return Center(child: Text(context.l10n!.noRadioStations));
          }

          return SingleChildScrollView(
            padding: commonSingleChildScrollViewPadding,
            child: Column(
              children: [
                ...List.generate(stations.length, (index) {
                  final station = stations[index];
                  return Padding(
                    key: ValueKey(station.id),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RadioStationCard(
                      station: station,
                      onPressed: () async {
                        final success = await audioHandler.playRadioStream(
                          id: station.id,
                          name: station.name,
                          streamUrl: station.streamUrl,
                          image: station.image,
                          genre: station.genre,
                        );

                        if (!success && context.mounted) {
                          showToast(context, context.l10n!.error);
                        }
                      },
                    ),
                  );
                }),
                const MiniPlayerBottomSpace(),
              ],
            ),
          );
        },
      ),
    );
  }
}

List<RadioStation> _sortWithLikedFirst(
  List<RadioStation> stations,
  Set<String> likedIds,
) {
  final liked = <RadioStation>[];
  final rest = <RadioStation>[];

  for (final station in stations) {
    if (likedIds.contains(station.id)) {
      liked.add(station);
    } else {
      rest.add(station);
    }
  }

  return [...liked, ...rest];
}
