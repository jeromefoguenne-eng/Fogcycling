import 'dart:convert';
import 'dart:io';

/// Préréglages de performance graphique WebGL & d'économie de batterie sur mobile (Phase 8)
enum GraphicsQualityPreset {
  ecoBattery(
    "eco",
    "🔋 Éco Batterie (Longue Étape 1h30)",
    "PixelRatio 1.0x • Sans ombres portées • Chauffe minimale du smartphone",
  ),
  balanced60Fps(
    "balanced",
    "⚡ Équilibré 60 FPS (Recommandé)",
    "PixelRatio 1.5x • Ombres optimisées • Fluidité maximale",
  ),
  ultraCartoonHd(
    "ultra",
    "✨ Ultra Cartoon HD (Qualité Studio)",
    "PixelRatio 2.0x • Ombres douces PCFSoft 1024px • Rendu Pixar/Zwift max",
  );

  final String jsKey;
  final String title;
  final String description;
  const GraphicsQualityPreset(this.jsKey, this.title, this.description);
}

/// Gestionnaire de persistance locale hors-ligne (Phase 8)
/// Sauvegarde automatiquement le profil, les maillots/points et les préférences graphiques sur le disque local.
class LocalPersistenceManager {
  static File _getStorageFile() {
    final dir = Directory.systemTemp;
    return File('${dir.path}${Platform.pathSeparator}fogcycling_state_v1.json');
  }

  static Future<void> saveState(Map<String, dynamic> data) async {
    try {
      final file = _getStorageFile();
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {
      // Ignoré en environnement de test restreint
    }
  }

  static Future<Map<String, dynamic>?> loadState() async {
    try {
      final file = _getStorageFile();
      if (await file.exists()) {
        final raw = await file.readAsString();
        return jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
