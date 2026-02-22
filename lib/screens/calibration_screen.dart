import 'package:flutter/material.dart';
import '../services/glove_connection_service.dart';
import '../models/gesture_data.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  static const List<String> _fingerNames = ['Pouce', 'Index', 'Majeur', 'Annulaire', 'Auriculaire'];
  final GloveConnectionService _glove = GloveConnectionService();

  Future<void> _testFinger(int fingerIndex, int angle) async {
    final angles = List<int>.filled(5, 0);
    angles[fingerIndex] = angle.clamp(0, 180);
    final g = GestureData(id: 'CAL', speed: 0.5, durationMs: 300, angles: angles);
    await _glove.sendGesture(g);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calibration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.warning_amber),
            onPressed: _glove.emergencyStop,
            tooltip: 'Arrêt d\'urgence',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Test manuel par doigt',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ouvrir = angle 0°, Fermer = angle 90°. Ajustez les butées côté firmware si besoin.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ...List.generate(5, (i) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fingerNames[i],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        FilledButton.tonal(
                          onPressed: () => _testFinger(i, 0),
                          child: const Text('Ouvrir (0°)'),
                        ),
                        FilledButton.tonal(
                          onPressed: () => _testFinger(i, 90),
                          child: const Text('Fermer (90°)'),
                        ),
                        FilledButton.tonal(
                          onPressed: () => _testFinger(i, 180),
                          child: const Text('Max (180°)'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          const Text(
            'Tous les doigts',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilledButton(
                onPressed: () async {
                  for (int i = 0; i < 5; i++) {
                    await _testFinger(i, 0);
                    await Future.delayed(const Duration(milliseconds: 200));
                  }
                },
                child: const Text('Tous ouverts'),
              ),
              FilledButton(
                onPressed: () async {
                  for (int i = 0; i < 5; i++) {
                    await _testFinger(i, 90);
                    await Future.delayed(const Duration(milliseconds: 200));
                  }
                },
                child: const Text('Tous fermés'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
