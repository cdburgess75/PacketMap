import 'dart:math' as math;

import 'packet.dart';

/// APRS packet parser — a line-for-line port of the PWA parser
/// (index.html, "APRS parser" section). Behaviour quirks are kept on
/// purpose so both implementations pass the same test vectors.
///
/// Returns null when the line has no `SRC>DEST` header or an empty body.
/// A packet whose body could not be decoded comes back with type "other"
/// (or null type on a malformed message body), never an exception.
AprsPacket? parsePacket(String line) {
  final gt = line.indexOf('>');
  if (gt < 1) return null;
  final colon = line.indexOf(':', gt);
  if (colon < 0) return null;
  final src = line.substring(0, gt);
  final hdr = line.substring(gt + 1, colon).split(',');
  final dest = hdr.isNotEmpty ? hdr[0] : '';
  final path = hdr.length > 1 ? hdr.sublist(1) : <String>[];
  final body = line.substring(colon + 1);
  if (body.isEmpty) return null;
  final dt = body[0];
  final p = AprsPacket(src: src, dest: dest, path: path, raw: line);
  try {
    if (dt == '!' || dt == '=') return _finishPos(p, body.substring(1));
    if (dt == '/' || dt == '@') return _finishPos(p, _safeSub(body, 8));
    if (dt == '`' || dt == "'") return _parseMicE(p, body);
    if (dt == ';') {
      // object: 9-char name, live/kill, 7-char timestamp, then position
      p.name = _slice(body, 1, 10).trim();
      p.obj = true;
      p.kill = body.length > 10 && body[10] == '_';
      return _finishPos(p, _safeSub(body, 18));
    }
    if (dt == ')') {
      // item: name 3-9 chars ended by ! or _
      final m = RegExp(r'^([^!_]{3,9})([!_])').firstMatch(body.substring(1));
      if (m == null) return p;
      p.name = m.group(1)!.trim();
      p.obj = true;
      p.kill = m.group(2) == '_';
      return _finishPos(p, body.substring(1 + m.group(1)!.length + 1));
    }
    if (dt == ':') {
      // message: 9-char padded addressee, ":", text, optional {id
      if (body.length < 11 || body[10] != ':') return p;
      p.type = 'msg';
      p.to = _slice(body, 1, 10).trim();
      var text = body.substring(11);
      final idm = RegExp(r'\{([A-Za-z0-9]{1,5})$').firstMatch(text);
      if (idm != null) {
        p.msgId = idm.group(1);
        text = text.substring(0, text.length - (idm.group(1)!.length + 1));
      }
      final am = RegExp(r'^ack([A-Za-z0-9]{1,5})$').firstMatch(text);
      final rm = RegExp(r'^rej([A-Za-z0-9]{1,5})$').firstMatch(text);
      if (am != null) {
        p.ack = am.group(1);
      } else if (rm != null) {
        p.rej = rm.group(1);
      } else {
        p.text = text;
      }
      return p;
    }
    if (dt == '>') {
      p.type = 'status';
      p.status = body.substring(1);
      return p;
    }
    if (dt == '_') {
      // positionless weather: "_" + 8-digit timestamp, then wx fields
      p.type = 'wx';
      p.wx = parseWx(_safeSub(body, 9));
      return p;
    }
  } catch (_) {}
  p.type = 'other';
  return p;
}

/// True when [to] is a bulletin/announcement slot (BLN0–BLN9, BLNA–BLNZ).
bool isBulletinAddressee(String to) => RegExp(r'^BLN[0-9A-Z]$').hasMatch(to.toUpperCase());

String _slice(String s, int a, int b) => s.substring(a, math.min(b, s.length));
String _safeSub(String s, int a) => a >= s.length ? '' : s.substring(a);

/// position body: either uncompressed (starts with digit) or compressed
AprsPacket _finishPos(AprsPacket p, String s) {
  if (s.isEmpty) return p;
  if (RegExp(r'[0-9]').hasMatch(s[0])) {
    // uncompressed: ddmm.mmN T dddmm.mmW C ...
    if (s.length < 19) return p;
    final lat = dmToDeg(s.substring(0, 7), s[7], 2);
    final symT = s[8];
    final lng = dmToDeg(s.substring(9, 17), s[17], 3);
    final symC = s[18];
    if (lat == null || lng == null) return p;
    p.type = 'pos';
    p.lat = lat;
    p.lng = lng;
    p.symT = symT;
    p.symC = symC;
    _parseExt(p, s.substring(19));
    return p;
  }
  if (RegExp(r'^[/\\A-Za-j]').hasMatch(s[0]) && s.length >= 13) {
    // compressed base91
    final latv = base91(s.substring(1, 5));
    final lonv = base91(s.substring(5, 9));
    if (latv == null || lonv == null) return p;
    p.type = 'pos';
    p.lat = 90 - latv / 380926;
    p.lng = -180 + lonv / 190463;
    final t = s[0];
    if (t.compareTo('a') >= 0 && t.compareTo('j') <= 0) {
      // a-j = digit overlays 0-9 on the alternate table
      p.symT = r'\';
      p.symO = String.fromCharCode(t.codeUnitAt(0) - 49);
    } else {
      p.symT = t;
    }
    p.symC = s[9];
    final c1 = s.codeUnitAt(10) - 33, c2 = s.codeUnitAt(11) - 33, T = s.codeUnitAt(12) - 33;
    if (s[10] != ' ' && c1 >= 0) {
      if ((T & 0x18) == 0x10) {
        // cs = altitude (ft) — the 0.3048*3.28084 pair is a PWA quirk kept for parity
        p.alt = (math.pow(1.002, c1 * 91 + c2) * 0.3048 * 3.28084).round();
      } else if ((T & 0x18) == 0x08) {
        p.rng = (2 * math.pow(1.08, c2)).round(); // cs = radio range (mi)
      } else if (c1 <= 89) {
        p.course = c1 * 4;
        p.speed = (math.pow(1.08, c2) - 1).round(); // knots
      }
    }
    p.comment = _safeSub(s, 13).trim();
    _extractAlt(p);
    if (p.symC == '_') {
      p.wx = parseWx(p.comment ?? '');
      p.comment = '';
    }
    return p;
  }
  return p;
}

