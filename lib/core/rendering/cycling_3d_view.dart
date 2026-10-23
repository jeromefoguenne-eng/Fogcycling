import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Composant de rendu WebGL / Three.js pour le monde virtuel 3D de Fogcycling.
/// Charge le moteur cartoon autonome localisé dans `assets/3d_world/index.html`
/// et assure la communication bidirectionnelle continue avec le Home Trainer (FTMS) et le Peloton IA.
class Cycling3dView extends StatefulWidget {
  final int watts;
  final double cadenceRpm;
  final double speedKmh;
  final double slopePercent;
  final int gear;
  final String themeKey;
  final int bikeHexColor;
  final int jerseyHexColor;

  const Cycling3dView({
    super.key,
    required this.watts,
    required this.cadenceRpm,
    required this.speedKmh,
    required this.slopePercent,
    required this.gear,
    this.themeKey = 'ventoux_lunar',
    this.bikeHexColor = 0xFFF97316,
    this.jerseyHexColor = 0xFF0284C7,
  });

  @override
  State<Cycling3dView> createState() => _Cycling3dViewState();
}

class _Cycling3dViewState extends State<Cycling3dView> {
  late final WebViewController _controller;
  bool _isPageLoaded = false;
  DateTime _lastTelemetryUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastSentTheme = '';
  int _lastBikeColor = 0;
  int _lastJerseyColor = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF7DD3FC))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _isPageLoaded = true;
              });
              _sendTelemetryToJs();
            }
          },
          onWebResourceError: (error) {
            debugPrint("⚠️ Erreur WebGL / WebView 3D : ${error.description}");
          },
        ),
      )
      ..loadFlutterAsset('assets/3d_world/index.html');
  }

  @override
  void didUpdateWidget(covariant Cycling3dView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final now = DateTime.now();
    if (now.difference(_lastTelemetryUpdate).inMilliseconds >= 60 ||
        oldWidget.themeKey != widget.themeKey ||
        oldWidget.bikeHexColor != widget.bikeHexColor ||
        oldWidget.jerseyHexColor != widget.jerseyHexColor) {
      _lastTelemetryUpdate = now;
      _sendTelemetryToJs();
    }
  }

  void _sendTelemetryToJs() {
    if (!_isPageLoaded) return;
    final themeJs = (_lastSentTheme != widget.themeKey)
        ? "if (window.setEnvironmentTheme) { window.setEnvironmentTheme('${widget.themeKey}'); }"
        : "";
    _lastSentTheme = widget.themeKey;

    final rgbBike = widget.bikeHexColor & 0xFFFFFF;
    final rgbJersey = widget.jerseyHexColor & 0xFFFFFF;
    final equipJs = (_lastBikeColor != rgbBike || _lastJerseyColor != rgbJersey)
        ? "if (window.setPlayerEquipmentColors) { window.setPlayerEquipmentColors($rgbBike, $rgbJersey); }"
        : "";
    _lastBikeColor = rgbBike;
    _lastJerseyColor = rgbJersey;

    final jsCode =
        "$themeJs$equipJs if (window.setRiderTelemetry) { window.setRiderTelemetry(${widget.watts}, ${widget.cadenceRpm.toStringAsFixed(1)}, ${widget.speedKmh.toStringAsFixed(1)}, ${widget.slopePercent.toStringAsFixed(1)}, ${widget.gear}); }";
    _controller.runJavaScript(jsCode);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (!_isPageLoaded)
          Container(
            color: const Color(0xFF0F172A),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.amber),
                  SizedBox(height: 16),
                  Text(
                    "Génération du monde 3D Fogcycling...",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
