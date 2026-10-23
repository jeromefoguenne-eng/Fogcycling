// ==============================================================================
// BLUETOOTH SIG STANDARDIZED UUIDS FOR SMART TRAINERS & HEART RATE SENSORS
// ==============================================================================

class BleUuids {
  // ─── FITNESS MACHINE SERVICE (FTMS) ──────────────────────────────────────────
  static const String ftmsService = "1826";
  static const String fitnessMachineFeature = "2acc";
  static const String indoorBikeData = "2ad2";
  static const String fitnessMachineControlPoint = "2ad9";
  static const String fitnessMachineStatus = "2ada";

  // ─── CYCLING POWER SERVICE (CPS) ─────────────────────────────────────────────
  static const String cyclingPowerService = "1818";
  static const String cyclingPowerMeasurement = "2a63";
  static const String cyclingPowerFeature = "2a65";

  // ─── CYCLING SPEED AND CADENCE (CSCS) ────────────────────────────────────────
  static const String cscService = "1816";
  static const String cscMeasurement = "2a5b";

  // ─── HEART RATE SERVICE (HRS) ────────────────────────────────────────────────
  static const String heartRateService = "180d";
  static const String heartRateMeasurement = "2a37";

  // ─── DEVICE INFORMATION SERVICE (DIS) ────────────────────────────────────────
  static const String deviceInformationService = "180a";
  static const String manufacturerName = "2a29";
  static const String modelNumber = "2a24";
  static const String firmwareRevision = "2a26";

  // Helpers to normalize 16-bit and 128-bit UUID strings
  static String normalize(String uuid) {
    final clean = uuid.toLowerCase().replaceAll("-", "");
    if (clean.length == 32 && clean.startsWith("0000") && clean.endsWith("00001000800000805f9b34fb")) {
      return clean.substring(4, 8);
    }
    return clean;
  }

  static bool matches(String uuid, String target16Bit) {
    final norm = normalize(uuid);
    final target = target16Bit.toLowerCase();
    return norm == target || norm.contains(target);
  }
}
