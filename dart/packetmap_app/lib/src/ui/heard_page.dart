import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../station_store.dart';
import '../theme.dart';
import 'station_sheet.dart';

/// A sortable roster of everything on the map — usually faster than hunting
/// for an icon, especially in a moving vehicle.
class HeardPage extends StatefulWidget {
  const HeardPage({super.key, required this.state});
  final AppState state;

  @override
  State<HeardPage> createState() => _HeardPageState();
}

class _HeardPageState extends State<HeardPage> {
  HeardSort sort = HeardSort.distance;
  String query = '';
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // ages drift; refresh them without waiting for a packet
    _tick = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final light = s.settings.light;
    final dim = light ? Ob.lInkDim : Ob.inkDim;
    final rows = s.stations.sorted(sort,
        fromLat: s.fix?.latitude, fromLng: s.fix?.longitude, query: query);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Row(children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(hintText: 'filter callsign or comment…'),
                style: const TextStyle(fontSize: 13),
                onChanged: (v) => setState(() => query = v),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => setState(() {
                sort = HeardSort.values[(sort.index + 1) % HeardSort.values.length];
              }),
              child: Text(
                switch (sort) {
                  HeardSort.distance => 'DIST',
                  HeardSort.age => 'AGE',
                  HeardSort.call => 'CALL',
                },
                style: const TextStyle(fontSize: 11, letterSpacing: 1),
              ),
            ),
            const SizedBox(width: 8),
            Text('${rows.length} stn', style: TextStyle(fontSize: 10, color: dim)),
          ]),
        ),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Text('No stations heard yet.\nThey appear as packets arrive.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: dim, height: 1.8)),
                )
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: light ? Ob.lLine : Ob.line),
                  itemBuilder: (ctx, i) => _row(rows[i], s),
                ),
        ),
      ],
    );
  }

  Widget _row(Station st, AppState s) {
    final light = s.settings.light;
    final dim = light ? Ob.lInkDim : Ob.inkDim;
    final stale = st.isStale(s.settings.staleMin);
    final sub = <String>[
      if (st.speed != null && st.speed! > 0)
        '${(st.speed! * 1.15078).round()} mph${st.course != null ? ' @ ${st.course}°' : ''}',
      if (st.comment != null && st.comment!.isNotEmpty)
        st.comment!
      else if (st.status != null)
        st.status!,
      if (st.wx?.temp != null) '${st.wx!.temp}°F',
    ].join(' · ');

    return ListTile(
      dense: true,
      onTap: () => showStationSheet(context, s, st),
      title: Row(children: [
        if (s.settings.isWatched(st.call))
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.star, size: 12, color: Ob.amber),
          ),
        Flexible(
          child: Text(st.call,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: stale ? dim : (light ? Ob.lGreen : Ob.green),
              )),
        ),
      ]),
      subtitle: sub.isEmpty
          ? null
          : Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: dim)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(distBear(s, st), style: const TextStyle(fontSize: 12.5)),
          Text(agoStr(st.lastHeard), style: TextStyle(fontSize: 11, color: dim)),
        ],
      ),
    );
  }
}
