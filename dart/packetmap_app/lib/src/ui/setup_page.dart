import 'package:aprs_core/aprs_core.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key, required this.state});
  final AppState state;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  late final TextEditingController _call =
      TextEditingController(text: widget.state.settings.call);
  late final TextEditingController _comment =
      TextEditingController(text: widget.state.settings.comment);
  final _watch = TextEditingController();

  @override
  void dispose() {
    _call.dispose();
    _comment.dispose();
    _watch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final set = s.settings;
    final light = set.light;
    final dim = light ? Ob.lInkDim : Ob.inkDim;

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        _card('◆ My station', light, [
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _call,
                textCapitalization: TextCapitalization.characters,
                // 9, not 6: AX.25 caps at 6 but APRS-IS accepts longer source
                // calls, and special-event calls are real.
                maxLength: 9,
                decoration: const InputDecoration(labelText: 'Callsign', counterText: ''),
                onChanged: (v) {
                  set.call = v.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
                  if (_call.text != set.call) {
                    _call.value = TextEditingValue(
                        text: set.call,
                        selection: TextSelection.collapsed(offset: set.call.length));
                  }
                },
                onSubmitted: (_) => _reconnect(),
                onEditingComplete: _reconnect,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: set.ssid,
                decoration: const InputDecoration(labelText: 'SSID'),
                items: [
                  for (var i = 0; i <= 15; i++)
                    DropdownMenuItem(value: '$i', child: Text(i == 0 ? 'none' : '-$i')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  set.ssid = v;
                  _reconnect();
                },
              ),
            ),
          ]),
          TextField(
            controller: _comment,
            maxLength: 43,
            decoration: const InputDecoration(labelText: 'Beacon text', counterText: ''),
            onChanged: (v) => set.comment = v,
            onEditingComplete: () => set.save(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              set.call.isEmpty
                  ? 'Leave the callsign blank for a receive-only map.'
                  : 'Passcode ${passcode(set.call)} is computed from your callsign. '
                      'Transmitting requires an amateur radio license.',
              style: TextStyle(fontSize: 11.5, color: dim, height: 1.5),
            ),
          ),
        ]),
        _card('⌁ Beaconing', light, [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Transmit'),
            subtitle: Text('master TX switch (beacons + messages)',
                style: TextStyle(fontSize: 11.5, color: dim)),
            value: set.tx,
            onChanged: (v) {
              set.tx = v;
              set.save();
            },
          ),
          if (set.tx && !s.canTx)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Not ready: ${s.txMissing().join(', ')}',
                  style: const TextStyle(fontSize: 11.5, color: Ob.red)),
            ),
        ]),
        _card('⇄ Network', light, [
          Row(children: [
            Expanded(
              child: Text('Feed radius', style: TextStyle(fontSize: 13, color: dim)),
            ),
            SizedBox(
              width: 90,
              child: TextField(
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: '${set.radiusKm}'),
                decoration: const InputDecoration(suffixText: 'km'),
                onSubmitted: (v) {
                  set.radiusKm = (int.tryParse(v) ?? 50).clamp(10, 500);
                  set.save();
                  s.client.pushFilter();
                },
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Connected straight to ${s.client.host}:${s.client.port} over TCP — '
              'no bridge, no server to host.',
              style: TextStyle(fontSize: 11.5, color: dim, height: 1.5),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton(
                onPressed: () => s.reconnect(),
                child: const Text('RECONNECT'),
              ),
            ),
          ),
        ]),
        _card('★ Watchlist', light, [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _watch,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'CALLSIGN (prefix * ok)'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final v = _watch.text.trim().toUpperCase();
                if (v.isEmpty) return;
                set.watch.add(v);
                _watch.clear();
                set.save();
                s.client.pushFilter();
              },
              child: const Text('ADD'),
            ),
          ]),
          if (set.watch.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('No watched callsigns yet.',
                  style: TextStyle(fontSize: 11.5, color: dim)),
            )
          else
            Wrap(
              spacing: 6,
              children: [
                for (final w in List<String>.from(set.watch))
                  Chip(
                    label: Text(w, style: const TextStyle(fontSize: 12)),
                    onDeleted: () {
                      set.watch.remove(w);
                      set.save();
                      s.client.pushFilter();
                    },
                  ),
              ],
            ),
        ]),
        _card('☀ Map & display', light, [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Callsign labels'),
            value: set.labels,
            onChanged: (v) {
              set.labels = v;
              set.save();
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Range circles'),
            subtitle: Text('coverage a station claims via PHG / RNG',
                style: TextStyle(fontSize: 11.5, color: dim)),
            value: set.rangeRings,
            onChanged: (v) {
              set.rangeRings = v;
              set.save();
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dead reckoning'),
            subtitle: Text('ghost where a moving station should be now',
                style: TextStyle(fontSize: 11.5, color: dim)),
            value: set.deadReckon,
            onChanged: (v) {
              set.deadReckon = v;
              set.save();
            },
          ),
        ]),
        _card('⛃ Data', light, [
          Wrap(spacing: 8, children: [
            OutlinedButton(
              onPressed: () {
                s.stations.clear();
                s.toast('stations cleared');
              },
              child: const Text('CLEAR STATIONS'),
            ),
            OutlinedButton(
              onPressed: () async {
                await s.messages.clear();
                s.toast('messages cleared');
              },
              child: const Text('CLEAR MESSAGES'),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Everything stays on this device. Nothing is uploaded anywhere '
              'except the packets you deliberately transmit.',
              style: TextStyle(fontSize: 11.5, color: dim, height: 1.5),
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Center(
            child: Text('PacketMap v$appVersion',
                style: TextStyle(fontSize: 10.5, color: dim)),
          ),
        ),
      ],
    );
  }

  void _reconnect() {
    widget.state.settings.save();
    widget.state.reconnect();
  }

  Widget _card(String title, bool light, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: light ? Ob.lAmber : Ob.amber)),
            const SizedBox(height: 6),
            ...children,
          ]),
        ),
      );
}
