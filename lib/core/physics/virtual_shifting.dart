/// Moteur de changement de braquet virtuel pour le Zwift Cog
/// Le Zwift Cog étant un pignon fixe mécanique de 14 dents, le changement de vitesse
/// s'effectue mathématiquement au niveau de la résistance et du moteur physique.
class VirtualShifter {
  static const int totalGears = 24;

  // Tableau des 24 ratios séquentiels équivalents à une transmission route moderne
  // (Pédalier 50/34 avec cassette 11-34)
  static const List<double> gearRatios = [
    0.85, 0.95, 1.06, 1.15, 1.25, 1.35, 1.48, 1.62, // Braquets de montagne (1 à 8)
    1.78, 1.95, 2.15, 2.38, 2.62, 2.88, 3.15, 3.45, // Braquets intermédiaires (9 à 16)
    3.75, 4.05, 4.35, 4.65, 4.95, 5.15, 5.35, 5.55, // Braquets de sprint / descente (17 à 24)
  ];

  int _currentGear = 10; // Rapport de départ équilibré (environ 34x17 / 50x25)

  int get currentGear => _currentGear;
  double get currentRatio => gearRatios[_currentGear - 1];

  /// Monter un rapport (plus dur, vitesse supérieure)
  bool shiftUp() {
    if (_currentGear < totalGears) {
      _currentGear++;
      return true;
    }
    return false;
  }

  /// Descendre un rapport (plus souple, pour grimper)
  bool shiftDown() {
    if (_currentGear > 1) {
      _currentGear--;
      return true;
    }
    return false;
  }

  /// Définir directement un rapport
  void setGear(int gear) {
    if (gear >= 1 && gear <= totalGears) {
      _currentGear = gear;
    }
  }

  /// Ajuste une pente simulée en fonction du rapport virtuel engagé.
  /// Un rapport plus petit (montagne) adoucit le couple requis sur le trainer.
  double computeApparentSlope(double actualRouteSlope) {
    // Ratio de référence (neutre = vitesse 12, ratio ~ 2.38)
    final neutralRatio = gearRatios[11];
    final relativeDrivetrainRatio = currentRatio / neutralRatio;

    // La résistance apparente envoyée au trainer est proportionnelle à la démultiplication
    return actualRouteSlope * relativeDrivetrainRatio;
  }
}
