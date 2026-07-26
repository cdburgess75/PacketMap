/// APRS-IS passcode: the standard XOR hash over the base callsign (no SSID).
int passcode(String call) {
  final c = call.toUpperCase().split('-')[0];
  var hash = 0x73e2;
  for (var i = 0; i < c.length; i += 2) {
    hash ^= c.codeUnitAt(i) << 8;
    if (i + 1 < c.length) hash ^= c.codeUnitAt(i + 1);
  }
  return hash & 0x7fff;
}

/// "KF5UUP" + "5" → "KF5UUP-5"; SSID "0" means no suffix.
String formatCall(String base, String ssid) =>
    base.isEmpty ? '' : (ssid != '0' ? '$base-$ssid' : base);
