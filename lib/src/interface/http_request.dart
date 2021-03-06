import 'dart:async';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:quiver/core.dart';

import 'http.dart';
import 'package:seltzer/src/interface/http_response.dart';

class _NullSeltzerHttpHandler extends SeltzerHttpHandler {
  const _NullSeltzerHttpHandler();

  @override
  Stream<SeltzerHttpResponse> handle(SeltzerHttpRequest request, [_]) {
    throw new UnsupportedError(
      'Cannot send requests - this was created as a standalone object',
    );
  }
}

/// An HTTP request object.
///
/// Use [SeltzerHttpRequest.send] to receive a [Stream] interface.
///
/// In most simple use cases [Stream.first] will connect and return a value:
///     get('some/url.json').send().first.then((value) => print('Got: $value'));
///
/// Some implementations of [SeltzerHttp] may choose to allow multiple responses
/// and/or respond with a local cache first, and then make a response against
/// the server. In that case, [Stream.listen] may be preferred:
///     get('some/url.json').send().listen((value) => print('Got: $value'));
abstract class SeltzerHttpRequest {
  /// Creates a new standalone request that _cannot be sent_.
  factory SeltzerHttpRequest(
    String method,
    String url, {
    Map<String, String> headers: const {},
  }) =>
      new SeltzerHttpRequest.fromHandler(
        const _NullSeltzerHttpHandler(),
        headers: headers,
        method: method,
        url: url,
      );

  /// Create a default implementation from a [handler].
  factory SeltzerHttpRequest.fromHandler(
    SeltzerHttpHandler handler, {
    Map<String, String> headers,
    @required String method,
    @required String url,
  }) = _DefaultSeltzerHttpRequest;

  /// HTTP headers.
  Map<String, String> get headers;

  /// HTTP method to use.
  String get method;

  /// URL to send the request to.
  String get url;

  /// Makes the HTTP request, and returns a [Stream] of results.
  Stream<SeltzerHttpResponse> send([Object payload]);
}

/// A partial implementation of [SeltzerHttpRequest].
abstract class SeltzerHtpRequestMixin implements SeltzerHttpRequest {
  static const Equality _equality = const SeltzerHttpRequestEquality();

  @override
  int get hashCode => _equality.hash(this);

  @override
  bool operator ==(Object o) => _equality.equals(this, o);

  toJson() {
    return {
      'headers': headers,
      'method': method,
      'url': url,
    };
  }
}

/// A partial implementation of [SeltzerHttpRequest].
///
/// The only missing implementation is [send].
abstract class SeltzerHttpRequestBase extends SeltzerHtpRequestMixin {
  @override
  final Map<String, String> headers;

  @override
  final String method;

  @override
  final String url;

  SeltzerHttpRequestBase({
    Map<String, String> headers,
    @required this.method,
    @required this.url,
  })
      : this.headers = headers ?? <String, String>{};

  @override
  String toString() => '$method $url {headers: ${headers.length}}';
}

/// A reusable [Equality] implementation for [SeltzerHttpRequest].
///
/// The default implementation of equality for requests.
class SeltzerHttpRequestEquality implements Equality<SeltzerHttpRequest> {
  static const Equality _mapEquality = const MapEquality();

  @literal
  const SeltzerHttpRequestEquality();

  @override
  bool equals(SeltzerHttpRequest e1, SeltzerHttpRequest e2) {
    return _mapEquality.equals(e1.headers, e2.headers) &&
        e1.method == e2.method &&
        e1.url == e2.url;
  }

  @override
  int hash(SeltzerHttpRequest e) {
    return hash3(
      _mapEquality.hash(e.headers),
      e.method,
      e.url,
    );
  }

  @override
  bool isValidKey(Object o) => o is SeltzerHttpRequest;
}

/// A platform independent implementation of [SeltzerHttpRequest].
///
/// Relies on delegating to a [SeltzerHttpHandler] instance, which is usually
/// the originating factory that created this object.
class _DefaultSeltzerHttpRequest extends SeltzerHttpRequestBase {
  final SeltzerHttpHandler _handler;

  _DefaultSeltzerHttpRequest(
    this._handler, {
    Map<String, String> headers,
    @required String method,
    @required String url,
  })
      : super(headers: headers, method: method, url: url);

  @override
  Stream<SeltzerHttpResponse> send([Object payload]) {
    return _handler.handle(this, payload);
  }
}
