/// APRS protocol core for the PacketMap Flutter port.
///
/// Ported from the PacketMap PWA (index.html) with its test vectors; the
/// PWA remains the reference implementation. Pure Dart, zero dependencies,
/// no platform APIs — everything here also runs on the web target.
library aprs_core;

export 'src/frames.dart';
export 'src/geo.dart';
export 'src/line_buffer.dart';
export 'src/packet.dart';
export 'src/parser.dart';
export 'src/passcode.dart';
export 'src/smart_beacon.dart';
