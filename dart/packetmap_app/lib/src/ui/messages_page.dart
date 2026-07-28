import 'package:flutter/material.dart';

import '../app_state.dart';
import '../message_store.dart';
import '../theme.dart';

String _stamp(DateTime t) {
  final n = DateTime.now();
  final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  final sameDay = t.year == n.year && t.month == n.month && t.day == n.day;
  return sameDay ? hm : '${t.month}/${t.day} $hm';
}

void openThread(BuildContext context, AppState state, String peer) {
  state.messages.markRead(peer);
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ThreadPage(state: state, peer: peer),
  ));
}

/// Conversation list, with bulletins pinned above it.
class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final light = state.settings.light;
    final dim = light ? Ob.lInkDim : Ob.inkDim;
    final peers = state.messages.peers;
    final blns = state.messages.bulletins.values.toList()
      ..sort((a, b) => b.t.compareTo(a.t));

    return Column(children: [
      if (blns.isNotEmpty)
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: BoxDecoration(
            color: light ? Ob.lPanel : Ob.panel,
            border: Border(bottom: BorderSide(color: light ? Ob.lLine : Ob.line)),
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
                child: Text('◈ BULLETINS',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2,
                        color: light ? Ob.lAmber : Ob.amber)),
              ),
              for (final b in blns)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(b.src,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: light ? Ob.lGreen : Ob.green)),
                      const SizedBox(width: 6),
                      Text('${b.slot}  ${_stamp(b.t)}',
                          style: TextStyle(fontSize: 10, color: dim)),
                    ]),
                    Text(b.text, style: const TextStyle(fontSize: 12.5)),
                  ]),
                ),
            ],
          ),
        ),
      Expanded(
        child: peers.isEmpty
            ? Center(
                child: Text(
                    'No APRS messages yet.\nSet your callsign in Setup,\nthen message any station from the map.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: dim, height: 1.8)),
              )
            : ListView.separated(
                itemCount: peers.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: light ? Ob.lLine : Ob.line),
                itemBuilder: (ctx, i) {
                  final peer = peers[i];
                  final thread = state.messages.thread(peer);
                  final last = thread.last;
                  final unread = thread.where((m) => m.unread).length;
                  return ListTile(
                    dense: true,
                    onTap: () => openThread(context, state, peer),
                    title: Text(peer,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: light ? Ob.lGreen : Ob.green)),
                    subtitle: Text(last.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: dim)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_stamp(last.t), style: TextStyle(fontSize: 11, color: dim)),
                        if (unread > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                                color: Ob.red, borderRadius: BorderRadius.circular(8)),
                            child: Text('$unread',
                                style: const TextStyle(fontSize: 10, color: Colors.white)),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          OutlinedButton(
            onPressed: () {
              if (state.askForecast()) openThread(context, state, AppState.wxbot);
            },
            child: const Text('☀ FORECAST FOR MY LOCATION',
                style: TextStyle(fontSize: 11.5, letterSpacing: 1.2)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              'Messages WXBOT, an APRS robot, with your coordinates; the forecast '
              'comes back as a reply. Works over RF with no internet.',
              style: TextStyle(fontSize: 11, color: dim, height: 1.4),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Expanded(
            child: TextField(
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'CALLSIGN-SSID'),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) openThread(context, state, v.trim().toUpperCase());
              },
            ),
          ),
        ]),
      ),
    ]);
  }
}

class ThreadPage extends StatefulWidget {
  const ThreadPage({super.key, required this.state, required this.peer});
  final AppState state;
  final String peer;

  @override
  State<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final light = s.settings.light;
    final dim = light ? Ob.lInkDim : Ob.inkDim;
    return AnimatedBuilder(
      animation: s.messages,
      builder: (context, _) {
        final msgs = s.messages.thread(widget.peer);
        return Scaffold(
          appBar: AppBar(title: Text(widget.peer, style: const TextStyle(letterSpacing: 1.5))),
          body: Column(children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: msgs.length,
                itemBuilder: (ctx, i) => _bubble(msgs[msgs.length - 1 - i], light),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text('APRS messages are public and limited to 67 characters.',
                  style: TextStyle(fontSize: 10, color: dim)),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      maxLength: 67,
                      decoration: const InputDecoration(hintText: 'message…', counterText: ''),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _send, child: const Text('SEND')),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    if (widget.state.sendMessage(widget.peer, text)) _input.clear();
  }

  Widget _bubble(Msg m, bool light) {
    final meta = switch (m.state) {
      MsgState.pending => ' · sending',
      MsgState.acked => ' · ✓ ack',
      MsgState.failed => ' · failed',
      MsgState.received => '',
    };
    final metaColor = switch (m.state) {
      MsgState.pending => light ? Ob.lAmber : Ob.amber,
      MsgState.acked => light ? Ob.lGreen : Ob.green,
      MsgState.failed => Ob.red,
      MsgState.received => light ? Ob.lInkDim : Ob.inkDim,
    };
    return Align(
      alignment: m.outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: m.outgoing
              ? (light ? const Color(0xFFD1F7EC) : const Color(0xFF164338))
              : (light ? Ob.lPanel2 : Ob.panel2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: light ? Ob.lLine : Ob.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(m.text, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 3),
          Text('${_stamp(m.t)}$meta', style: TextStyle(fontSize: 10.5, color: metaColor)),
        ]),
      ),
    );
  }
}
