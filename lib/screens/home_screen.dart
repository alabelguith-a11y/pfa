import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/gesture_data.dart';
import '../services/gesture_loader_service.dart';
import '../services/glove_connection_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final GloveConnectionService _glove = GloveConnectionService();
  GestureLibrary? _library;
  bool _loading = true;
  bool _sending = false;
  int _delayBetweenMs = 400;
  String? _selectedWord;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    final lib = await GestureLoaderService.load();
    if (mounted) setState(() { _library = lib; _loading = false; });
  }

  Future<void> _sendLetter(String letter) async {
    if (_library == null) return;
    final g = _library!.letterGesture(letter);
    if (g == null) return;
    setState(() => _sending = true);
    await _glove.sendGesture(g);
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _sendText() async {
    if (_library == null) return;
    final text = _textController.text.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final gestures = <GestureData>[];
    for (int i = 0; i < text.length; i++) {
      final g = _library!.letterGesture(text[i]);
      if (g != null) gestures.add(g);
    }
    await _glove.sendSequence(gestures, delayBetweenMs: _delayBetweenMs);
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _sendWord(String word) async {
    if (_library == null) return;
    final seq = _library!.wordToSequence(word);
    if (seq == null || seq.isEmpty) return;
    setState(() => _sending = true);
    final gestures = seq.map((id) => _library!.letterGesture(id)).whereType<GestureData>().toList();
    await _glove.sendSequence(gestures, delayBetweenMs: _delayBetweenMs);
    if (mounted) setState(() => _sending = false);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commande'),
        actions: [
          StreamBuilder<bool>(
            stream: _glove.connectionStream,
            initialData: _glove.isConnected,
            builder: (_, snap) {
              final connected = snap.data ?? false;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  avatar: Icon(connected ? Icons.link : Icons.link_off, color: Colors.white, size: 18),
                  label: Text(connected ? 'Connecté' : 'Déconnecté'),
                  backgroundColor: connected ? Colors.green : Colors.grey,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_ethernet),
            onPressed: () => _showConnectionSheet(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Saisie texte / lettres', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Lettres ou mot (A–Z)',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.text_fields),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _sendText(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _sending ? null : _sendText,
                    icon: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                    label: Text(_sending ? 'Envoi…' : 'Envoyer le texte'),
                  ),
                  const SizedBox(height: 24),
                  const Text('Mot prédéfini (glossaire)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedWord,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    hint: const Text('Choisir un mot'),
                    items: _library?.wordList.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList() ?? [],
                    onChanged: (v) => setState(() => _selectedWord = v),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _sending || _selectedWord == null
                        ? null
                        : () => _sendWord(_selectedWord!),
                    child: const Text('Envoyer le mot'),
                  ),
                  const SizedBox(height: 24),
                  const Text('Alphabet — toucher une lettre', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').map((letter) {
                      return ActionChip(
                        label: Text(letter),
                        onPressed: _sending ? null : () => _sendLetter(letter),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Délai entre poses (ms):'),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) => _delayBetweenMs = int.tryParse(v) ?? 400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _glove.emergencyStop,
                    icon: const Icon(Icons.warning_amber),
                    label: const Text('Arrêt d\'urgence'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ),
    );
  }

  /// Runs the full BLE flow: permissions, scan, device picker, connect.
  Future<void> _startBleConnection(BuildContext sheetContext) async {
    Navigator.pop(sheetContext);
    final ctx = context;

    // --- Step 1: Show progress so user sees something immediately
    if (!mounted) return;
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 20),
            Expanded(child: Text('Demande d\'autorisation Bluetooth…')),
          ],
        ),
      ),
    );

    // --- Step 2: Request BLE + location permissions (with "Open settings" if denied)
    var scanStatus = await Permission.bluetoothScan.status;
    var connectStatus = await Permission.bluetoothConnect.status;
    var locationStatus = await Permission.location.status;

    if (scanStatus.isPermanentlyDenied ||
        connectStatus.isPermanentlyDenied ||
        locationStatus.isPermanentlyDenied) {
      if (mounted) Navigator.of(ctx).pop();
      if (!mounted) return;
      await _showPermissionSettingsDialog(ctx);
      return;
    }
    if (!scanStatus.isGranted) scanStatus = await Permission.bluetoothScan.request();
    if (!connectStatus.isGranted) connectStatus = await Permission.bluetoothConnect.request();
    if (!locationStatus.isGranted) locationStatus = await Permission.location.request();

    if (!scanStatus.isGranted || !connectStatus.isGranted || !locationStatus.isGranted) {
      if (mounted) Navigator.of(ctx).pop();
      if (!mounted) return;
      await _showPermissionSettingsDialog(ctx);
      return;
    }

    // --- Step 3: Update dialog to "Scanning"
    if (!mounted) return;
    Navigator.of(ctx).pop();
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 20),
            Expanded(child: Text('Recherche d\'appareils BLE…')),
          ],
        ),
      ),
    );

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10)).catchError((_) {});
    await Future.delayed(const Duration(seconds: 6));
    final results = FlutterBluePlus.lastScanResults;
    await FlutterBluePlus.stopScan();

    if (!mounted) return;
    Navigator.of(ctx).pop(); // close "Scanning" dialog

    if (results.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Aucun appareil trouvé. Déconnectez le gant de nRF Connect, assurez-vous que le Bluetooth est activé, puis réessayez.'),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    final chosen = await showModalBottomSheet<BluetoothDevice>(
      context: ctx,
      builder: (c) => ListView(
        shrinkWrap: true,
        children: results.map((r) => ListTile(
          title: Text(r.device.platformName.isNotEmpty ? r.device.platformName : r.device.remoteId.toString()),
          subtitle: Text(r.device.remoteId.toString()),
          onTap: () => Navigator.pop(c, r.device),
        )).toList(),
      ),
    );

    if (chosen == null) return;

    if (!mounted) return;
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 20),
            Expanded(child: Text('Connexion au gant…')),
          ],
        ),
      ),
    );

    try {
      await _glove.connectBle(chosen);
      if (!mounted) return;
      Navigator.of(ctx).pop();
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Connecté (BLE)')));
      setState(() {});
    } catch (e) {
      if (mounted) {
        Navigator.of(ctx).pop();
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() {});
      }
    }
  }

  Future<void> _showPermissionSettingsDialog(BuildContext context) async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Autorisation Bluetooth requise'),
        content: const Text(
          'Pour détecter et connecter le gant, l\'application a besoin des autorisations '
          '« Bluetooth – scanner » et « Bluetooth – se connecter ». '
          'Activez-les dans les paramètres de l\'application.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Ouvrir les paramètres'),
          ),
        ],
      ),
    );
    if (openSettings == true) {
      await openAppSettings();
    }
  }

  void _showConnectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Connexion gant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.bluetooth),
                title: const Text('Bluetooth (BLE)'),
                subtitle: const Text('Profil GATT GestureCtrl'),
                onTap: () => _startBleConnection(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.wifi),
                title: const Text('Wi-Fi (Arduino R4)'),
                subtitle: const Text('IP:port — ex. 192.168.1.100:8888'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showWifiDialog(context);
                },
              ),
              if (_glove.isConnected)
                ListTile(
                  leading: const Icon(Icons.link_off),
                  title: const Text('Déconnecter'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _glove.disconnect();
                    if (mounted) setState(() {});
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showWifiDialog(BuildContext context) {
    final hostController = TextEditingController(text: '192.168.1.100');
    final portController = TextEditingController(text: '8888');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connexion Wi-Fi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hostController,
              decoration: const InputDecoration(labelText: 'IP Arduino'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: portController,
              decoration: const InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              final host = hostController.text.trim();
              final port = int.tryParse(portController.text.trim()) ?? 8888;
              _glove.setWifiConfig(host, port);
              Navigator.pop(ctx);
              try {
                await _glove.connectWifi();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connecté (Wi-Fi)')));
                setState(() {});
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
              }
            },
            child: const Text('Connecter'),
          ),
        ],
      ),
    );
  }
}
