import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/gesture_data.dart';

enum ConnectionMode { none, ble, wifi }

class GloveConnectionService {
  static final GloveConnectionService _instance =
      GloveConnectionService._internal();
  factory GloveConnectionService() => _instance;

  GloveConnectionService._internal();

  ConnectionMode _mode = ConnectionMode.none;
  BluetoothDevice? _bleDevice;
  BluetoothCharacteristic? _gestureChar;
  Socket? _wifiSocket;
  String _wifiHost = '192.168.1.100';
  int _wifiPort = 8888;

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  final StreamController<String> _connectionLossController =
      StreamController<String>.broadcast();
  Stream<String> get connectionLossStream => _connectionLossController.stream;

  ConnectionMode get mode => _mode;
  bool get isConnected =>
      (_mode == ConnectionMode.ble && _bleDevice != null) ||
      (_mode == ConnectionMode.wifi && _wifiSocket != null);

  void setWifiConfig(String host, int port) {
    _wifiHost = host;
    _wifiPort = port;
  }

  Future<void> connectBle(BluetoothDevice device) async {
    try {
      // Connection timeout (Android GATT can fail with 133 if device is busy or out of range)
      await device.connect(timeout: const Duration(seconds: 15));
      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService s in services) {
        if (s.uuid.toString().toLowerCase().contains('gesture')) {
          for (BluetoothCharacteristic c in s.characteristics) {
            if (c.properties.write || c.properties.writeWithoutResponse) {
              _gestureChar = c;
              break;
            }
          }
          break;
        }
      }
      if (_gestureChar == null) {
        for (final s in services) {
          for (final c in s.characteristics) {
            if (c.properties.write || c.properties.writeWithoutResponse) {
              _gestureChar = c;
              break;
            }
          }
          if (_gestureChar != null) break;
        }
      }
      if (_gestureChar == null) {
        await device.disconnect();
        throw Exception(
          'Aucune caractéristique d\'écriture trouvée. '
          'Vérifiez que le profil GATT du gant expose un service avec une caractéristique writable.',
        );
      }
      _bleDevice = device;
      _mode = ConnectionMode.ble;
      _connectionController.add(true);
      // Monitor BLE disconnect
      _monitorBleConnection();
    } catch (e) {
      _connectionController.add(false);
      rethrow;
    }
  }

  void _monitorBleConnection() {
    _bleDevice?.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected && _mode == ConnectionMode.ble) {
        _bleDevice = null;
        _gestureChar = null;
        _mode = ConnectionMode.none;
        _connectionController.add(false);
        _connectionLossController.add('BLE connection lost');
      }
    });
  }

  Future<void> connectWifi() async {
    try {
      _wifiSocket = await Socket.connect(_wifiHost, _wifiPort,
          timeout: const Duration(seconds: 5));
      _mode = ConnectionMode.wifi;
      _connectionController.add(true);
      // Monitor WiFi socket close
      _monitorWifiConnection();
    } catch (e) {
      _connectionController.add(false);
      rethrow;
    }
  }

  void _monitorWifiConnection() {
    if (_wifiSocket != null) {
      _wifiSocket!.done.then((_) {
        if (_mode == ConnectionMode.wifi) {
          _wifiSocket = null;
          _mode = ConnectionMode.none;
          _connectionController.add(false);
          _connectionLossController.add('WiFi connection lost');
        }
      }).catchError((_) {
        if (_mode == ConnectionMode.wifi) {
          _wifiSocket = null;
          _mode = ConnectionMode.none;
          _connectionController.add(false);
          _connectionLossController.add('WiFi connection lost');
        }
      });
    }
  }

  Future<void> disconnect() async {
    if (_mode == ConnectionMode.ble && _bleDevice != null) {
      await _bleDevice!.disconnect();
      _bleDevice = null;
      _gestureChar = null;
    }
    if (_mode == ConnectionMode.wifi && _wifiSocket != null) {
      _wifiSocket!.destroy();
      _wifiSocket = null;
    }
    _mode = ConnectionMode.none;
    _connectionController.add(false);
  }

  Future<bool> sendGesture(GestureData gesture) async {
    final String frame = gesture.toCommandFrame();
    final List<int> bytes = utf8.encode(frame);

    if (_mode == ConnectionMode.ble && _gestureChar != null) {
      try {
        await _gestureChar!.write(bytes);
        return true;
      } catch (e) {
        // Detect BLE write failure as potential loss
        if (_mode == ConnectionMode.ble) {
          _bleDevice = null;
          _gestureChar = null;
          _mode = ConnectionMode.none;
          _connectionController.add(false);
          _connectionLossController.add('BLE write failed');
        }
        return false;
      }
    }

    if (_mode == ConnectionMode.wifi && _wifiSocket != null) {
      try {
        _wifiSocket!.add(bytes);
        _wifiSocket!.add([0x0a]);
        return true;
      } catch (e) {
        // Detect WiFi write failure as potential loss
        if (_mode == ConnectionMode.wifi) {
          _wifiSocket = null;
          _mode = ConnectionMode.none;
          _connectionController.add(false);
          _connectionLossController.add('WiFi write failed');
        }
        return false;
      }
    }

    return false;
  }

  Future<void> sendSequence(
    List<GestureData> gestures, {
    int delayBetweenMs = 400,
  }) async {
    for (int i = 0; i < gestures.length; i++) {
      await sendGesture(gestures[i]);
      if (i < gestures.length - 1 && delayBetweenMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: delayBetweenMs));
      }
    }
  }

  Future<void> emergencyStop() async {
    const String frame = '{"id":"STOP","speed":0,"angles":[0,0,0,0,0]}';
    final List<int> bytes = utf8.encode(frame);
    if (_mode == ConnectionMode.ble && _gestureChar != null) {
      await _gestureChar!.write(bytes);
    }
    if (_mode == ConnectionMode.wifi && _wifiSocket != null) {
      _wifiSocket!.add(bytes);
      _wifiSocket!.add([0x0a]);
    }
  }

  void dispose() {
    _connectionController.close();
    _connectionLossController.close();
  }
}
