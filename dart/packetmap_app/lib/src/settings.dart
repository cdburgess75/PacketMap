import 'dart:convert';

import 'package:aprs_core/aprs_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything the user can configure. Same defaults as the PWA so a station
/// behaves identically whichever version they run.
class Settings extends ChangeNotifier {
  static const _key = 'packetmap-settings';

  String call = '';
  String ssid = '9';
  String symTable = '/';
  String symCode = '[';
  String comment = 'PacketMap';
  bool tx = false;
  bool notify = false;
  int radiusKm = 50;
  List<String> watch = [];
  double centerLat = 29.953;
  double centerLng = -90.0764;
  double zoom = 11;
  bool labels = true;
  int staleMin = 30;
  bool rangeRings = true;
  bool deadReckon = true;
  bool light = false;

  SmartBeaconConfig beacon = const SmartBeaconConfig();

  /// "KF5UUP-5", or "" when no callsign is set (receive-only).
  String get myCall => formatCall(call, ssid);
  bool get canTx => tx && myCall.isNotEmpty;

  String filterFor(double lat, double lng) => buildFilter(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        myCall: myCall,
        baseCall: call,
        watch: watch,
      );

  bool isWatched(String c) => watch.any((w) => w.endsWith('*')
      ? c.toUpperCase().startsWith(w.substring(0, w.length - 1).toUpperCase())
      : c.toUpperCase() == w.toUpperCase());

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        call = m['call'] ?? call;
        ssid = '${m['ssid'] ?? ssid}'; // tolerate a numeric ssid
        symTable = m['symTable'] ?? symTable;
        symCode = m['symCode'] ?? symCode;
        comment = m['comment'] ?? comment;
        tx = m['tx'] ?? tx;
        notify = m['notify'] ?? notify;
        radiusKm = m['radiusKm'] ?? radiusKm;
        watch = (m['watch'] as List?)?.cast<String>() ?? watch;
        centerLat = (m['centerLat'] as num?)?.toDouble() ?? centerLat;
        centerLng = (m['centerLng'] as num?)?.toDouble() ?? centerLng;
        zoom = (m['zoom'] as num?)?.toDouble() ?? zoom;
        labels = m['labels'] ?? labels;
        staleMin = m['staleMin'] ?? staleMin;
        rangeRings = m['rangeRings'] ?? rangeRings;
        deadReckon = m['deadReckon'] ?? deadReckon;
        light = m['light'] ?? light;
      } catch (_) {/* corrupt prefs: fall back to defaults */}
    }
    notifyListeners();
  }

  Future<void> save() async {
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _key,
        jsonEncode({
          'call': call, 'ssid': ssid, 'symTable': symTable, 'symCode': symCode,
          'comment': comment, 'tx': tx, 'notify': notify, 'radiusKm': radiusKm,
          'watch': watch, 'centerLat': centerLat, 'centerLng': centerLng,
          'zoom': zoom, 'labels': labels, 'staleMin': staleMin,
          'rangeRings': rangeRings, 'deadReckon': deadReckon, 'light': light,
        }));
  }
}
