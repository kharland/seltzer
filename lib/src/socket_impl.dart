import 'dart:async';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:seltzer/src/interface.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A cross-platform [SeltzerWebSocket] implementation.
class SeltzerWebSocketImpl implements SeltzerWebSocket {
  final Completer<SeltzerSocketClosedEvent> _onCloseCompleter =
      new Completer<SeltzerSocketClosedEvent>();
  final StreamSplitter<SeltzerMessage> _messageStreamSplitter;
  final WebSocketChannel _delegate;

  bool _isOpen = true;

  /// Creates a [SeltzerWebSocketImpl] that communicates through [channel].
  SeltzerWebSocketImpl(WebSocketChannel channel)
      : _delegate = channel,
        _messageStreamSplitter =
            new StreamSplitter(channel.stream.asyncMap(_decodeSocketMessage)) {
    _delegate.sink.done.then((_) {
      _triggerClose();
    });
  }

  Stream<SeltzerMessage> get onMessage => _messageStreamSplitter.split();

  Future<SeltzerSocketClosedEvent> get onClose => _onCloseCompleter.future;

  void close({int code, String reason}) {
    _errorIfClosed();
    _delegate.sink.close(code, reason);
  }

  void sendBytes(ByteBuffer data) {
    _errorIfClosed();
    _delegate.sink.add(data.asInt8List());
  }

  void sendString(String data) {
    _errorIfClosed();
    _delegate.sink.add(data);
  }

  void _errorIfClosed() {
    if (!_isOpen) {
      throw new StateError('Socket is closed.');
    }
  }

  static Future<SeltzerMessage> _decodeSocketMessage(payload) async {
    if (payload is ByteBuffer) {
      return new SeltzerMessage.fromBytes(payload.asUint8List());
    }
    if (payload is TypedData) {
      return new SeltzerMessage.fromBytes(payload.buffer.asUint8List());
    }
    return new SeltzerMessage.fromString(payload);
  }

  void _triggerClose() {
    if (_isOpen) {
      _isOpen = false;
      _onCloseCompleter.complete(
        new SeltzerSocketClosedEvent(
          _delegate.closeCode,
          _delegate.closeReason,
        ),
      );
    }
  }
}