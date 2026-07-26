import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aprs_core/aprs_core.dart';

/// Where the link is, for the header dot.
enum LinkState { offline, connecting, loggedIn }

/// APRS-IS over a raw TCP socket.
///
/// Native platforms can open sockets, so this talks to the APRS-IS core pool
/// directly — no WebSocket bridge, and no frame-vs-CRLF ambiguity: the TCP
/// stream is always CRLF-delimited. [AprsLineBuffer] still does the splitting,
/// because records arrive across arbitrary segment boundaries.
class AprsIsClient {
  AprsIsClient({
    this.host = 'rotate.aprs2.net',
    this.port = 14580,
    required this.appVersion,
  });

  final String host;
  final int port;
  final String appVersion;

  Socket? _sock;
  StreamSubscription<List<int>>? _sub;
  final _lines = AprsLineBuffer();
  Timer? _reconnect;
  Duration _backoff = const Duration(seconds: 1);
  bool _closedByUs = false;

  bool _connected = false; // server sent "# logresp"
  bool _verified = false; // ...and accepted our passcode
  DateTime _lastRx = DateTime.fromMillisecondsSinceEpoch(0);

  bool get connected => _connected;
  bool get verified => _verified;
  DateTime get lastRx => _lastRx;

  /// Login parameters, supplied fresh on every (re)connect.
  String Function() callsign = () => '';
  String Function() baseCall = () => '';
  String Function() filter = () => '';

  final _packets = StreamController<AprsPacket>.broadcast();
  final _raw = StreamController<RawLine>.broadcast();
  final _state = StreamController<LinkState>.broadcast();

  Stream<AprsPacket> get packets => _packets.stream;

  /// Every line in and out, for the RAW tab.
  Stream<RawLine> get rawLines => _raw.stream;
  Stream<LinkState> get state => _state.stream;

  /// The server keepalive is ~20 s. Silence past this means the socket is a
  /// corpse — on mobile it can look open long after the OS tore it down — and
  /// anything "sent" into it would vanish without an error.
  static const staleAfter = Duration(seconds: 90);

  bool get linkAlive =>
      _sock != null && _connected && DateTime.now().difference(_lastRx) < staleAfter;

  Future<void> connect() async {
    _reconnect?.cancel();
    await _teardown();
    _closedByUs = false;
    _state.add(LinkState.connecting);
    try {
      final s = await Socket.connect(host, port, timeout: const Duration(seconds: 12));
      _sock = s;
      _lines.reset();
      _lastRx = DateTime.now();
      _sub = s.listen(_onData, onError: (_) => _dropped(), onDone: _dropped, cancelOnError: true);
      // Login is always CRLF-terminated; see aprs_core/frames.dart.
      final mine = callsign();
      final line = buildLogin(
        user: mine.isEmpty ? _anonCall() : mine,
        pass: mine.isEmpty ? -1 : passcode(baseCall()),
        version: appVersion,
        filter: filter(),
      );
      _write(line);
    } catch (_) {
      _dropped();
    }
  }

  /// Receive-only logins still need a name; some servers blacklist N0CALL.
  String _anonCall() => 'PMAP${(DateTime.now().millisecondsSinceEpoch % 9000) + 1000}';

  void _onData(List<int> chunk) {
    _lastRx = DateTime.now();
    // APRS is latin-1 on the wire; never let a stray byte kill the stream.
    for (final line in _lines.feed(latin1.decode(chunk, allowInvalid: true))) {
      _handle(line);
    }
  }

  void _handle(String line) {
    _raw.add(RawLine(line, mine: false));
    if (line.startsWith('#')) {
      if (line.contains('logresp')) {
        _connected = true;
        _verified = RegExp(r'\bverified\b').hasMatch(line);
        _backoff = const Duration(seconds: 1);
        _state.add(LinkState.loggedIn);
      }
      return;
    }
    final p = parsePacket(line);
    if (p != null) _packets.add(p);
  }

  /// Send one record. Returns false when the link is not demonstrably alive,
  /// so callers can retry instead of believing a send that went nowhere.
  bool send(String record) {
    if (!linkAlive) return false;
    _write(record);
    _raw.add(RawLine(record, mine: true));
    return true;
  }

  void _write(String record) {
    try {
      _sock?.write('$record\r\n');
    } catch (_) {
      _dropped();
    }
  }

  /// Push a new server-side filter without reconnecting.
  void pushFilter() {
    if (_sock != null && _connected) _write(buildFilterUpdate(filter()));
  }

  void _dropped() {
    if (_closedByUs) return;
    _connected = false;
    _verified = false;
    _state.add(LinkState.offline);
    _teardown();
    _reconnect?.cancel();
    _reconnect = Timer(_backoff, connect);
    final next = _backoff * 2;
    _backoff = next > const Duration(seconds: 30) ? const Duration(seconds: 30) : next;
  }

  /// Call when the app returns to the foreground, or the network comes back.
  /// A phone can suspend the process and leave a dead socket looking fine, so
  /// verify rather than trust, and skip the backoff — the user is waiting.
  void revive() {
    if (linkAlive) return;
    _backoff = const Duration(seconds: 1);
    _reconnect?.cancel();
    connect();
  }

  /// Watchdog: close a socket that has gone quiet so the reconnect path runs.
  void tickWatchdog() {
    if (_sock != null && _connected && DateTime.now().difference(_lastRx) > staleAfter) {
      _dropped();
    }
  }

  Future<void> _teardown() async {
    await _sub?.cancel();
    _sub = null;
    try {
      _sock?.destroy();
    } catch (_) {}
    _sock = null;
  }

  Future<void> dispose() async {
    _closedByUs = true;
    _reconnect?.cancel();
    await _teardown();
    await _packets.close();
    await _raw.close();
    await _state.close();
  }
}

/// A line for the RAW console; [mine] marks what we transmitted.
class RawLine {
  RawLine(this.text, {required this.mine}) : t = DateTime.now();
  final String text;
  final bool mine;
  final DateTime t;
}
