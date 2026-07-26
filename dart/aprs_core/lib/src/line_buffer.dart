/// Incremental record splitter for the APRS-IS byte stream.
///
/// Raw TCP (rotate.aprs2.net:14580) delivers CRLF-delimited records split
/// across arbitrary chunks; a native javAPRSSrvr WebSocket delivers one
/// record per frame with no terminator at all. This class handles both the
/// way the PWA does: split on newlines, and if a connection has never
/// carried a newline, treat each fed chunk as one complete record.
///
/// The same asymmetry applies to SENDING — see frames.dart.
class AprsLineBuffer {
  String _buf = '';
  bool _sawNL = false;

  /// True once any newline has been seen (CRLF-stream transport).
  bool get sawNewline => _sawNL;

  /// Feed one chunk (TCP segment or WS frame); returns completed records.
  List<String> feed(String chunk) {
    final out = <String>[];
    _buf += chunk;
    if (!_sawNL && _buf.contains('\n')) _sawNL = true;
    int i;
    while ((i = _buf.indexOf('\n')) >= 0) {
      final line = _buf.substring(0, i).replaceFirst(RegExp(r'\r$'), '');
      _buf = _buf.substring(i + 1);
      if (line.isNotEmpty) out.add(line);
    }
    if (!_sawNL && _buf.isNotEmpty) {
      final line = _buf.replaceFirst(RegExp(r'\r$'), '');
      _buf = '';
      if (line.isNotEmpty) out.add(line);
    }
    return out;
  }

  /// Reset on reconnect — framing is per-connection.
  void reset() {
    _buf = '';
    _sawNL = false;
  }
}
