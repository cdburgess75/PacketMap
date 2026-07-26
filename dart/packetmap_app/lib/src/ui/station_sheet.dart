import 'package:aprs_core/aprs_core.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../station_store.dart';
import '../theme.dart';
import 'messages_page.dart';

String agoStr(DateTime t) {
  final s = DateTime.now().difference(t).inSeconds;
  if (s < 60) return '${s}s ago';
  if (s < 3600) return '${(s / 60).round()}m ago';
  if (s < 86400) return '${(s / 3600).toStringAsFixed(1)}h ago';
  return '${(s / 86400).toStringAsFixed(1)}d ago';
}

/// Distance and bearing from the current fix, or "" with no GPS.
String distBear(AppState s, Station st) {
  final fix = s.fix;
  if (fix == null || st.lat == null) return '';
  final km = haversineKm(fix.latitude, fix.longitude, st.lat!, st.lng!);
  final brg = bearingDeg(fix.latitude, fix.longitude, st.lat!, st.lng!);
  return '${(km * 0.621371).toStringAsFixed(1)} mi @ ${brg.round()}°';
}

void showStationSheet(BuildContext context, AppState s, Station st) {
  showModalBottomSheet(
    context: context,
    backgroundColor: s.settings.light ? Ob.lPanel : Ob.panel,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
    builder: (ctx) => _StationSheet(state: s, station: st),
  );
}

class _StationSheet extends StatelessWidget {
  const _StationSheet({required this.state, required this.station});
  final AppState state;
  final Station station;

  @override
  Widget build(BuildContext context) {
    final light = state.settings.light;
    final dim = light ? Ob.lInkDim : Ob.inkDim;
    final green = light ? Ob.lGreen : Ob.green;
    final st = station;
    final rows = <(String, String)>[
      ('heard', agoStr(st.lastHeard) + (st.via != null ? ' via ${st.via}' : '')),
      if (distBear(state, st).isNotEmpty) ('from me', distBear(state, st)),
      if (st.lat != null)
        ('position', '${st.lat!.toStringAsFixed(4)}, ${st.lng!.toStringAsFixed(4)}'),
      if (st.speed != null && st.speed! > 0)
        ('speed',
            '${(st.speed! * 1.15078).round()} mph${st.course != null ? ' @ ${st.course}°' : ''}'),
      if (st.alt != null) ('altitude', '${st.alt} ft'),
      if (st.rangeKm != null)
        ('range',
            '${(st.rangeKm! * 0.621371).round()} mi${st.phg != null ? ' · PHG${st.phg}' : ''}'),
      if (st.status != null) ('status', st.status!),
    ];

    return DraggableScrollableSheet(
      initialChildSize: .6,
      minChildSize: .3,
      maxChildSize: .92,
      expand: false,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(children: [
            Expanded(
              child: Text(st.call,
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: green)),
            ),
            IconButton(
              tooltip: 'Message',
              icon: const Icon(Icons.mail_outline),
              onPressed: () {
                Navigator.pop(ctx);
                openThread(context, state, st.call);
              },
            ),
            IconButton(
              tooltip: 'Watch',
              icon: Icon(
                state.settings.isWatched(st.call) ? Icons.star : Icons.star_border,
                color: state.settings.isWatched(st.call) ? Ob.amber : dim,
              ),
              onPressed: () {
                final w = state.settings.watch;
                if (state.settings.isWatched(st.call)) {
                  w.removeWhere((x) => x.toUpperCase() == st.call.toUpperCase());
                } else {
                  w.add(st.call);
                }
                state.settings.save();
              },
            ),
          ]),
          if (st.comment != null && st.comment!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(st.comment!,
                  style: TextStyle(fontSize: 12.5, color: light ? Ob.lAmber : Ob.amber)),
            ),
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                    width: 78,
                    child: Text(k, style: TextStyle(fontSize: 12.5, color: dim))),
                Expanded(child: Text(v, style: const TextStyle(fontSize: 12.5))),
              ]),
            ),
          if (st.wx != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: light ? Ob.lPanel2 : Ob.panel2,
                border: Border.all(color: light ? Ob.lLine : Ob.line),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_wxLine(st), style: const TextStyle(fontSize: 12.5, height: 1.6)),
            ),
          ],
          if (st.lastRaw != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: light ? Ob.lBg : Ob.bg,
                border: Border.all(color: light ? Ob.lLine : Ob.line),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(st.lastRaw!,
                  style: Ob.mono.copyWith(fontSize: 10.5, color: dim)),
            ),
          ],
        ],
      ),
    );
  }

  String _wxLine(Station st) {
    final w = st.wx!;
    final parts = <String>[
      if (w.temp != null) '${w.temp}°F',
      if (w.hum != null) '${w.hum}% rh',
      if (w.windSpd != null) 'wind ${w.windSpd} mph @ ${w.windDir ?? '?'}°',
      if (w.gust != null) 'gust ${w.gust}',
      if (w.baro != null) '${w.baro!.toStringAsFixed(1)} mb',
      if (w.rain1h != null) 'rain 1h ${w.rain1h}"',
      if (w.rain24h != null) '24h ${w.rain24h}"',
    ];
    return 'WX: ${parts.join(' · ')}';
  }
}
