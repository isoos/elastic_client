import 'dart:async';
import 'dart:convert' as convert;

import 'package:meta/meta.dart';

/// Communication abstraction for adding multiple layers on top of the basic
/// HTTP client.
abstract class Transport {
  /// Sends [request] and parses the response.
  Future<Response> send(Request request);

  /// Closes the transport client (and any underlying HTTP client).
  Future close();
}

/// Low-level API request.
class Request {
  /// The HTTP method (e.g. 'POST', 'GET', 'DELETE')
  final String method;

  /// The path segments to the API endpoint.
  final List<String> pathSegments;

  /// The body as text.
  final String bodyText;

  /// The HTTP headers being sent alongside the request.
  final Map<String, String> headers;

  /// The query parameters of the request.
  final Map<String, String> params;

  Request._(
      this.method, this.pathSegments, this.bodyText, this.headers, this.params);

  /// Creates a new [Request] object.
  ///
  /// If [bodyMap] is specified, the content will be encoded as JSON, alongside
  /// with the appropriate header.
  factory Request(
    String method,
    List<String> pathSegments, {
    Map<String, dynamic> bodyMap,
    String bodyText,
    Map<String, String> params,
  }) {
    if (bodyMap != null && bodyText != null) {
      throw ArgumentError(
          'Only one of "bodyMap" or "bodyText" must be specified.');
    }
    bodyText ??= bodyMap == null ? null : convert.json.encode(bodyMap);
    final headers =
        bodyText == null ? null : {'Content-Type': 'application/json'};
    return Request._(method, pathSegments, bodyText, headers, params);
  }
}

/// Low-level API response object.
class Response {
  /// The HTTP status code of the response.
  final int statusCode;

  /// The body of the response.
  final String body;

  Map<String, dynamic> _bodyAsMap;
  List _bodyAsList;

  /// Creates a new [Response] object.
  Response(this.statusCode, this.body);

  /// Returns the body parsed as a [Map].
  Map<String, dynamic> get bodyAsMap =>
      _bodyAsMap ??= convert.json.decode(body) as Map<String, dynamic>;

  List get bodyAsList => _bodyAsList ??= convert.json.decode(body) as List;

  void throwIfStatusNotOK({@required String message}) {
    if (statusCode == 200) return;
    throw TransportException(message, statusCode: statusCode, body: body);
  }
}

/// Exception that describes an issue with executing the request.
class TransportException implements Exception {
  /// The message when the exception was thrown.
  final String message;

  /// The status code of the response.
  final int statusCode;

  /// The body text of the response.
  final String body;

  ///
  TransportException(this.message, {this.statusCode, this.body});

  @override
  String toString() {
    return [
      message,
      if (statusCode != null) '$statusCode',
      if (body != null) body,
    ].join('\n');
  }
}
