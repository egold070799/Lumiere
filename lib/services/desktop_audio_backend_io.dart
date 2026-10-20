import 'package:just_audio_media_kit/just_audio_media_kit.dart';

void initializeDesktopAudioBackend(String title) {
  JustAudioMediaKit.title = title;
  JustAudioMediaKit.ensureInitialized();
}
