import 'package:flutter/material.dart';

/// Animierter Mikrofon-Button für den Voice-Abfrage-Screen.
///
/// Zeigt im Ruhezustand ([isRecording] = false) einen einfachen
/// Mikrofon-Icon-Button. Während der Aufnahme ([isRecording] = true)
/// erscheinen pulsierende Kreisringe um den Button, die dem Nutzer
/// visuell signalisieren, dass die App aktiv zuhört.
///
/// Die Animation ist eine kontinuierliche Skalierungsanimation, die
/// mit [AnimationController] gesteuert wird.
class MicButton extends StatefulWidget {
  const MicButton({
    super.key,
    required this.isRecording,
    required this.onTap,
    this.size = 88.0,
  });

  /// Ob gerade eine Aufnahme läuft.
  final bool isRecording;

  /// Callback wenn der Button gedrückt wird.
  final VoidCallback onTap;

  /// Durchmesser des Haupt-Buttons in Pixeln.
  final double size;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  // AnimationController steuert den Zeitablauf der Animation (0.0 → 1.0 → 0.0 ...)
  late AnimationController _controller;

  // CurvedAnimation macht die Animation nicht linear sondern "easeInOut" —
  // das fühlt sich natürlicher an als eine gleichmäßige Geschwindigkeit
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, // vsync vermeidet unnötige Frames wenn der Widget nicht sichtbar ist
      duration: const Duration(milliseconds: 1000),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animation starten/stoppen je nach Aufnahme-Status
    if (widget.isRecording && !oldWidget.isRecording) {
      _controller.repeat(reverse: true); // Pulsiert hin und her
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose(); // Wichtig: immer Controller freigeben, sonst Memory-Leak
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color activeColor = const Color(0xFFEF4444);   // Rot beim Aufnehmen
    final Color idleColor = const Color(0xFF6366F1);     // Indigo im Ruhezustand

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return SizedBox(
            // Der Stack-Bereich muss größer als der Button sein, damit
            // die Pulsier-Ringe außerhalb des Buttons sichtbar sind
            width: widget.size * 2.0,
            height: widget.size * 2.0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── Äußerer Pulsier-Ring (sichtbar nur bei Aufnahme) ──────
                if (widget.isRecording)
                  Transform.scale(
                    scale: _pulseAnimation.value * 1.1,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: activeColor.withValues(alpha: 0.1),
                      ),
                    ),
                  ),

                // ── Mittlerer Pulsier-Ring (sichtbar nur bei Aufnahme) ────
                if (widget.isRecording)
                  Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: widget.size * 0.85,
                      height: widget.size * 0.85,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: activeColor.withValues(alpha: 0.15),
                        border: Border.all(
                          color: activeColor.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                // ── Haupt-Button ──────────────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isRecording ? activeColor : idleColor,
                    boxShadow: [
                      BoxShadow(
                        color: (widget.isRecording ? activeColor : idleColor)
                            .withValues(alpha: 0.45),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: widget.size * 0.42,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
