import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';

/// The live packet stream, unfiltered by design — the whole protocol, visible.
class RawPage extends StatefulWidget {
  const RawPage({super.key, required this.state});
  final AppState state;

  @override
  State<RawPage> createState() => _RawPageState();
}

class _RawPageState extends State<RawPage> {
  String filter = '';
  bool paused = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final light = s.settings.light;
    final dim = light ? Ob.lInkDim : Ob.inkDim;
    final q = filter.trim().toUpperCase();
    final lines = s.raw.where((l) => q.isEmpty || l.text.toUpperCase().contains(q)).toList();
    final shown = lines.length > 500 ? lines.sublist(lines.length - 500) : lines;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        child: Row(children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(hintText: 'filter (callsign or text)…'),
              style: const TextStyle(fontSize: 13),
              onChanged: (v) => setState(() => filter = v),
            ),
          ),
          const SizedBox(width: 8),
          Text('${s.raw.length}', style: TextStyle(fontSize: 10, color: dim)),
          IconButton(
            tooltip: paused ? 'Resume' : 'Pause',
            icon: Icon(paused ? Icons.play_arrow : Icons.pause,
                color: paused ? Ob.amber : dim),
            onPressed: () => setState(() => paused = !paused),
          ),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: shown.length,
          itemBuilder: (ctx, i) {
            final l = shown[shown.length - 1 - i];
            final gt = l.text.indexOf('>');
            final isHeader = l.text.startsWith('#');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: SelectableText.rich(
                TextSpan(
                  style: Ob.mono.copyWith(
                    fontSize: 12,
                    height: 1.35,
                    color: l.mine ? (light ? Ob.lAmber : Ob.amber) : dim,
                  ),
                  children: [
                    if (!isHeader && gt > 0 && gt < 12) ...[
                      TextSpan(
                        text: l.text.substring(0, gt),
                        style: TextStyle(
                            color: light ? Ob.lGreen : Ob.green, fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: l.text.substring(gt)),
                    ] else
                      TextSpan(text: l.text),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}
