import 'package:lumiere/services/youtube_http_transport_stub.dart'
    if (dart.library.html) 'package:lumiere/services/youtube_http_transport_web.dart'
    as transport;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Creates the HTTP client used by YouTube metadata and playback requests.
/// Web requests go through the same-origin, host-restricted Vercel function.
YoutubeHttpClient createYoutubeHttpClient() =>
    YoutubeHttpClient(transport.createYoutubeHttpTransport());
