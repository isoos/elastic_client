import 'dart:convert' as convert;

import 'package:http/http.dart' as http;
import 'package:http_client/http_client.dart' as http_client;
import 'package:http_client/pkg_http_adapter.dart' as pkg_http_adapter;
import 'package:meta/meta.dart';

import 'elastic_client_impl.dart';

/// The default transport implementation over HTTP.
class HttpTransport implements Transport {
  final Uri _uri;
  final http.Client _httpClient;
  final Duration _timeout;
  final String? _authorization;
  final bool _shouldCloseClient;

  /// Creates a new HttpTransport instance.
  HttpTransport({
    @required /* String | Uri */ dynamic url,
    dynamic client,
    Duration timeout = const Duration(minutes: 1),
    String? authorization,
  })  : _httpClient = _castClient(client),
        _shouldCloseClient = client != null,
        _uri = _castUri(url),
        _timeout = timeout,
        _authorization = authorization;

  @override
  Future<Response> send(Request request) async {
    final pathSegments = <String>[
      ..._uri.pathSegments,
      ...request.pathSegments,
    ];
    final newUri = _uri.replace(
        pathSegments: pathSegments, queryParameters: request.params);
    final rq = http.Request(request.method, newUri);
    if (_authorization != null) {
      rq.headers['Authorization'] = _authorization!;
    }
    if (request.headers != null) {
      rq.headers.addAll(request.headers!);
    }
    if (request.bodyText != null) {
      rq.body = request.bodyText!;
    }
    final rs = await _httpClient.send(rq).timeout(_timeout);
    final warning = rs.headers['warning'];
    return Response(rs.statusCode, await rs.stream.bytesToString(),
        warning: warning);
  }

  @override
  Future close() async {
    if (_shouldCloseClient) {
      _httpClient.close();
    }
  }
}

/// Creates the `Basic` authorization header with [username] and [password].
String basicAuthorization(String username, String password) {
  final up = convert.utf8.encode('$username:$password');
  return 'Basic ${convert.base64Encode(up)}';
}

Uri _castUri(dynamic url) {
  ArgumentError.checkNotNull(url, 'url');
  if (url is String) return Uri.parse(url);
  if (url is Uri) return url;
  throw ArgumentError('Unknown URI type: $url');
}

http.Client _castClient(dynamic client) {
  if (client == null) return http.Client();
  if (client is http.Client) return client;
  if (client is http_client.Client) {
    return pkg_http_adapter.PkgHttpAdapter(client);
  }
  throw ArgumentError('Unknown HTTP client: $client.');
}