/// ddmm.mm + hemisphere → signed degrees. Position-ambiguity spaces read
/// as "5" (cell centre). Returns null on garbage.
double? dmToDeg(String dm, String hemi, int degDigits) {
  dm = dm.replaceAll(' ', '5');
  final deg = int.tryParse(dm.substring(0, degDigits));
  final min = double.tryParse(dm.substring(degDigits));
  if (deg == null || min == null) return null;
  var v = deg + min / 60;
  if (hemi == 'S' || hemi == 'W') v = -v;
  if (hemi != 'N' && hemi != 'S' && hemi != 'E' && hemi != 'W') return null;
  return v;
}

/// APRS base91: chars '!'..'{' → value. Null on any out-of-range char.
int? base91(String s) {
  var v = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i) - 33;
    if (c < 0 || c > 90) return null;
    v = v * 91 + c;
  }
  return v;
}

/// uncompressed data extension + comment
void _parseExt(AprsPacket p, String s) {
  var rest = s;
  if (p.symC == '_') {
    // weather report: wind dir/speed then wx fields
    final m = RegExp(r'^(\d{3}|\.{3}|\s{3})/(\d{3}|\.{3}|\s{3})').firstMatch(rest);
    var wxs = rest;
    if (m != null) {
      if (RegExp(r'\d').hasMatch(m.group(1)!)) p.course = int.parse(m.group(1)!);
      if (RegExp(r'\d').hasMatch(m.group(2)!)) p.speed = int.parse(m.group(2)!);
      wxs = rest.substring(7);
    }
    p.wx = parseWx(wxs);
    p.comment = '';
    return;
  }
  final cs = RegExp(r'^(\d{3})/(\d{3})').firstMatch(rest);
  if (cs != null) {
    p.course = int.parse(cs.group(1)!);
    p.speed = int.parse(cs.group(2)!);
    rest = rest.substring(7);
  }
  final phg = RegExp(r'^PHG(\d{4})').firstMatch(rest);
  if (phg != null) {
    p.phg = phg.group(1);
    rest = rest.substring(7);
  }
  final rng = RegExp(r'^RNG(\d{4})').firstMatch(rest);
  if (rng != null) {
    p.rng = int.parse(rng.group(1)!);
    rest = rest.substring(7);
  }
  p.comment = rest.trim();
  _extractAlt(p);
}

void _extractAlt(AprsPacket p) {
  final c = p.comment;
  if (c == null || c.isEmpty) return;
  final am = RegExp(r'/A=(-?\d{6})').firstMatch(c);
  if (am != null) {
    p.alt = int.parse(am.group(1)!);
    p.comment = c.replaceFirst(am.group(0)!, '').trim();
  }
  _applyDao(p);
}

