import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/gesture_data.dart';
import '../services/gesture_loader_service.dart';
import '../services/glove_connection_service.dart';
import 'manual_control_screen.dart';

import '../services/local_asset_server.dart';

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
  int _delayBetweenMs = 800;
  String? _selectedWord;
  late final WebViewController _web;

  @override
  void initState() {
    super.initState();
    // Initialize the controller first
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000));

    // Configure navigation and load the asset
    _web.setNavigationDelegate(
      NavigationDelegate(
        onWebResourceError: (error) =>
            debugPrint("WebView Error: ${error.description}"),
      ),
    );

    _initializeWebView();
    _loadLibrary();
  }

  Future<void> _initializeWebView() async {
    final server = LocalAssetServer();
    await server.start();
    _web.loadRequest(Uri.parse('http://127.0.0.1:${server.port}/adeva.html'));
  }

  Future<void> _pushToVisualizer(GestureData g) async {
    try {
      // 1. Create the payload map
      final Map<String, dynamic> data = {
        'id': g.id,
        'status': 'Moving to ${g.id}',
        'angles': g.angles,
      };

      // 2. Convert to JSON string
      String jsonString = jsonEncode(data);

      // 3. Cast the data into the Puppet (WebView)
      // We escape the jsonString with single quotes so JS receives it as one string
      await _web.runJavaScript("receiveDataFromFlutter('$jsonString')");
    } catch (e) {
      debugPrint("Error pushing to visualizer: $e");
    }
  }

  Future<void> _loadLibrary() async {
    final lib = await GestureLoaderService.load();
    if (mounted)
      setState(() {
        _library = lib;
        _loading = false;
      });
  }

  Future<void> _sendLetter(String letter) async {
    if (_library == null) return;
    final g = _library!.letterGesture(letter);
    if (g == null) return;
    setState(() => _sending = true);
    await _pushToVisualizer(g);
    await _glove.sendGesture(g);
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _sendText() async {
    if (_library == null) return;
    final text = _textController.text
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '');
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final gestures = <GestureData>[];
    for (int i = 0; i < text.length; i++) {
      final g = _library!.letterGesture(text[i]);
      if (g != null) gestures.add(g);
    }
    for (int i = 0; i < gestures.length; i++) {
      await _pushToVisualizer(gestures[i]);
      await _glove.sendGesture(gestures[i]);
      if (i < gestures.length - 1 && _delayBetweenMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: _delayBetweenMs));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _sendWord(String word) async {
    if (_library == null) return;
    final seq = _library!.wordToSequence(word);
    if (seq == null || seq.isEmpty) return;
    setState(() => _sending = true);
    final gestures = seq
        .map((id) => _library!.letterGesture(id))
        .whereType<GestureData>()
        .toList();
    for (int i = 0; i < gestures.length; i++) {
      await _pushToVisualizer(gestures[i]);
      await _glove.sendGesture(gestures[i]);
      if (i < gestures.length - 1 && _delayBetweenMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: _delayBetweenMs));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _emergencyStop() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await _glove.emergencyStop();
      await _pushToVisualizer(
        const GestureData(
          id: 'STOP',
          speed: 0,
          durationMs: 0,
          angles: [0, 0, 0, 0, 0],
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arrêt d\'urgence envoyé')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
          IconButton(
            icon: const Icon(Icons.fingerprint),
            tooltip: 'Contrôle manuel',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      ManualControlScreen(pushToVisualizer: _pushToVisualizer)),
            ),
          ),
          StreamBuilder<bool>(
            stream: _glove.connectionStream,
            initialData: _glove.isConnected,
            builder: (_, snap) {
              final connected = snap.data ?? false;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  avatar: Icon(connected ? Icons.link : Icons.link_off,
                      color: Colors.white, size: 18),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 320,
                      child: WebViewWidget(controller: _web),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Saisie mot',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Mot (A–Z)',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.text_fields),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _sendText(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _sending ? null : _sendText,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    label: Text(_sending ? 'Envoi…' : 'Envoyer le mot'),
                  ),
                  const SizedBox(height: 24),
                  const Text('Mot prédéfini (glossaire)',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedWord,
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
                    hint: const Text('Choisir un mot'),
                    items: _library?.wordList
                            .map((w) =>
                                DropdownMenuItem(value: w, child: Text(w)))
                            .toList() ??
                        [],
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
                  OutlinedButton.icon(
                    onPressed: _emergencyStop,
                    icon: const Icon(Icons.warning_amber),
                    label: const Text('Arrêt d\'urgence'),
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.red),
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

    // --- Step 2: Request BLE permissions (with "Open settings" if denied)
    var scanStatus = await Permission.bluetoothScan.status;
    var connectStatus = await Permission.bluetoothConnect.status;

    if (scanStatus.isPermanentlyDenied || connectStatus.isPermanentlyDenied) {
      if (mounted) Navigator.of(ctx).pop();
      if (!mounted) return;
      await _showPermissionSettingsDialog(ctx);
      return;
    }
    if (!scanStatus.isGranted)
      scanStatus = await Permission.bluetoothScan.request();
    if (!connectStatus.isGranted)
      connectStatus = await Permission.bluetoothConnect.request();

    if (!scanStatus.isGranted || !connectStatus.isGranted) {
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

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10))
        .catchError((_) {});
    await Future.delayed(const Duration(seconds: 6));
    final results = FlutterBluePlus.lastScanResults;
    await FlutterBluePlus.stopScan();

    if (!mounted) return;
    Navigator.of(ctx).pop(); // close "Scanning" dialog

    if (results.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text(
              'Aucun appareil trouvé. Déconnectez le gant de nRF Connect, assurez-vous que le Bluetooth est activé, puis réessayez.'),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    final chosen = await showModalBottomSheet<BluetoothDevice>(
      context: ctx,
      builder: (c) => ListView(
        shrinkWrap: true,
        children: results
            .map((r) => ListTile(
                  title: Text(r.device.platformName.isNotEmpty
                      ? r.device.platformName
                      : r.device.remoteId.toString()),
                  subtitle: Text(r.device.remoteId.toString()),
                  onTap: () => Navigator.pop(c, r.device),
                ))
            .toList(),
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
      ScaffoldMessenger.of(ctx)
          .showSnackBar(const SnackBar(content: Text('Connecté (BLE)')));
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
              const Text('Connexion gant',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              final host = hostController.text.trim();
              final port = int.tryParse(portController.text.trim()) ?? 8888;
              _glove.setWifiConfig(host, port);
              Navigator.pop(ctx);
              try {
                await _glove.connectWifi();
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Connecté (Wi-Fi)')));
                setState(() {});
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Erreur: $e')));
              }
            },
            child: const Text('Connecter'),
          ),
        ],
      ),
    );
  }
}
