import 'dart:async';

import 'package:http_client/http_client.dart' as http;

import 'transport.dart';

class HttpTransport implements Transport {
  final Uri _uri;
  final http.Client _httpClient;
  final Duration _timeout;

  HttpTransport(
    this._httpClient,
    this._uri, {
    Duration timeout: const Duration(minutes: 1),
  }) : _timeout = timeout;

  @override
  Future<Response> send(Request request) async {
    final newUri = _uri.replace(
        pathSegments: request.pathSegments, queryParameters: request.params);
    final rs = await _httpClient
        .send(new http.Request(
          request.method,
          newUri,
          headers: request.headers,
          body: request.bodyText,
        ))
        .timeout(_timeout);
    return new Response(rs.statusCode, await rs.readAsString());
  }

  @override
  Future close() async {
    await _httpClient.close();
  }
}
