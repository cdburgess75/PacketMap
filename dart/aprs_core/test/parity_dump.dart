// Dumps aprs_core's parse of test/vectors.txt as one canonical JSON line per
// vector. The PWA side (parity_dump.mjs) emits the same shape; parity.mjs
// diffs them. Run from dart/aprs_core:  dart test/parity_dump.dart
import 'dart:convert';
import 'dart:io';

import '../lib/aprs_core.dart';

/// Round to [dp], and collapse whole numbers to int so Dart's "0.0" matches
/// JavaScript's "0" — a formatting difference, not a value difference.
num _r(double v, int dp) {
  var f = 1.0;
  for (var i = 0; i < dp; i++) {
    f *= 10;
  }
  final r = (v * f).round() / f;
  return r == r.roundToDouble() ? r.toInt() : r;
}

Map<String, Object?> _dump(AprsPacket? p) {
  if (p == null) return {'null': true};
  final m = <String, Object?>{
    'src': p.src,
    'dest': p.dest,
    'path': p.path,
  };
  void put(String k, Object? v) {
    if (v != null) m[k] = v;
  }

  put('type', p.type);
  put('name', p.name);
  if (p.obj) m['obj'] = true;
  if (p.kill) m['kill'] = true;
  put('to', p.to);
  put('text', p.text);
  put('msgId', p.msgId);
  put('ack', p.ack);
  put('rej', p.rej);
  put('status', p.status);
  if (p.lat != null) m['lat'] = _r(p.lat!, 6);
  if (p.lng != null) m['lng'] = _r(p.lng!, 6);
  put('symT', p.symT);
  put('symC', p.symC);
  put('symO', p.symO);
  put('course', p.course);
  put('speed', p.speed);
  put('alt', p.alt);
  put('phg', p.phg);
  put('rng', p.rng);
  put('comment', p.comment);
  final wx = p.wx;
  if (wx != null) {
    final w = <String, Object?>{};
    void wput(String k, Object? v) {
      if (v != null) w[k] = v is double ? _r(v, 4) : v;
    }

    wput('windDir', wx.windDir);
    wput('windSpd', wx.windSpd);
    wput('gust', wx.gust);
    wput('temp', wx.temp);
    wput('rain1h', wx.rain1h);
    wput('rain24h', wx.rain24h);
    wput('rainMid', wx.rainMid);
    wput('hum', wx.hum);
    wput('baro', wx.baro);
    m['wx'] = w;
  }
  return m;
}

String _canon(Map<String, Object?> m) {
  final keys = m.keys.toList()..sort();
  return jsonEncode({for (final k in keys) k: m[k]});
}

void main(List<String> args) {
  final path = args.isNotEmpty ? args[0] : 'test/vectors.txt';
  for (final raw in File(path).readAsLinesSync()) {
    final line = raw.trimRight();
    if (line.isEmpty || line.startsWith('#')) continue;
    stdout.writeln(_canon(_dump(parsePacket(line))));
  }
}
