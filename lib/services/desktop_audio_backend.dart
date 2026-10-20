import 'desktop_audio_backend_stub.dart'
    if (dart.library.html) 'desktop_audio_backend_stub.dart'
    if (dart.library.io) 'desktop_audio_backend_io.dart'
    as backend;

void initializeDesktopAudioBackend(String title) {
  backend.initializeDesktopAudioBackend(title);
}
