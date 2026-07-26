import 'dart:math' as math;

/// TX frame builders — byte-for-byte the strings the PWA transmits
/// (verified against a live javAPRSSrvr session). All return the record
/// WITHOUT a terminator: over raw TCP append CRLF; over a native
/// javAPRSSrvr WebSocket send the record as one frame with no terminator
/// (two bytes of CRLF inside a frame get the packet silently dropped —
/// see PacketMap 2026.07.26.001).

const String tocall = 'APZPKM';

/// Signed degrees → APRS ddmm.mmH / dddmm.mmH.
String degToDm(double v, {required bool isLat}) {
  final hemi = isLat ? (v >= 0 ? 'N' : 'S') : (v >= 0 ? 'E' : 'W');
  v = v.abs();
  final deg = v.floor();
  final min = (v - deg) * 60;
  final dd = deg.toString().padLeft(isLat ? 2 : 3, '0');
  final mm = min.toStringAsFixed(2).padLeft(5, '0');
  return '$dd$mm$hemi';
}

/// Position report (`=`, no timestamp). Course/speed extension is included
/// only when both are known and speed > 0; heading 0 transmits as 360.
String buildPositionFrame({
  required String call,
  required double lat,
  required double lng,
  required String symTable,
  required String symCode,
  int? courseDeg,
  int? speedKnots,
  String comment = '',
}) {
  final la = degToDm(lat, isLat: true);
  final lo = degToDm(lng, isLat: false);
  var ext = '';
  if (speedKnots != null && courseDeg != null && speedKnots > 0) {
    final crs = (courseDeg == 0 ? 360 : courseDeg).toString().padLeft(3, '0');
    final spd = math.min(speedKnots, 999).toString().padLeft(3, '0');
    ext = '$crs/$spd';
  }
  final cmt = comment.length > 43 ? comment.substring(0, 43) : comment;
  return '$call>$tocall,TCPIP*:=$la$symTable$lo$symCode$ext${cmt.isNotEmpty ? ' $cmt' : ''}';
}

/// Directed message: addressee padded to 9, `{id` suffix.
String buildMessageFrame({
  required String call,
  required String to,
  required String text,
  required String id,
}) =>
    '$call>$tocall,TCPIP*::${to.padRight(9)}:$text{$id';

/// Ack for a received message id.
String buildAckFrame({required String call, required String to, required String id}) =>
    '$call>$tocall,TCPIP*::${to.padRight(9)}:ack$id';

/// APRS-IS login line. Terminate with CRLF on every transport — framing is
/// not yet known when it is sent, and both transports accept it.
String buildLogin({
  required String user,
  required int pass,
  required String version,
  required String filter,
}) =>
    'user $user pass $pass vers PacketMap $version filter $filter';

/// Server-side filter: radius + own packets + own-call prefix + watch list.
/// [myCall] is the full call-SSID, [baseCall] the bare call; both empty for
/// receive-only. Watch entries are used verbatim (trailing * allowed).
String buildFilter({
  required double lat,
  required double lng,
  required int radiusKm,
  String myCall = '',
  String baseCall = '',
  List<String> watch = const [],
}) {
  var f = 'r/${lat.toStringAsFixed(3)}/${lng.toStringAsFixed(3)}/$radiusKm';
  if (myCall.isNotEmpty) f += ' g/$myCall b/$baseCall*';
  for (final w in watch) {
    f += ' b/$w';
  }
  return f;
}

/// Mid-session filter update (send after login, terminated per transport).
String buildFilterUpdate(String filter) => '#filter $filter';
