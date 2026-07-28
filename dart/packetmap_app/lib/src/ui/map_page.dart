import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_state.dart';
import '../station_store.dart';
import '../theme.dart';
import 'station_sheet.dart';

/// The live map: stations, track tails, range circles, dead-reckoned ghosts,
/// and your own position.
class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.state});
  final AppState state;

  @override
  State<MapPage> createState() => MapPageState();
}

class MapPageState extends State<MapPage> {
  final _map = MapController();
  bool _follow = true;
  bool _centredOnce = false;

  static const _tailColors = [
    Ob.amber, Ob.blue, Ob.green, Ob.red,
    Color(0xFFC9A0E8), Color(0xFFE8D75A), Color(0xFF7EE87E), Color(0xFFE88BD4),
  ];

  Color _tailColor(String call) => _tailColors[call.hashCode.abs() % _tailColors.length];

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final light = s.settings.light;
    final fix = s.fix;
    final here = fix != null ? LatLng(fix.latitude, fix.longitude) : null;

    if (here != null && _follow && _centredOnce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _follow) _map.move(here, _map.camera.zoom);
      });
    }
    if (here != null && !_centredOnce) {
      _centredOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _map.move(here, 12);
      });
    }

    final withPos = s.stations.all.where((st) => st.lat != null).toList();

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: here ?? LatLng(s.settings.centerLat, s.settings.centerLng),
            initialZoom: s.settings.zoom,
            backgroundColor: light ? Ob.lMapBg : Ob.mapBg,
            onPositionChanged: (pos, gesture) {
              if (gesture) _follow = false;
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'io.github.cdburgess75.packetmap',
              tileBuilder: light ? null : _darkTiles,
            ),
            // coverage a station claims for itself
            if (s.settings.rangeRings)
              CircleLayer(
                circles: [
                  for (final st in withPos)
                    if (st.rangeKm != null)
                      CircleMarker(
                        point: LatLng(st.lat!, st.lng!),
                        radius: st.rangeKm! * 1000,
                        useRadiusInMeter: true,
                        color: _tailColor(st.call).withValues(alpha: .04),
                        borderColor: _tailColor(st.call).withValues(alpha: .4),
                        borderStrokeWidth: 1,
                      ),
                ],
              ),
            PolylineLayer(
              polylines: [
                for (final st in withPos)
                  if (st.track.length > 1)
                    Polyline(
                      points: [for (final p in st.track) LatLng(p.lat, p.lng)],
                      color: _tailColor(st.call).withValues(alpha: .75),
                      strokeWidth: 2,
                    ),
                // dead reckoning: where it should be now, dashed
                if (s.settings.deadReckon)
                  for (final st in withPos)
                    if (st.deadReckoned() case final dr?)
                      Polyline(
                        points: [LatLng(st.lat!, st.lng!), LatLng(dr.lat, dr.lng)],
                        color: _tailColor(st.call).withValues(alpha: .55),
                        strokeWidth: 1.5,
                        pattern: StrokePattern.dashed(segments: const [4, 5]),
                      ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final st in withPos) _stationMarker(st, s),
                if (here != null)
                  Marker(
                    point: here,
                    width: 26,
                    height: 26,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Ob.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(color: Color(0x66FF5252), blurRadius: 12, spreadRadius: 2),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          right: 10,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapBtn(
                icon: Icons.gps_fixed,
                hot: _follow,
                light: light,
                tooltip: 'Follow my position',
                onTap: () {
                  setState(() => _follow = true);
                  if (here != null) _map.move(here, _map.camera.zoom);
                },
              ),
              const SizedBox(height: 10),
              _MapBtn(
                icon: Icons.fit_screen,
                light: light,
                tooltip: 'Zoom to fit',
                onTap: () {
                  final pts = [
                    for (final st in withPos) LatLng(st.lat!, st.lng!),
                    if (here != null) here,
                  ];
                  if (pts.isEmpty) {
                    s.toast('No stations on the map yet');
                    return;
                  }
                  setState(() => _follow = false);
                  _map.fitCamera(CameraFit.coordinates(
                      coordinates: pts, padding: const EdgeInsets.all(48), maxZoom: 15));
                },
              ),
              const SizedBox(height: 10),
              _MapBtn(
                icon: Icons.wb_sunny_outlined,
                light: light,
                tooltip: 'Ask WXBOT for a forecast here',
                onTap: () => s.askForecast(),
              ),
              const SizedBox(height: 10),
              _SendNowBtn(state: s),
            ],
          ),
        ),
      ],
    );
  }

  Marker _stationMarker(Station st, AppState s) {
    final stale = st.isStale(s.settings.staleMin);
    final color = _tailColor(st.call);
    return Marker(
      point: LatLng(st.lat!, st.lng!),
      width: 132,
      height: 30,
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => showStationSheet(context, s, st),
        child: Opacity(
          opacity: stale ? .55 : 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white70, width: 1.5),
                ),
                child: s.settings.isWatched(st.call)
                    ? const Icon(Icons.star, size: 9, color: Colors.black87)
                    : null,
              ),
              if (s.settings.labels)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: Text(
                      st.call,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: s.settings.light ? Ob.lInk : Colors.white,
                        shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dim and desaturate OSM tiles so the markers carry the colour, matching
  /// the PWA's CSS filter on the dark theme.
  Widget _darkTiles(BuildContext context, Widget tile, TileImage image) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.46, 0.30, 0.10, 0, -8,
        0.26, 0.50, 0.10, 0, -8,
        0.26, 0.30, 0.30, 0, -8,
        0, 0, 0, 1, 0,
      ]),
      child: tile,
    );
  }
}

class _MapBtn extends StatelessWidget {
  const _MapBtn({
    required this.icon,
    required this.onTap,
    required this.light,
    this.hot = false,
    this.tooltip,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool light, hot;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final bg = hot ? (light ? Ob.lGreen : Ob.green) : (light ? Ob.lPanel : Ob.panel);
    final fg = hot
        ? (light ? Colors.white : const Color(0xFF03110D))
        : (light ? Ob.lInk : Ob.ink);
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: bg,
        shape: CircleBorder(side: BorderSide(color: light ? Ob.lLine : Ob.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 46, height: 46, child: Icon(icon, color: fg, size: 21)),
        ),
      ),
    );
  }
}

class _SendNowBtn extends StatelessWidget {
  const _SendNowBtn({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final light = state.settings.light;
    final ready = state.canTx;
    return Tooltip(
      message: ready ? 'Send position beacon now' : 'To beacon: ${state.txMissing().join(', ')}',
      child: Opacity(
        opacity: ready ? 1 : .5,
        child: Material(
          color: light ? Ob.lPanel : Ob.panel,
          shape: CircleBorder(side: BorderSide(color: light ? Ob.lLine : Ob.line)),
          child: InkWell(
            customBorder: const CircleBorder(),
            // stays tappable when not ready, so a tap can explain why
            onTap: () => state.sendBeacon(manual: true),
            child: SizedBox(
              width: 46,
              height: 46,
              child: Center(
                child: Text('SEND\nNOW',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 9,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: light ? Ob.lAmber : Ob.amber)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
