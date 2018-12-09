import 'dart:async';

import 'package:http_client/http_client.dart' as http;

import 'transport.dart';

import 'dart:convert' as convert;

class HttpTransport implements Transport {
  final Uri _uri;
  final http.Client _httpClient;
  final Duration _timeout;
  final BasicAuth _basicAuth;

  HttpTransport(this._httpClient, this._uri,
      {Duration timeout: const Duration(minutes: 1), BasicAuth basicAuth})
      : _timeout = timeout,
        _basicAuth = basicAuth;

  @override
  Future<Response> send(Request request) async {
    final newUri = _uri.replace(
        pathSegments: request.pathSegments, queryParameters: request.params);
    final rs = await _httpClient
        .send(new http.Request(
          request.method,
          newUri,
          headers: _mergeHeader(request.headers),
          body: request.bodyText,
        ))
        .timeout(_timeout);
    return new Response(rs.statusCode, await rs.readAsString());
  }

  @override
  Future close() async {
    await _httpClient.close();
  }

  Map<String, String> _mergeHeader(Map<String, String> headerToMerge) {
    return _basicAuth == null ? headerToMerge : Map.from(_basicAuth.toMap())
      ..addAll(headerToMerge);
  }
}

class BasicAuth {
  final String username;
  final String password;
  BasicAuth(this.username, this.password);
  Map<String, String> toMap() {
    final up = convert.utf8.encode('$username:$password');
    return {'Authorization': 'Basic ${convert.base64Encode(up)}'};
  }
}
