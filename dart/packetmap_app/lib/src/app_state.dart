import 'dart:async';

import 'package:aprs_core/aprs_core.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'aprs_client.dart';
import 'message_store.dart';
import 'settings.dart';
import 'station_store.dart';

const appVersion = '2026.07.26.007';

/// Ties the pieces together: GPS in, APRS-IS in and out, beaconing on top.
class AppState extends ChangeNotifier {
  AppState()
      : settings = Settings(),
        stations = StationStore() {
    client = AprsIsClient(appVersion: appVersion);
    messages = MessageStore(send: client.send, myCall: () => settings.myCall);
    client.callsign = () => settings.myCall;
    client.baseCall = () => settings.call;
    client.filter = () => settings.filterFor(
        fix?.latitude ?? settings.centerLat, fix?.longitude ?? settings.centerLng);
  }

  final Settings settings;
  final StationStore stations;
  late final AprsIsClient client;
  late final MessageStore messages;

  Position? fix;
  LinkState link = LinkState.offline;
  String? banner; // transient toast text
  final List<RawLine> raw = [];
  static const rawLimit = 2000;

  StreamSubscription? _pkt, _rawSub, _state, _geo;
  Timer? _watchdog, _beaconTimer;
  DateTime _lastBeacon = DateTime.fromMillisecondsSinceEpoch(0);
  double? _lastBeaconHeading;
  double? _filterLat, _filterLng;

  bool get canTx =>
      settings.tx && settings.myCall.isNotEmpty && client.verified && client.linkAlive && fix != null;

  /// Ordered list of what still blocks transmit, for an honest refusal.
  List<String> txMissing() => [
        if (!settings.tx) 'turn on Transmit',
        if (settings.myCall.isEmpty) 'set your callsign'
        else if (!client.verified) 'callsign not verified yet',
        if (fix == null) 'enable GPS',
        if (!client.linkAlive) 'connect to APRS-IS',
      ];

  Future<void> start() async {
    await settings.load();
    await messages.load();
    messages.addListener(notifyListeners);
    stations.addListener(notifyListeners);

    _pkt = client.packets.listen(_onPacket);
    _rawSub = client.rawLines.listen((l) {
      raw.add(l);
      if (raw.length > rawLimit) raw.removeAt(0);
      notifyListeners();
    });
    _state = client.state.listen((s) {
      link = s;
      notifyListeners();
    });

    _watchdog = Timer.periodic(const Duration(seconds: 15), (_) {
      client.tickWatchdog();
      stations.prune();
    });
    _beaconTimer = Timer.periodic(const Duration(seconds: 5), (_) => _smartBeaconTick());

    await _startGps();
    await client.connect();
  }

  Future<void> _startGps() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      _geo = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best, distanceFilter: 5),
      ).listen(_onFix, onError: (_) {});
    } catch (_) {/* desktop without a GPS: the manual centre still works */}
  }

  void _onFix(Position p) {
    final first = fix == null;
    fix = p;
    if (first) _pushFilterIfMoved(force: true);
    _pushFilterIfMoved();
    notifyListeners();
  }

  /// Re-anchor the server-side filter once we've moved ~20% of the radius.
  void _pushFilterIfMoved({bool force = false}) {
    if (fix == null) return;
    if (!force && _filterLat != null) {
      final moved = haversineKm(fix!.latitude, fix!.longitude, _filterLat!, _filterLng!);
      if (moved < settings.radiusKm * 0.2) return;
    }
    _filterLat = fix!.latitude;
    _filterLng = fix!.longitude;
    client.pushFilter();
  }

  void _onPacket(AprsPacket p) {
    if (p.type == 'msg') {
      final note = messages.handle(p);
      if (note != null) toast(note);
      return;
    }
    final st = stations.ingest(p);
    if (st != null && settings.isWatched(st.call)) {
      // only shout when a watched station reappears, not on every beacon
      if (DateTime.now().difference(st.lastHeard).inMinutes > 30) toast('${st.call} heard');
    }
  }

  void toast(String text) {
    banner = text;
    notifyListeners();
    Timer(const Duration(seconds: 5), () {
      if (banner == text) {
        banner = null;
        notifyListeners();
      }
    });
  }

  // ---- transmit ----

  String? buildBeacon() {
    if (fix == null) return null;
    final p = fix!;
    final knots = p.speed.isFinite && p.speed > 0 ? (p.speed * 1.94384).round() : null;
    return buildPositionFrame(
      call: settings.myCall,
      lat: p.latitude,
      lng: p.longitude,
      symTable: settings.symTable,
      symCode: settings.symCode,
      courseDeg: p.heading.isFinite ? p.heading.round() : null,
      speedKnots: knots,
      comment: settings.comment,
    );
  }

  bool sendBeacon({bool manual = false}) {
    if (!canTx) {
      if (manual) toast("can't beacon: ${txMissing().join(', ')}");
      return false;
    }
    final frame = buildBeacon();
    if (frame == null || !client.send(frame)) {
      client.revive();
      if (manual) toast('not connected — position not sent');
      return false;
    }
    _lastBeacon = DateTime.now();
    _lastBeaconHeading = fix?.heading;
    if (manual) toast('position sent');
    notifyListeners();
    return true;
  }

  void _smartBeaconTick() {
    if (!canTx || fix == null) return;
    final mph = (fix!.speed.isFinite ? fix!.speed : 0) * 2.23694;
    final due = smartBeaconDue(
      mph: mph,
      secsSinceLast: DateTime.now().difference(_lastBeacon).inSeconds.toDouble(),
      headingDeg: fix!.heading.isFinite ? fix!.heading : null,
      lastHeadingDeg: _lastBeaconHeading,
      cfg: settings.beacon,
    );
    if (due) sendBeacon();
  }

  /// WXBOT is a long-running APRS-IS robot: message it and it answers with a
  /// forecast. We send explicit coordinates rather than letting it look up our
  /// last beacon, so this works for a station that has never transmitted a
  /// position — and it works over RF with no internet at all, which is the
  /// whole reason to ask a radio robot instead of a weather API.
  static const wxbot = 'WXBOT';
  bool askForecast() {
    final p = fix;
    if (p == null) {
      toast('waiting for a GPS fix');
      return false;
    }
    return sendMessage(
        wxbot, '${p.latitude.toStringAsFixed(4)}/${p.longitude.toStringAsFixed(4)}');
  }

  bool sendMessage(String peer, String text) {
    if (!canTx) {
      client.revive();
      toast("can't send: ${txMissing().join(', ')}");
      return false;
    }
    messages.sendMessage(peer, text);
    return true;
  }

  /// The app came back to the foreground, or the network returned.
  void onResume() {
    client.revive();
    notifyListeners();
  }

  Future<void> reconnect() => client.connect();

  @override
  void dispose() {
    _pkt?.cancel();
    _rawSub?.cancel();
    _state?.cancel();
    _geo?.cancel();
    _watchdog?.cancel();
    _beaconTimer?.cancel();
    messages.dispose();
    client.dispose();
    super.dispose();
  }
}
