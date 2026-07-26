// Engine tests: the parts that decide what goes on the air and what the user
// is told. No widgets, no device — these run on the Dart VM.
import 'package:aprs_core/aprs_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:packetmap/src/message_store.dart';
import 'package:packetmap/src/settings.dart';
import 'package:packetmap/src/station_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('StationStore', () {
    test('folds successive packets into one station', () {
      final s = StationStore();
      s.ingest(parsePacket('W5CMM-9>APRS,TCPIP*:!3035.00N/09015.00W>090/045 rolling')!);
      s.ingest(parsePacket('W5CMM-9>APRS,TCPIP*:!3036.00N/09015.00W>095/050 still going')!);
      expect(s.length, 1);
      final st = s['W5CMM-9']!;
      expect(st.speed, 50);
      expect(st.course, 95);
      expect(st.track.length, 2, reason: 'a move should extend the tail');
    });

    test('objects are keyed by object name, and remember who reported them', () {
      final s = StationStore();
      s.ingest(parsePacket(
          'W5OBJ-1>APRS,TCPIP*:;LEADER   *092345z3030.00N/09010.00W>088/036 obj')!);
      expect(s['LEADER'], isNotNull);
      expect(s['LEADER']!.via, 'W5OBJ-1');
    });

    test('a repeated identical position does not grow the tail', () {
      final s = StationStore();
      const line = 'W5LA-1>APRS,TCPIP*:!3038.10N/09018.00W-home';
      s.ingest(parsePacket(line)!);
      s.ingest(parsePacket(line)!);
      expect(s['W5LA-1']!.track.length, 1);
    });

    test('range comes from RNG, else PHG', () {
      final s = StationStore();
      s.ingest(parsePacket('W5LA-1>APRS,TCPIP*:!3038.10N/09018.00W-RNG0025 home')!);
      s.ingest(parsePacket('N5YHM-1>APN391,TCPIP*:!3028.26N/09002.60W#PHG5130 digi')!);
      expect((s['W5LA-1']!.rangeKm! * 0.621371).round(), 25);
      expect((s['N5YHM-1']!.rangeKm! * 0.621371).round(), 8);
      s.ingest(parsePacket('KG5ABC-7>APRS,TCPIP*:!3037.00N/09017.00W[walking')!);
      expect(s['KG5ABC-7']!.rangeKm, isNull, reason: 'no PHG/RNG means no circle');
    });

    test('dead reckoning only for stations actually moving and recently heard', () {
      final s = StationStore();
      s.ingest(parsePacket('W5CMM-9>APRS,TCPIP*:!3035.00N/09015.00W>090/045 east')!);
      final st = s['W5CMM-9']!;
      expect(st.deadReckoned(), isNull, reason: 'just heard: nothing to project yet');
      st.lastHeard = DateTime.now().subtract(const Duration(minutes: 5));
      final dr = st.deadReckoned()!;
      expect(dr.lng, greaterThan(st.lng!), reason: 'heading 090 goes east');
      expect(haversineKm(st.lat!, st.lng!, dr.lat, dr.lng), closeTo(45 * 1.852 / 12, 0.2));
      st.lastHeard = DateTime.now().subtract(const Duration(minutes: 45));
      expect(st.deadReckoned(), isNull, reason: 'too stale to guess');
      final parked = StationStore()
        ..ingest(parsePacket('W5SIT-1>APRS,TCPIP*:!3035.00N/09015.00W>000/000 parked')!);
      parked['W5SIT-1']!.lastHeard = DateTime.now().subtract(const Duration(minutes: 5));
      expect(parked['W5SIT-1']!.deadReckoned(), isNull);
    });

    test('sorts by distance, age and callsign', () {
      final s = StationStore();
      s.ingest(parsePacket('BBB-1>APRS,TCPIP*:!3100.00N/09000.00W-far')!);
      s.ingest(parsePacket('AAA-1>APRS,TCPIP*:!3001.00N/09000.00W-near')!);
      final byDist = s.sorted(HeardSort.distance, fromLat: 30, fromLng: -90);
      expect(byDist.first.call, 'AAA-1');
      expect(s.sorted(HeardSort.call).first.call, 'AAA-1');
      expect(s.sorted(HeardSort.age).first.call, 'AAA-1', reason: 'most recent first');
      expect(s.sorted(HeardSort.distance, query: 'BBB').length, 1);
    });

    test('prunes stations unheard for six hours but keeps the open one', () {
      final s = StationStore();
      s.ingest(parsePacket('OLD-1>APRS,TCPIP*:!3000.00N/09000.00W-old')!);
      s.ingest(parsePacket('KEEP-1>APRS,TCPIP*:!3000.00N/09000.00W-keep')!);
      for (final st in s.all) {
        st.lastHeard = DateTime.now().subtract(const Duration(hours: 7));
      }
      s.prune(keep: 'KEEP-1');
      expect(s['OLD-1'], isNull);
      expect(s['KEEP-1'], isNotNull);
    });
  });

  group('MessageStore', () {
    late List<String> sent;
    late bool linkUp;
    MessageStore build() {
      sent = [];
      linkUp = true;
      return MessageStore(
        send: (r) {
          if (!linkUp) return false;
          sent.add(r);
          return true;
        },
        myCall: () => 'KF5UUP-5',
      );
    }

    test('sends a well-formed message and acks on reply', () async {
      final m = build();
      final msg = m.sendMessage('W5CMM-9', 'hello');
      expect(sent.single, 'KF5UUP-5>APZPKM,TCPIP*::W5CMM-9  :hello{${msg.id}');
      expect(msg.state, MsgState.pending);
      m.handle(parsePacket('W5CMM-9>APRS,TCPIP*::KF5UUP-5 :ack${msg.id}')!);
      expect(msg.state, MsgState.acked);
    });

    test('a reject marks the message failed', () {
      final m = build();
      final msg = m.sendMessage('W5CMM-9', 'nope');
      m.handle(parsePacket('W5CMM-9>APRS,TCPIP*::KF5UUP-5 :rej${msg.id}')!);
      expect(msg.state, MsgState.failed);
    });

    test('a send that never left the device is deferred, not counted as a try', () {
      final m = build();
      linkUp = false;
      final msg = m.sendMessage('W5CMM-9', 'while offline');
      expect(sent, isEmpty);
      expect(msg.state, MsgState.pending, reason: 'still queued, not failed');
      expect(msg.tries, 0, reason: 'no on-air attempt was spent');
      expect(msg.defers, 1);
    });

    test('incoming messages are auto-acked and deduped', () {
      final m = build();
      const line = 'KG5ABC-7>APRS,TCPIP*::KF5UUP-5 :on the levee{45';
      final note = m.handle(parsePacket(line)!);
      expect(note, contains('on the levee'));
      expect(sent.single, 'KF5UUP-5>APZPKM,TCPIP*::KG5ABC-7 :ack45');
      m.handle(parsePacket(line)!); // retransmission
      expect(m.thread('KG5ABC-7').length, 1, reason: 'duplicate dropped');
      expect(sent.length, 2, reason: 'but re-acked, since the sender clearly missed it');
    });

    test('bulletins are collected, never acked, keyed by sender and slot', () {
      final m = build();
      m.handle(parsePacket('W5NET-1>APRS,TCPIP*::BLN1     :net at 1900')!);
      m.handle(parsePacket('W5NET-1>APRS,TCPIP*::BLN1     :net at 2000')!);
      m.handle(parsePacket('W5NET-1>APRS,TCPIP*::BLNA     :skywarn up')!);
      expect(m.bulletins.length, 2, reason: 'same slot replaces in place');
      expect(m.bulletins['W5NET-1|BLN1']!.text, 'net at 2000');
      expect(sent, isEmpty, reason: 'broadcasts must never be acked');
      expect(m.messages, isEmpty, reason: 'bulletins are not a conversation');
    });

    test('messages for other stations are ignored', () {
      final m = build();
      expect(m.handle(parsePacket('W5A>APRS,TCPIP*::W5OTHER-1:not for us{9')!), isNull);
      expect(m.messages, isEmpty);
      expect(sent, isEmpty);
    });

    test('a young pending message keeps its ack lookup across a restart', () async {
      final first = build();
      final msg = first.sendMessage('W5CMM-9', 'survives a restart');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final second = MessageStore(send: (r) => true, myCall: () => 'KF5UUP-5');
      await second.load();
      final restored = second.messages.firstWhere((x) => x.id == msg.id);
      expect(restored.state, MsgState.pending);
      // the ack arrives only now, after the restart
      second.handle(parsePacket('W5CMM-9>APRS,TCPIP*::KF5UUP-5 :ack${msg.id}')!);
      expect(restored.state, MsgState.acked,
          reason: 'an ack after a restart must still resolve the message');
    });

    test('an old pending message is failed on load, not left "sending"', () async {
      final store = build();
      store.messages.add(Msg(
        peer: 'W5OLD-1',
        outgoing: true,
        text: 'sent an hour ago',
        t: DateTime.now().subtract(const Duration(hours: 1)),
        id: '77',
        state: MsgState.pending,
      ));
      await store.clear(); // flush an empty store first
      final seeded = MessageStore(send: (r) => true, myCall: () => 'KF5UUP-5');
      seeded.messages.add(Msg(
        peer: 'W5OLD-1',
        outgoing: true,
        text: 'sent an hour ago',
        t: DateTime.now().subtract(const Duration(hours: 1)),
        id: '77',
        state: MsgState.pending,
      ));
      seeded.sendMessage('X-1', 'forces a persist');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final reloaded = MessageStore(send: (r) => true, myCall: () => 'KF5UUP-5');
      await reloaded.load();
      final old = reloaded.messages.firstWhere((m) => m.id == '77');
      expect(old.state, MsgState.failed);
    });
  });

  group('Settings', () {
    test('myCall honours the SSID, including a numeric zero', () {
      final s = Settings()
        ..call = 'KF5UUP'
        ..ssid = '5';
      expect(s.myCall, 'KF5UUP-5');
      s.ssid = '0';
      expect(s.myCall, 'KF5UUP');
      s.call = '';
      expect(s.myCall, '', reason: 'no callsign means receive-only');
    });

    test('builds the server-side filter the way APRS-IS expects', () {
      final s = Settings()
        ..call = 'KF5UUP'
        ..ssid = '5'
        ..radiusKm = 50
        ..watch = ['W5CMM'];
      expect(s.filterFor(30.641, -90.311),
          'r/30.641/-90.311/50 g/KF5UUP-5 b/KF5UUP* b/W5CMM');
    });

    test('watch matching handles exact calls and * prefixes', () {
      final s = Settings()..watch = ['W5CMM', 'KE5*'];
      expect(s.isWatched('W5CMM'), isTrue);
      expect(s.isWatched('w5cmm'), isTrue);
      expect(s.isWatched('W5CMM-9'), isFalse, reason: 'exact means exact');
      expect(s.isWatched('KE5JZM-1'), isTrue, reason: 'prefix wildcard');
      expect(s.isWatched('N5XYZ'), isFalse);
    });

    test('a numeric ssid in stored settings is tolerated', () async {
      SharedPreferences.setMockInitialValues({
        'packetmap-settings': '{"call":"KF5UUP","ssid":9}',
      });
      final s = Settings();
      await s.load();
      expect(s.myCall, 'KF5UUP-9');
    });
  });
}
