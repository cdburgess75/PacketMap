/// Decoded APRS packet. Field names mirror the PWA parser (index.html,
/// "APRS parser" section) so the two implementations can be diffed.
class AprsPacket {
  AprsPacket({required this.src, required this.dest, required this.path, required this.raw});

  final String src;
  final String dest;
  final List<String> path;
  final String raw;

  /// "pos" | "msg" | "status" | "wx" | "other" | null (unparseable body).
  String? type;

  // objects / items
  String? name; // object/item name; stations keyed by this when set
  bool obj = false;
  bool kill = false;

  // messages
  String? to;
  String? text;
  String? msgId;
  String? ack;
  String? rej;

  // status
  String? status;

  // position
  double? lat;
  double? lng;
  String? symT; // table: "/" primary, "\" alternate
  String? symC; // symbol code
  String? symO; // overlay char (compressed a–j digit overlays)
  int? course; // degrees
  int? speed; // knots
  int? alt; // feet
  String? phg; // 4 digits, e.g. "5130"
  int? rng; // advertised radio range, miles
  String? comment;

  Wx? wx;

  @override
  String toString() =>
      'AprsPacket(src: $src, type: $type, lat: $lat, lng: $lng, symT: $symT, '
      'symC: $symC, to: $to, text: $text, msgId: $msgId, ack: $ack, comment: $comment)';
}

/// Weather fields, US units as sent on the air.
class Wx {
  int? windDir; // degrees
  int? windSpd; // mph
  int? gust; // mph
  int? temp; // °F
  double? rain1h; // inches
  double? rain24h; // inches
  double? rainMid; // inches since midnight
  int? hum; // %
  double? baro; // mb

  bool get isEmpty =>
      windDir == null && windSpd == null && gust == null && temp == null &&
      rain1h == null && rain24h == null && rainMid == null && hum == null && baro == null;
}
