import 'dart:io';
import 'package:flutter/services.dart';

class LocalAssetServer {
  static final LocalAssetServer _instance = LocalAssetServer._internal();
  factory LocalAssetServer() => _instance;
  LocalAssetServer._internal();

  HttpServer? _server;
  int get port => _server?.port ?? 0;

  Future<void> start() async {
    if (_server != null) return;
    
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((HttpRequest request) async {
      try {
        String path = request.uri.path;
        if (path == '/') path = '/adeva.html';
        
        final assetPath = 'assets$path';
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List();
        
        // Add CORS headers just in case
        request.response.headers.add('Access-Control-Allow-Origin', '*');
        
        if (path.endsWith('.html')) {
          request.response.headers.contentType = ContentType.html;
        } else if (path.endsWith('.js')) {
          request.response.headers.contentType = ContentType('application', 'javascript');
        } else if (path.endsWith('.css')) {
          request.response.headers.contentType = ContentType('text', 'css');
        } else if (path.endsWith('.glb')) {
          request.response.headers.contentType = ContentType('model', 'gltf-binary');
        } else if (path.endsWith('.json')) {
          request.response.headers.contentType = ContentType.json;
        }
        
        request.response.add(bytes);
        await request.response.close();
      } catch (e) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    });
  }

  void stop() {
    _server?.close();
    _server = null;
  }
}
