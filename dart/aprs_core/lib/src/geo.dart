import 'dart:math' as math;

/// Great-circle distance in km (haversine).
double haversineKm(double la1, double lo1, double la2, double lo2) {
  const r = 6371.0;
  final dLa = (la2 - la1) * math.pi / 180, dLo = (lo2 - lo1) * math.pi / 180;
  final a = math.pow(math.sin(dLa / 2), 2) +
      math.cos(la1 * math.pi / 180) * math.cos(la2 * math.pi / 180) * math.pow(math.sin(dLo / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// Initial bearing in degrees, 0–360.
double bearingDeg(double la1, double lo1, double la2, double lo2) {
  final dLo = (lo2 - lo1) * math.pi / 180;
  final y = math.sin(dLo) * math.cos(la2 * math.pi / 180);
  final x = math.cos(la1 * math.pi / 180) * math.sin(la2 * math.pi / 180) -
      math.sin(la1 * math.pi / 180) * math.cos(la2 * math.pi / 180) * math.cos(dLo);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// Point at [distKm] along bearing [brg] from (lat, lng). Used by dead
/// reckoning and anything projecting a course line.
({double lat, double lng}) destPoint(double lat, double lng, double brg, double distKm) {
  final d = distKm / 6371, b = brg * math.pi / 180;
  final la = lat * math.pi / 180, lo = lng * math.pi / 180;
  final la2 = math.asin(math.sin(la) * math.cos(d) + math.cos(la) * math.sin(d) * math.cos(b));
  final lo2 = lo +
      math.atan2(math.sin(b) * math.sin(d) * math.cos(la),
          math.cos(d) - math.sin(la) * math.sin(la2));
  return (lat: la2 * 180 / math.pi, lng: ((lo2 * 180 / math.pi + 540) % 360) - 180);
}

/// Classic APRS PHG range estimate in miles: power p^2 W, height 10*2^h ft,
/// gain g dB. [phg] is the 4 digits after "PHG".
double phgRangeMi(String phg) {
  final watts = math.pow(int.parse(phg[0]), 2);
  final feet = 10 * math.pow(2, int.parse(phg[1]));
  final gain = math.pow(10, int.parse(phg[2]) / 10);
  return math.sqrt(2 * feet * math.sqrt((watts / 10) * (gain / 2)));
}
