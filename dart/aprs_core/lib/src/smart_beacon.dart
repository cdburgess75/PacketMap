/// SmartBeaconing: rate scales with speed; corner pegging on heading change.
/// Pure decision logic — the caller owns the clock and the GPS.
class SmartBeaconConfig {
  const SmartBeaconConfig({
    this.slowRateSecs = 1200,
    this.fastRateSecs = 60,
    this.slowSpeedMph = 5,
    this.fastSpeedMph = 60,
    this.minTurnAngleDeg = 15,
    this.minTurnTimeSecs = 15,
    this.turnSlope = 240,
  });

  final int slowRateSecs; // stopped: beacon every N s
  final int fastRateSecs; // at/above fast speed: every N s
  final int slowSpeedMph;
  final int fastSpeedMph;
  final int minTurnAngleDeg;
  final int minTurnTimeSecs;
  final int turnSlope;
}

/// True when a beacon is due. Mirrors the PWA's smartBeaconTick():
/// corner pegging first (only while moving), then the speed-scaled rate.
bool smartBeaconDue({
  required double mph,
  required double secsSinceLast,
  double? headingDeg,
  double? lastHeadingDeg,
  SmartBeaconConfig cfg = const SmartBeaconConfig(),
}) {
  final double rate;
  if (mph < cfg.slowSpeedMph) {
    rate = cfg.slowRateSecs.toDouble();
  } else if (mph >= cfg.fastSpeedMph) {
    rate = cfg.fastRateSecs.toDouble();
  } else {
    rate = cfg.fastRateSecs * cfg.fastSpeedMph / mph;
  }
  if (mph >= cfg.slowSpeedMph &&
      headingDeg != null &&
      lastHeadingDeg != null &&
      secsSinceLast >= cfg.minTurnTimeSecs) {
    var dh = (headingDeg - lastHeadingDeg).abs();
    if (dh > 180) dh = 360 - dh;
    if (dh > cfg.minTurnAngleDeg + cfg.turnSlope / (mph < 1 ? 1 : mph)) return true;
  }
  return secsSinceLast >= rate;
}
