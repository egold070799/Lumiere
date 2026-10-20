import 'dart:async';

import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// Rewrites YouTube requests to a same-origin Vercel function so browsers do
/// not make cross-origin requests to endpoints that do not enable CORS.
class _YoutubeProxyBrowserClient extends http.BaseClient {
  final BrowserClient _browser = BrowserClient();

  static const _supportedHosts = {
    'www.youtube.com',
    'music.youtube.com',
    'youtubei.googleapis.com',
  };

  Uri _proxyUri(Uri uri) {
    final host = uri.host.toLowerCase();
    final isGoogleVideo = host.endsWith('.googlevideo.com');
    if (!_supportedHosts.contains(host) && !isGoogleVideo) {
      throw http.ClientException('Unsupported YouTube proxy host: $host', uri);
    }

    final origin = Uri.base;
    return origin.replace(
      path: '/api/youtube',
      queryParameters: {'url': uri.toString()},
      fragment: '',
    );
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final target = http.StreamedRequest(request.method, _proxyUri(request.url))
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection;
    const browserManagedHeaders = {
      'accept-language',
      'cookie',
      'host',
      'origin',
      'referer',
      'user-agent',
    };
    request.headers.forEach((name, value) {
      if (!browserManagedHeaders.contains(name.toLowerCase())) {
        target.headers[name] = value;
      }
    });
    if (request.contentLength != null) {
      target.contentLength = request.contentLength;
    }

    unawaited(request.finalize().pipe(target.sink));
    return _browser.send(target);
  }

  @override
  void close() => _browser.close();
}

http.Client createYoutubeHttpTransport() => _YoutubeProxyBrowserClient();