/// !DAO! addendum (APRS 1.2): one extra digit of lat/lon minute precision.
/// Uppercase datum = human-readable digits (thousandths of a minute),
/// lowercase = base-91. Token is stripped from the comment.
void _applyDao(AprsPacket p) {
  final c = p.comment;
  if (c == null || c.isEmpty || p.lat == null) return;
  final m = RegExp(r'!([A-Za-z])(.)(.)!').firstMatch(c);
  if (m == null) return;
  final a = m.group(2)!, o = m.group(3)!;
  double dLat, dLon;
  final datum = m.group(1)!;
  if (datum.compareTo('A') >= 0 && datum.compareTo('Z') <= 0) {
    if (!RegExp(r'^\d$').hasMatch(a) || !RegExp(r'^\d$').hasMatch(o)) return;
    dLat = int.parse(a) / 1000;
    dLon = int.parse(o) / 1000;
  } else {
    final ca = a.codeUnitAt(0) - 33, co = o.codeUnitAt(0) - 33;
    if (ca < 0 || ca > 90 || co < 0 || co > 90) return;
    dLat = ca / 91 * 0.01;
    dLon = co / 91 * 0.01;
  }
  p.lat = p.lat! + (p.lat! < 0 ? -1 : 1) * dLat / 60;
  p.lng = p.lng! + (p.lng! < 0 ? -1 : 1) * dLon / 60;
  p.comment = c.replaceFirst(m.group(0)!, '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
}

/// Weather field soup → [Wx] (US units as sent). Null when nothing decodes.
Wx? parseWx(String s) {
  if (s.isEmpty) return null;
  final wx = Wx();
  String? grab(String re) {
    final m = RegExp(re).firstMatch(s);
    if (m != null && RegExp(r'\d').hasMatch(m.group(1)!)) return m.group(1);
    return null;
  }

  final g = grab(r'g(\d{3})');
  if (g != null) wx.gust = int.parse(g);
  final t = grab(r't(-?\d{2,3})');
  if (t != null) wx.temp = int.parse(t);
  final r = grab(r'r(\d{3})');
  if (r != null) wx.rain1h = int.parse(r) / 100;
  final pp = grab(r'p(\d{3})');
  if (pp != null) wx.rain24h = int.parse(pp) / 100;
  final pm = grab(r'P(\d{3})');
  if (pm != null) wx.rainMid = int.parse(pm) / 100;
  final h = grab(r'h(\d{2})');
  if (h != null) {
    final n = int.parse(h);
    wx.hum = n == 0 ? 100 : n;
  }
  final b = grab(r'b(\d{4,5})');
  if (b != null) wx.baro = int.parse(b) / 10;
  final wnd = RegExp(r'(\d{3})/(\d{3})').firstMatch(s);
  if (wnd != null) {
    wx.windDir = int.parse(wnd.group(1)!);
    wx.windSpd = int.parse(wnd.group(2)!);
  }
  return wx.isEmpty ? null : wx;
}

/// Mic-E: latitude + message bits ride in the AX.25 destination field.
/// Do not touch without running the test vectors (CLAUDE.md rule).
AprsPacket _parseMicE(AprsPacket p, String body) {
  final d = p.dest;
  if (d.length < 6 || body.length < 9) return p;
  var lat = '';
  var south = false, lonOff = false, west = false;
  for (var i = 0; i < 6; i++) {
    final c = d[i];
    String digit;
    if (c.compareTo('0') >= 0 && c.compareTo('9') <= 0) {
      digit = c;
    } else if (c.compareTo('A') >= 0 && c.compareTo('J') <= 0) {
      digit = String.fromCharCode(c.codeUnitAt(0) - 17); // A-J = 0-9
    } else if (c.compareTo('P') >= 0 && c.compareTo('Y') <= 0) {
      digit = String.fromCharCode(c.codeUnitAt(0) - 32); // P-Y = 0-9
    } else if (c == 'K' || c == 'L' || c == 'Z') {
      digit = '5'; // ambiguity: centre
    } else {
      return p;
    }
    lat += digit;
    if (i == 3 && c.compareTo('P') >= 0 && c.compareTo('Z') <= 0) south = false;
    if (i == 3 && ((c.compareTo('0') >= 0 && c.compareTo('9') <= 0) || c == 'L')) south = true;
    if (i == 4 && c.compareTo('P') >= 0 && c.compareTo('Z') <= 0) lonOff = true;
    if (i == 5 && c.compareTo('P') >= 0 && c.compareTo('Z') <= 0) west = true;
  }
  var latv = int.parse(lat.substring(0, 2)) +
      double.parse('${lat.substring(2, 4)}.${lat.substring(4)}') / 60;
  if (south) latv = -latv;
  // info field: d28 encoding
  int b(int i) => body.codeUnitAt(i) - 28;
  var lonDeg = b(1);
  if (lonOff) lonDeg += 100;
  if (lonDeg >= 180 && lonDeg <= 189) {
    lonDeg -= 80;
  } else if (lonDeg >= 190 && lonDeg <= 199) {
    lonDeg -= 190;
  }
  var lonMin = b(2);
  if (lonMin >= 60) lonMin -= 60;
  final lonHun = b(3);
  var lngv = lonDeg + (lonMin + lonHun / 100) / 60;
  if (west) lngv = -lngv;
  var speed = b(4) * 10 + b(5) ~/ 10;
  if (speed >= 800) speed -= 800;
  var course = (b(5) % 10) * 100 + b(6);
  if (course >= 400) course -= 400;
  p.type = 'pos';
  p.lat = latv;
  p.lng = lngv;
  p.speed = speed; // knots
  p.course = course;
  p.symC = body[7];
  p.symT = body[8];
  var comment = body.substring(9);
  if (comment.length >= 4 && comment[3] == '}') {
    // Mic-E altitude
    final av = base91(comment.substring(0, 3));
    if (av != null) p.alt = ((av - 10000) * 3.28084).round();
    comment = comment.substring(4);
  }
  // strip Mic-E device type prefix/suffix bytes commonly seen (`, ', ], >)
  p.comment = comment.replaceFirst(RegExp('^[\\]>`\'"]+'), '').trim();
  _extractAlt(p);
  return p;
}
