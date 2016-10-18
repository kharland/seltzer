import 'dart:async';
import 'dart:html';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:seltzer/src/context.dart';
import 'package:seltzer/src/interface.dart';

export 'package:seltzer/seltzer.dart';

/// Initializes `package:seltzer/seltzer.dart` to use [BrowserSeltzerHttp].
///
/// This is appropriate for clients running in Dartium, DDC, and dart2js.
void useSeltzerInTheBrowser() {
  setPlatform(const BrowserSeltzerHttp());
  setWebSocketProvider((String url) => new BrowserSeltzerWebSocket(url));
}

/// An implementation of [SeltzerHttp] that works within the browser.
///
/// The "browser" means support for Dartium, DDC, and dart2js.
class BrowserSeltzerHttp extends PlatformSeltzerHttp {
  /// Use the default browser implementation of [SeltzerHttp].
  @literal
  const factory BrowserSeltzerHttp() = BrowserSeltzerHttp._;

  const BrowserSeltzerHttp._();

  @override
  Future<SeltzerHttpResponse> execute(
    String method,
    String url, {
    Map<String, String> headers: const {},
  }) async {
    return new _HtmlSeltzerHttpResponse(await HttpRequest.request(
      url,
      method: method,
      requestHeaders: headers,
    ));
  }
}

class _HtmlSeltzerHttpResponse implements SeltzerHttpResponse {
  final HttpRequest _request;

  _HtmlSeltzerHttpResponse(this._request);

  @override
  String get payload => _request.responseText;
}

/// A [SeltzerWebSocket] implementation for the browser.
class BrowserSeltzerWebSocket implements SeltzerWebSocket {
  final Completer _onOpenCompleter = new Completer();
  final Completer _onCloseCompleter = new Completer();
  final StreamController<SeltzerMessage> _onMessageController =
      new StreamController<SeltzerMessage>.broadcast();

  StreamSubscription _dataSubscription;
  WebSocket _webSocket;

  /// Creates a new browser web sock connected to the remote peer at [url].
  BrowserSeltzerWebSocket(String url) {
    _webSocket = new WebSocket(url);
    _dataSubscription = _webSocket.onMessage.listen((MessageEvent event) async {
      _onMessageController
          .add(await _BrowserSeltzerMessage.createFromMessageEvent(event));
    });
    _webSocket.onOpen.first.then((_) {
      _onOpenCompleter.complete();
    });
    _webSocket.onClose.first.then((_) {
      _onCloseCompleter.complete();
    });
  }

  @override
  Stream<SeltzerMessage> get onMessage => _onMessageController.stream;

  @override
  Stream get onOpen => _onOpenCompleter.future.asStream();

  @override
  Stream get onClose => _onCloseCompleter.future.asStream();

  @override
  Future close([int code, String reason]) async {
    _errorIfClosed();
    _dataSubscription.cancel();
    _webSocket.close(code, reason);
  }

  @override
  Future sendString(String data) async {
    _errorIfClosed();
    _webSocket.sendString(data);
  }

  @override
  Future sendBytes(ByteBuffer data) async {
    _errorIfClosed();
    _webSocket.sendTypedData(data.asInt8List());
  }

  void _errorIfClosed() {
    if (_webSocket == null || _webSocket.readyState != WebSocket.OPEN) {
      throw new StateError("Socket is closed");
    }
  }
}

class _BrowserSeltzerMessage implements SeltzerMessage {
  @override
  final bool isBinary;
  @override
  final Object payload;

  _BrowserSeltzerMessage(this.payload, this.isBinary);

  static Future<_BrowserSeltzerMessage> createFromMessageEvent(
      MessageEvent message) async {
    if (message.data is String) {
      return new _BrowserSeltzerMessage(message.data, false);
    } else {
      // Message.data is a Blob. we have to decode it before using it.
      var fileReader = new FileReader()..readAsArrayBuffer(message.data);
      await fileReader.onLoadEnd.first;
      return new _BrowserSeltzerMessage(fileReader.result, true);
    }
  }
}
