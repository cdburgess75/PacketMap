import 'dart:async';
import 'dart:convert';

import 'package:aprs_core/aprs_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MsgState { pending, acked, failed, received }

class Msg {
  Msg({
    required this.peer,
    required this.outgoing,
    required this.text,
    required this.t,
    this.id = '',
    this.state = MsgState.received,
    this.unread = false,
  });

  final String peer;
  final bool outgoing;
  final String text;
  final DateTime t;
  final String id;
  MsgState state;
  bool unread;

  /// Attempts that actually left the device; deferrals don't count.
  int tries = 0;
  int defers = 0;

  String get key => '$peer|${outgoing ? 'o' : 'i'}|${t.millisecondsSinceEpoch}|$id';

  Map<String, dynamic> toJson() => {
        'peer': peer, 'out': outgoing, 'text': text,
        't': t.millisecondsSinceEpoch, 'id': id,
        'state': state.name, 'unread': unread,
      };

  static Msg fromJson(Map<String, dynamic> m) => Msg(
        peer: m['peer'],
        outgoing: m['out'],
        text: m['text'],
        t: DateTime.fromMillisecondsSinceEpoch(m['t']),
        id: m['id'] ?? '',
        state: MsgState.values.firstWhere((s) => s.name == m['state'],
            orElse: () => MsgState.received),
        unread: m['unread'] ?? false,
      );
}

/// A bulletin (BLN0-9 / BLNA-Z), keyed by sender+slot so a re-send replaces.
class Bulletin {
  Bulletin(this.src, this.slot, this.text) : t = DateTime.now();
  final String src, slot, text;
  final DateTime t;
}

/// Messages, acks and retries.
///
/// The retry rules are the ones the PWA arrived at the hard way: three on-air
/// attempts thirty seconds apart, but a send that never left the device is a
/// deferral, not an attempt — it waits for the link and tries again without
/// spending the budget.
class MessageStore extends ChangeNotifier {
  MessageStore({required this.send, required this.myCall});

  /// Returns false when the link is not alive.
  final bool Function(String record) send;
  final String Function() myCall;

  static const _key = 'packetmap-messages';
  static const _seqKey = 'packetmap-msgseq';
  static const ackGrace = Duration(minutes: 5);
  static const retryEvery = Duration(seconds: 30);
  static const deferEvery = Duration(seconds: 5);
  static const maxDefers = 6;

  final List<Msg> messages = [];
  final Map<String, Bulletin> bulletins = {};
  final Map<String, String> _pendingAcks = {}; // "PEER|id" -> msg key
  final Map<String, Timer> _timers = {};
  int _seq = 0;

  int get unreadCount => messages.where((m) => m.unread).length;

  List<String> get peers {
    final seen = <String, DateTime>{};
    for (final m in messages) {
      final cur = seen[m.peer];
      if (cur == null || m.t.isAfter(cur)) seen[m.peer] = m.t;
    }
    final list = seen.keys.toList()..sort((a, b) => seen[b]!.compareTo(seen[a]!));
    return list;
  }

  List<Msg> thread(String peer) => messages.where((m) => m.peer == peer).toList();

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _seq = p.getInt(_seqKey) ?? 0;
    final raw = p.getString(_key);
    if (raw != null) {
      try {
        for (final e in (jsonDecode(raw) as List)) {
          messages.add(Msg.fromJson(e as Map<String, dynamic>));
        }
      } catch (_) {/* corrupt store: start clean rather than crash */}
    }
    messages.sort((a, b) => a.t.compareTo(b.t));
    // Restoring messages has to restore the ack bookkeeping with them: the
    // retry timers died with the old process. Anything young enough may still
    // be acked, so re-arm the lookup; anything older never will be, and
    // leaving it on "sending" forever would be a lie.
    final now = DateTime.now();
    for (final m in messages) {
      if (!m.outgoing || m.state != MsgState.pending) continue;
      if (now.difference(m.t) < ackGrace) {
        _pendingAcks['${m.peer.toUpperCase()}|${m.id}'] = m.key;
      } else {
        m.state = MsgState.failed;
      }
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(messages.map((m) => m.toJson()).toList()));
    await p.setInt(_seqKey, _seq);
  }

  /// Route an inbound message packet. Returns a note worth surfacing, if any.
  String? handle(AprsPacket p) {
    final to = (p.to ?? '').toUpperCase();
    if (isBulletinAddressee(to)) {
      if (p.text != null) {
        bulletins['${p.src.toUpperCase()}|$to'] = Bulletin(p.src, to, p.text!);
        notifyListeners();
      }
      return null; // broadcasts are never acked
    }
    final mine = myCall();
    if (mine.isEmpty || to != mine.toUpperCase()) return null;

    if (p.ack != null || p.rej != null) {
      final id = p.ack ?? p.rej!;
      final key = _pendingAcks.remove('${p.src.toUpperCase()}|$id');
      if (key != null) {
        final m = messages.cast<Msg?>().firstWhere((x) => x!.key == key, orElse: () => null);
        if (m != null) {
          m.state = p.ack != null ? MsgState.acked : MsgState.failed;
          _timers.remove(m.key)?.cancel();
          _persist();
          notifyListeners();
        }
      }
      return null;
    }
    if (p.text == null) return null;

    if (p.msgId != null) {
      send(buildAckFrame(call: mine, to: p.src, id: p.msgId!));
      // drop retransmissions of something we already have
      final dup = messages.any((m) =>
          !m.outgoing &&
          m.peer == p.src &&
          m.id == p.msgId &&
          DateTime.now().difference(m.t) < const Duration(minutes: 10));
      if (dup) return null;
    }
    messages.add(Msg(
      peer: p.src,
      outgoing: false,
      text: p.text!,
      t: DateTime.now(),
      id: p.msgId ?? '',
      unread: true,
    ));
    _persist();
    notifyListeners();
    return '${p.src}: ${p.text!}';
  }

  void markRead(String peer) {
    var changed = false;
    for (final m in messages) {
      if (m.peer == peer && m.unread) {
        m.unread = false;
        changed = true;
      }
    }
    if (changed) {
      _persist();
      notifyListeners();
    }
  }

  Msg sendMessage(String peer, String text) {
    _seq = (_seq % 99998) + 1;
    final m = Msg(
      peer: peer.toUpperCase(),
      outgoing: true,
      text: text,
      t: DateTime.now(),
      id: '$_seq',
      state: MsgState.pending,
    );
    messages.add(m);
    _pendingAcks['${m.peer}|${m.id}'] = m.key;
    _persist();
    notifyListeners();
    _attempt(m);
    return m;
  }

  void _attempt(Msg m) {
    if (m.state != MsgState.pending) return;
    final ok = send(buildMessageFrame(
        call: myCall(), to: m.peer, text: m.text, id: m.id));
    if (!ok) {
      // Never left the device: wait for the link rather than burning a retry.
      m.defers++;
      if (m.defers <= maxDefers) {
        _timers[m.key] = Timer(deferEvery, () => _attempt(m));
      } else {
        _fail(m);
      }
      return;
    }
    m.tries++;
    _timers[m.key] = Timer(retryEvery, () {
      if (m.state != MsgState.pending) return;
      if (m.tries < 3) {
        _attempt(m);
      } else {
        _fail(m);
      }
    });
  }

  void _fail(Msg m) {
    m.state = MsgState.failed;
    _pendingAcks.remove('${m.peer.toUpperCase()}|${m.id}');
    _timers.remove(m.key)?.cancel();
    _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    messages.clear();
    _pendingAcks.clear();
    await _persist();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}
