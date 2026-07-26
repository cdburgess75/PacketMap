// Unit tests for the non-parser half of aprs_core. Plain Dart, no package:test,
// so it runs with a bare SDK and no `pub get`:
//
//   dart test/run_tests.dart
//
// The parser is covered separately by the parity harness, which diffs
// aprs_core against the PWA over test/vectors.txt (see README.md).
import 'dart:io';

import '../lib/aprs_core.dart';

int _pass = 0, _fail = 0;

void ok(String label, bool cond, [String? detail]) {
  if (cond) {
    _pass++;
    print('  PASS  $label');
  } else {
    _fail++;
    print('  FAIL  $label${detail != null ? '\n          $detail' : ''}');
  }
}

void eq(String label, Object? got, Object? want) =>
    ok(label, got == want, 'got:  ${jsonish(got)}\n          want: ${jsonish(want)}');

void near(String label, double got, double want, double tol) =>
    ok(label, (got - want).abs() <= tol, 'got $got, want $want (+/- $tol)');

String jsonish(Object? v) => v is String ? '"$v"' : '$v';

void main() {
  print('passcode + callsign');
  eq('passcode("N0CALL") == 13023', passcode('N0CALL'), 13023);
  eq('passcode("KF5UUP") == 22689', passcode('KF5UUP'), 22689);
  eq('passcode ignores the SSID', passcode('KF5UUP-5'), passcode('KF5UUP'));
  eq('passcode is case-insensitive', passcode('kf5uup'), 22689);
  eq('formatCall appends the SSID', formatCall('KF5UUP', '5'), 'KF5UUP-5');
  eq('SSID 0 means no suffix', formatCall('KF5UUP', '0'), 'KF5UUP');
  eq('no callsign, no string', formatCall('', '9'), '');

  print('\ndegToDm');
  eq('latitude pads to 2 degree digits', degToDm(30.641, isLat: true), '3038.46N');
  eq('longitude pads to 3', degToDm(-90.311, isLat: false), '09018.66W');
  eq('southern hemisphere', degToDm(-33.86, isLat: true), '3351.60S');
  eq('eastern hemisphere', degToDm(151.209, isLat: false), '15112.54E');
  eq('minutes pad to 5 chars', degToDm(30.005, isLat: true), '3000.30N');

  print('\nTX frames (byte-for-byte with the PWA)');
  eq(
    'position beacon',
    buildPositionFrame(
      call: 'KF5UUP-5', lat: 30.641, lng: -90.311,
      symTable: '/', symCode: '[', comment: 'PacketMap',
    ),
    'KF5UUP-5>APZPKM,TCPIP*:=3038.46N/09018.66W[ PacketMap',
  );
  eq(
    'beacon with course/speed extension',
    buildPositionFrame(
      call: 'KF5UUP-9', lat: 30.641, lng: -90.311, symTable: '/', symCode: '>',
      courseDeg: 88, speedKnots: 36, comment: 'rolling',
    ),
    'KF5UUP-9>APZPKM,TCPIP*:=3038.46N/09018.66W>088/036 rolling',
  );
  eq(
    'heading 0 transmits as 360',
    buildPositionFrame(
      call: 'K-1', lat: 30.641, lng: -90.311, symTable: '/', symCode: '>',
      courseDeg: 0, speedKnots: 12,
    ),
    'K-1>APZPKM,TCPIP*:=3038.46N/09018.66W>360/012',
  );
  ok(
    'stopped stations omit the extension',
    !buildPositionFrame(
      call: 'K-1', lat: 30.641, lng: -90.311, symTable: '/', symCode: '>',
      courseDeg: 88, speedKnots: 0,
    ).contains('/000'),
  );
  eq(
    'message: addressee padded to 9, {id suffix',
    buildMessageFrame(call: 'KF5UUP-5', to: 'W5CMM-9', text: 'test message', id: '1'),
    'KF5UUP-5>APZPKM,TCPIP*::W5CMM-9  :test message{1',
  );
  eq(
    'ack',
    buildAckFrame(call: 'KF5UUP-5', to: 'KG5ABC-7', id: '45'),
    'KF5UUP-5>APZPKM,TCPIP*::KG5ABC-7 :ack45',
  );
  eq('comment truncates at 43 chars',
      buildPositionFrame(
        call: 'K-1', lat: 0, lng: 0, symTable: '/', symCode: '>',
        comment: 'x' * 60,
      ).split(' ').last.length,
      43);

  print('\nlogin + filter (matches a live AE5PL-JF session)');
  final filter = buildFilter(
    lat: 30.641, lng: -90.311, radiusKm: 50, myCall: 'KF5UUP-5', baseCall: 'KF5UUP');
  eq('filter', filter, 'r/30.641/-90.311/50 g/KF5UUP-5 b/KF5UUP*');
  eq(
    'login line',
    buildLogin(user: 'KF5UUP-5', pass: passcode('KF5UUP'), version: '2026.07.25.002', filter: filter),
    'user KF5UUP-5 pass 22689 vers PacketMap 2026.07.25.002 '
        'filter r/30.641/-90.311/50 g/KF5UUP-5 b/KF5UUP*',
  );
  eq('receive-only filter has no g/ or b/',
      buildFilter(lat: 30.641, lng: -90.311, radiusKm: 50),
      'r/30.641/-90.311/50');
  eq('watch entries append',
      buildFilter(lat: 30.0, lng: -90.0, radiusKm: 25, watch: ['W5CMM', 'KE5JZM*']),
      'r/30.000/-90.000/25 b/W5CMM b/KE5JZM*');
  eq('filter update command', buildFilterUpdate(filter), '#filter $filter');

  print('\nstream framing (the 2026.07.26.001 bug)');
  final stream = AprsLineBuffer();
  final s1 = stream.feed('# javAPRSSrvr\r\nW5A>APRS,TCPIP*:>one\r\nW5B>AP');
  eq('CRLF stream splits complete records', s1.length, 2);
  eq('partial record is held back', s1.last, 'W5A>APRS,TCPIP*:>one');
  final s2 = stream.feed('RS,TCPIP*:>two\r\n');
  eq('continuation completes it', s2.single, 'W5B>APRS,TCPIP*:>two');
  ok('stream transport detected', stream.sawNewline);

  final frames = AprsLineBuffer();
  final f1 = frames.feed('# javAPRSSrvr 4.3.4b07');
  eq('frame-per-record yields the whole frame', f1.single, '# javAPRSSrvr 4.3.4b07');
  final f2 = frames.feed('W5A>APRS,TCPIP*:>no terminator here');
  eq('every frame is one record', f2.single, 'W5A>APRS,TCPIP*:>no terminator here');
  ok('frame transport detected', !frames.sawNewline);
  frames.reset();
  ok('reset clears framing for the next connection', !frames.sawNewline);

  print('\ngeo');
  // 120.802999 km — cross-checked against the PWA's haversine to six decimals
  near('haversine New Orleans -> Baton Rouge (120.8 km / 75 mi)',
      haversineKm(29.951, -90.071, 30.451, -91.187), 120.803, 0.001);
  near('bearing due north', bearingDeg(30.0, -90.0, 31.0, -90.0), 0, 0.5);
  near('bearing due east', bearingDeg(30.0, -90.0, 30.0, -89.0), 90, 0.5);
  final dp = destPoint(30.0, -90.0, 90, 10);
  near('destPoint holds latitude going east', dp.lat, 30.0, 0.01);
  near('destPoint lands 10 km out',
      haversineKm(30.0, -90.0, dp.lat, dp.lng), 10, 0.05);
  near('PHG5130 -> ~8 mi (25 W, 20 ft, 3 dB)', phgRangeMi('5130'), 7.95, 0.1);
  near('PHG5360 -> ~19 mi (25 W, 80 ft, 6 dB)', phgRangeMi('5360'), 18.9, 0.2);

  print('\nSmartBeaconing');
  ok('parked: nothing due at 5 minutes',
      !smartBeaconDue(mph: 0, secsSinceLast: 300));
  ok('parked: due after the slow rate',
      smartBeaconDue(mph: 0, secsSinceLast: 1200));
  ok('highway: due after the fast rate',
      smartBeaconDue(mph: 65, secsSinceLast: 60));
  ok('highway: not due before it',
      !smartBeaconDue(mph: 65, secsSinceLast: 30));
  ok('mid speed scales between the two',
      smartBeaconDue(mph: 30, secsSinceLast: 121) &&
          !smartBeaconDue(mph: 30, secsSinceLast: 119));
  ok('corner pegging fires on a sharp turn',
      smartBeaconDue(mph: 45, secsSinceLast: 20, headingDeg: 90, lastHeadingDeg: 170));
  ok('a gentle drift does not',
      !smartBeaconDue(mph: 45, secsSinceLast: 20, headingDeg: 90, lastHeadingDeg: 95));
  ok('no corner pegging while stopped',
      !smartBeaconDue(mph: 1, secsSinceLast: 20, headingDeg: 90, lastHeadingDeg: 270));
  ok('turn ignored before the minimum gap',
      !smartBeaconDue(mph: 45, secsSinceLast: 5, headingDeg: 90, lastHeadingDeg: 270));

  print('\nbulletins');
  ok('BLN1 is a bulletin', isBulletinAddressee('BLN1'));
  ok('BLNA is a bulletin', isBulletinAddressee('BLNA'));
  ok('a callsign is not', !isBulletinAddressee('KF5UUP-5'));
  ok('BLN10 is not (single char slot)', !isBulletinAddressee('BLN10'));

  print('\n$_pass passed, $_fail failed');
  if (_fail > 0) exit(1);
}
