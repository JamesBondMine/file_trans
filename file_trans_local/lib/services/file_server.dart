import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

class FileServer {
  final File file;
  final int port;
  final Function(String clientIP)? onConnection;
  final Function()? onDownloadStart;
  final Function()? onDownloadComplete;

  HttpServer? _server;

  FileServer({
    required this.file,
    required this.port,
    this.onConnection,
    this.onDownloadStart,
    this.onDownloadComplete,
  });

  Future<void> start() async {
    final handler = Pipeline()
        .addMiddleware(_logRequests())
        .addMiddleware(_corsHeaders())
        .addHandler(_handleRequest);

    _server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      port,
    );

    print('文件服务器已启动: http://${_server!.address.host}:${_server!.port}');
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    print('文件服务器已停止');
  }

  Middleware _logRequests() {
    return (Handler innerHandler) {
      return (Request request) async {
        final clientIP = request.headers['x-forwarded-for'] ?? 
                        request.context['shelf.io.connection_info']?.toString() ?? 
                        'Unknown';
        
        print('请求: ${request.method} ${request.url} from $clientIP');
        onConnection?.call(clientIP);

        return await innerHandler(request);
      };
    };
  }

  Middleware _corsHeaders() {
    return createMiddleware(
      responseHandler: (Response response) {
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type',
        });
      },
    );
  }

  Future<Response> _handleRequest(Request request) async {
    // 处理 OPTIONS 请求
    if (request.method == 'OPTIONS') {
      return Response.ok('');
    }

    // 根路径 - 返回文件信息
    if (request.url.path == '' || request.url.path == '/') {
      return _handleFileInfo();
    }

    // 下载路径 - 返回文件内容
    if (request.url.path == 'download') {
      return await _handleFileDownload();
    }

    return Response.notFound('Not Found');
  }

  Response _handleFileInfo() {
    final fileName = path.basename(file.path);
    final fileSize = file.lengthSync();
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

    final info = {
      'fileName': fileName,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'downloadUrl': '/download',
    };

    return Response.ok(
      jsonEncode(info),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }

  Future<Response> _handleFileDownload() async {
    onDownloadStart?.call();

    final fileName = path.basename(file.path);
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    final fileBytes = await file.readAsBytes();

    // 下载完成后调用回调
    Future.delayed(const Duration(milliseconds: 100), () {
      onDownloadComplete?.call();
    });

    return Response.ok(
      fileBytes,
      headers: {
        'Content-Type': mimeType,
        'Content-Disposition': 'attachment; filename="$fileName"',
        'Content-Length': fileBytes.length.toString(),
      },
    );
  }
}

