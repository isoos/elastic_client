import 'dart:async';
import 'dart:convert' as convert;

abstract class Transport {
  Future<Response> send(Request request);
  Future close();
}

class Request {
  final String method;
  final List<String> pathSegments;
  final String bodyText;
  final Map<String, String> headers;
  final Map<String, String> params;

  Request._(
      this.method, this.pathSegments, this.bodyText, this.headers, this.params);

  factory Request(
    String method,
    List<String> pathSegments, {
    Map<String, dynamic> bodyMap,
    String bodyText,
    Map<String, String> params,
  }) {
    bodyText ??= bodyMap == null ? null : convert.json.encode(bodyMap);
    final headers =
        bodyText == null ? null : {'Content-Type': 'application/json'};
    return new Request._(
        method, pathSegments, bodyText, headers, params);
  }
}

class Response {
  final int statusCode;
  final String body;

  Response(this.statusCode, this.body);

  Map get bodyAsMap => convert.json.decode(body) as Map;
}
