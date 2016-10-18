import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:seltzer/src/context.dart';
import 'package:seltzer/src/interface.dart';

export 'package:seltzer/seltzer.dart';

/// Initializes `package:seltzer/seltzer.dart` to use [ServerSeltzerHttp].
///
/// This is appropriate for clients running in the VM on the command line.
void useSeltzerInTheServer() {
  setPlatform(const ServerSeltzerHttp());
  setWebSocketProvider((String url) => new ServerSeltzerWebSocket(url));
}

/// An implementation of [SeltzerHttp] that works within the browser.
///
/// The "server" means in the Dart VM on the command line.
class ServerSeltzerHttp extends PlatformSeltzerHttp {
  /// Use the default server implementation of [SeltzerHttp].
  @literal
  const factory ServerSeltzerHttp() = ServerSeltzerHttp._;

  const ServerSeltzerHttp._();

  @override
  Future<SeltzerHttpResponse> execute(
    String method,
    String url, {
    Map<String, String> headers,
  }) async {
    var request = await new HttpClient().openUrl(method, Uri.parse(url));
    headers.forEach(request.headers.add);
    var response = await request.close();
    var payload = await UTF8.decodeStream(response);
    return new _IOSeltzerHttpResponse(payload);
  }
}

class _IOSeltzerHttpResponse implements SeltzerHttpResponse {
  @override
  final String payload;

  _IOSeltzerHttpResponse(this.payload);
}

/// A [SeltzerWebSocket] implementation for the dart vm.
class ServerSeltzerWebSocket implements SeltzerWebSocket {
  static final _SOCKET_CLOSED_ERROR = new StateError("Socket is closed");

  final Completer _onOpenCompleter = new Completer();
  final Completer _onCloseCompleter = new Completer();
  final StreamController<SeltzerMessage> _onMessageController =
      new StreamController<SeltzerMessage>.broadcast();

  /// This is needed because dart:io WebSockets don't offer a reliable method
  /// for determining when a socket has closed. With this implementation,
  /// [onClose] will emit immediately after calling [close] while the underlying
  /// web socket closes its actual connection in the background.
  bool _isOpen = false;
  StreamSubscription _messageSubscription;
  WebSocket _webSocket;

  /// Creates a new server web sock connected to the remote peer at [url].
  ServerSeltzerWebSocket(String url) {
    WebSocket.connect(url).then((WebSocket webSocket) {
      _webSocket = webSocket;
      _messageSubscription = _webSocket.listen((payload) {
        _onMessageController
            .add(new _ServerSeltzerMessage(payload, payload is! String));
      });
      _isOpen = true;
      _onOpenCompleter.complete();
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
    _isOpen = false;
    _messageSubscription.cancel();
    _webSocket.close(code, reason);
    _onCloseCompleter.complete();
  }

  @override
  Future sendString(String data) async {
    _errorIfClosed();
    _webSocket.add(data);
  }

  @override
  Future sendBytes(ByteBuffer data) async {
    _errorIfClosed();
    _webSocket.add(data.asInt8List());
  }

  void _errorIfClosed() {
    if (!_isOpen) {
      throw _SOCKET_CLOSED_ERROR;
    }
  }
}

class _ServerSeltzerMessage implements SeltzerMessage {
  @override
  final bool isBinary;
  @override
  final Object payload;

  _ServerSeltzerMessage(this.payload, this.isBinary);
}
