import 'package:aprs_core/aprs_core.dart';
import 'package:flutter/foundation.dart';

/// One station on the map, accumulated across packets.
class Station {
  Station(this.call);

  final String call;
  double? lat, lng;
  String symTable = '/', symCode = '/';
  String? symOverlay;
  int? course, speed, alt, rng;
  String? phg, comment, status;
  Wx? wx;
  String? lastRaw;
  String? via; // src when this is an object/item reported by someone else
  DateTime lastHeard = DateTime.now();
  final List<TrackPoint> track = [];

  bool isStale(int staleMin) =>
      DateTime.now().difference(lastHeard).inMinutes >= staleMin;

  /// Coverage the station claims for itself, in km — RNG wins over PHG.
  double? get rangeKm {
    double? mi;
    if (rng != null && rng! > 0) {
      mi = rng!.toDouble();
    } else if (phg != null && RegExp(r'^\d{4}$').hasMatch(phg!)) {
      mi = phgRangeMi(phg!);
    }
    if (mi == null || !mi.isFinite || mi <= 0) return null;
    return (mi > 400 ? 400 : mi) * 1.609344;
  }

  /// Where it should be now if it held its last course and speed. Null when
  /// stopped, when we have no heading, or once the guess is too old to trust.
  ({double lat, double lng})? deadReckoned() {
    if (lat == null || speed == null || speed == 0 || course == null) return null;
    if (speed! * 1.15078 < 3) return null;
    final mins = DateTime.now().difference(lastHeard).inSeconds / 60;
    if (mins < 0.5 || mins > 30) return null;
    return destPoint(lat!, lng!, course!.toDouble(), speed! * 1.852 * (mins / 60));
  }
}

class TrackPoint {
  TrackPoint(this.lat, this.lng, this.t);
  final double lat, lng;
  final DateTime t;
}

/// Every station we've heard, bounded so a busy feed can't grow without limit.
class StationStore extends ChangeNotifier {
  static const maxStations = 500;
  static const maxTrack = 600;

  final Map<String, Station> _byCall = {};
  Iterable<Station> get all => _byCall.values;
  int get length => _byCall.length;
  Station? operator [](String call) => _byCall[call];

  /// Fold a position/weather/status packet in. Objects and items are keyed by
  /// the object name, not the station that reported them.
  Station? ingest(AprsPacket p) {
    if (p.type != 'pos' && p.type != 'wx' && p.type != 'status') return null;
    final call = p.name ?? p.src;
    if (call.isEmpty) return null;
    final st = _byCall.putIfAbsent(call, () => Station(call));
    st.lastHeard = DateTime.now();
    st.lastRaw = p.raw;
    if (p.name != null && p.src != call) st.via = p.src;
    if (p.comment != null && p.comment!.isNotEmpty) st.comment = p.comment;
    if (p.status != null) st.status = p.status;
    if (p.wx != null) st.wx = p.wx;
    if (p.course != null && p.course! > 0) st.course = p.course;
    if (p.speed != null) st.speed = p.speed;
    if (p.alt != null) st.alt = p.alt;
    if (p.phg != null) st.phg = p.phg;
    if (p.rng != null) st.rng = p.rng;
    if (p.type == 'pos' && p.lat != null) {
      final moved = st.lat == null ||
          (st.lat! - p.lat!).abs() > 1e-5 ||
          (st.lng! - p.lng!).abs() > 1e-5;
      st.lat = p.lat;
      st.lng = p.lng;
      st.symTable = p.symT ?? st.symTable;
      st.symCode = p.symC ?? st.symCode;
      if (p.symO != null) st.symOverlay = p.symO;
      if (moved || st.track.isEmpty) {
        st.track.add(TrackPoint(p.lat!, p.lng!, DateTime.now()));
        if (st.track.length > maxTrack) st.track.removeAt(0);
      }
    }
    if (_byCall.length > maxStations) prune(force: true);
    notifyListeners();
    return st;
  }

  /// Drop stations unheard for six hours; if still over the cap, drop the
  /// oldest. [keep] is never removed — it's whatever the user has open.
  void prune({bool force = false, String? keep}) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 6));
    _byCall.removeWhere((c, s) => c != keep && s.lastHeard.isBefore(cutoff));
    if (force && _byCall.length > maxStations) {
      final sorted = _byCall.values.where((s) => s.call != keep).toList()
        ..sort((a, b) => a.lastHeard.compareTo(b.lastHeard));
      for (var i = 0; i < _byCall.length - maxStations && i < sorted.length; i++) {
        _byCall.remove(sorted[i].call);
      }
    }
    notifyListeners();
  }

  /// Sorted for the Heard list.
  List<Station> sorted(HeardSort sort, {double? fromLat, double? fromLng, String query = ''}) {
    final q = query.trim().toUpperCase();
    final rows = _byCall.values.where((s) =>
        q.isEmpty ||
        s.call.toUpperCase().contains(q) ||
        (s.comment ?? '').toUpperCase().contains(q)).toList();
    double dist(Station s) => (fromLat == null || s.lat == null)
        ? double.infinity
        : haversineKm(fromLat, fromLng!, s.lat!, s.lng!);
    switch (sort) {
      case HeardSort.call:
        rows.sort((a, b) => a.call.compareTo(b.call));
      case HeardSort.age:
        rows.sort((a, b) => b.lastHeard.compareTo(a.lastHeard));
      case HeardSort.distance:
        rows.sort((a, b) {
          final d = dist(a).compareTo(dist(b));
          return d != 0 ? d : b.lastHeard.compareTo(a.lastHeard);
        });
    }
    return rows;
  }

  void clear() {
    _byCall.clear();
    notifyListeners();
  }
}

enum HeardSort { distance, age, call }
