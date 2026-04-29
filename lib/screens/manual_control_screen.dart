import 'package:flutter/material.dart';
import '../models/gesture_data.dart';
import '../services/glove_connection_service.dart';

class ManualControlScreen extends StatefulWidget {
  final Future<void> Function(GestureData) pushToVisualizer;
  const ManualControlScreen({super.key, required this.pushToVisualizer});

  @override
  State<ManualControlScreen> createState() => _ManualControlScreenState();
}

class _ManualControlScreenState extends State<ManualControlScreen> {
  final GloveConnectionService _glove = GloveConnectionService();
  List<int> _angles = [0, 0, 0, 0, 0];
  bool _sending = false;

  GestureData _currentGesture() {
    final id = 'MANUAL_${DateTime.now().millisecondsSinceEpoch}';
    return GestureData(
        id: id, speed: 0.6, durationMs: 400, angles: List<int>.from(_angles));
  }

  Future<void> _sendGesture(GestureData g) async {
    setState(() => _sending = true);
    final ok = await _glove.sendGesture(g);
    setState(() => _sending = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(ok ? 'Envoyé' : 'Échec envoi')));
  }

  Future<void> _sendAndVisualize(GestureData g) async {
    setState(() => _sending = true);
    await widget.pushToVisualizer(g);
    final ok = await _glove.sendGesture(g);
    setState(() => _sending = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              ok ? 'Envoyé et visualisé' : 'Visualisé, mais envoi échoué')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contrôle manuel')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Réglage des doigts',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            for (int i = 0; i < 5; i++) ...[
              Row(
                children: [
                  Expanded(
                      child: Text([
                    'Pouce',
                    'Index',
                    'Majeur',
                    'Annulaire',
                    'Auriculaire'
                  ][i])),
                  SizedBox(
                      width: 48,
                      child:
                          Text('${_angles[i]}°', textAlign: TextAlign.right)),
                ],
              ),
              Slider(
                value: _angles[i].toDouble(),
                min: 0,
                max: 90,
                divisions: 90,
                label: '${_angles[i]}°',
                onChanged: (v) => setState(() => _angles[i] = v.round()),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _sending
                      ? null
                      : () => _sendAndVisualize(_currentGesture()),
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: const Text('Envoyer + visualiser'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
