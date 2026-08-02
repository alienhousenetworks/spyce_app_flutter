/// Generalized distance for feed privacy (not exact km).
///
/// Buckets (km):
///   <5 → 5 · 5–10 → 10 · 10–15 → 15 · 15–20 → 20 · 20–30 → 30
///   30–50 → 45 · 50–80 → 70 · 80–100 → 100 · 100–150 → 140
///   150–200 → 200 · above → exact integer km
int? generalizedDistanceKm(num? distanceKm) {
  if (distanceKm == null) return null;
  final d = distanceKm.toDouble();
  if (d.isNaN || d.isInfinite || d < 0) return null;

  if (d < 5) return 5;
  if (d < 10) return 10;
  if (d < 15) return 15;
  if (d < 20) return 20;
  if (d < 30) return 30;
  if (d < 50) return 45;
  if (d < 80) return 70;
  if (d < 100) return 100;
  if (d < 150) return 140;
  if (d < 200) return 200;
  return d.round();
}

/// e.g. `"~12 km"` — null if distance unknown.
String? generalizedDistanceLabel(num? distanceKm) {
  final v = generalizedDistanceKm(distanceKm);
  if (v == null) return null;
  return '~$v km';
}
