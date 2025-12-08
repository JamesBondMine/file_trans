import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';
import '../models/device_info.dart';

class FileTransferService {
  /// 下载文件
  Future<void> downloadFile({
    required DeviceInfo device,
    required Function(String fileName, int fileSize, double progress) onProgress,
    required Function(String filePath) onComplete,
    required Function(String error) onError,
  }) async {
    try {
      // 1. 先获取文件信息
      final infoUrl = '${device.address}/';
      final infoResponse = await http.get(Uri.parse(infoUrl));

      if (infoResponse.statusCode != 200) {
        onError('无法获取文件信息');
        return;
      }

      final fileInfo = jsonDecode(infoResponse.body);
      final fileName = fileInfo['fileName'] as String;
      final fileSize = fileInfo['fileSize'] as int;

      // 2. 请求存储权限（Android）
      if (Platform.isAndroid) {
        await _requestStoragePermission();
      }

      // 3. 开始下载文件
      final downloadUrl = '${device.address}/download';
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        onError('下载失败: HTTP ${streamedResponse.statusCode}');
        return;
      }

      // 4. 获取保存路径
      final savePath = await _getSavePath(fileName);
      final file = File(savePath);

      // 5. 写入文件并更新进度
      final sink = file.openWrite();
      int downloadedBytes = 0;

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        final progress = downloadedBytes / fileSize;
        onProgress(fileName, fileSize, progress);
      }

      await sink.close();

      // 6. 检查是否是图片或视频，如果是则保存到相册（仅 Android/iOS）
      if (Platform.isAndroid || Platform.isIOS) {
        await _saveToGalleryIfNeeded(savePath, fileName);
      }

      // 7. 下载完成
      onComplete(savePath);
    } catch (e) {
      onError(e.toString());
    }
  }

  /// 请求存储权限
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Android 13+ 使用新的权限模型
      if (await Permission.photos.request().isGranted ||
          await Permission.videos.request().isGranted ||
          await Permission.audio.request().isGranted) {
        return true;
      }

      // Android 12 及以下
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true;
  }

  /// 获取保存路径
  Future<String> _getSavePath(String fileName) async {
    Directory directory;

    if (Platform.isAndroid) {
      // Android: 保存到 Downloads 目录
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      }
    } else if (Platform.isIOS) {
      // iOS: 保存到应用文档目录
      directory = await getApplicationDocumentsDirectory();
    } else {
      // macOS/Windows/Linux: 保存到 Downloads 目录
      directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }

    final savePath = path.join(directory.path, fileName);
    print('文件将保存到: $savePath');
    
    return savePath;
  }

  /// 安装 APK（仅 Android）
  Future<void> installApk(String filePath) async {
    if (!Platform.isAndroid) {
      throw Exception('仅支持 Android 平台安装 APK');
    }

    try {
      // 请求安装权限
      if (await Permission.requestInstallPackages.isDenied) {
        final status = await Permission.requestInstallPackages.request();
        if (!status.isGranted) {
          throw Exception('需要安装权限才能安装 APK');
        }
      }

      // 打开 APK 文件
      final result = await OpenFilex.open(filePath);
      
      if (result.type != ResultType.done) {
        throw Exception('打开 APK 失败: ${result.message}');
      }
    } catch (e) {
      throw Exception('安装 APK 失败: $e');
    }
  }

  /// 打开文件
  Future<void> openFile(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      
      if (result.type != ResultType.done) {
        throw Exception('打开文件失败: ${result.message}');
      }
    } catch (e) {
      throw Exception('打开文件失败: $e');
    }
  }

  /// 检查文件类型并保存到相册
  Future<void> _saveToGalleryIfNeeded(String filePath, String fileName) async {
    try {
      final extension = path.extension(fileName).toLowerCase();
      
      // 图片格式
      final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.heic'];
      // 视频格式
      final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.flv', '.wmv', '.m4v'];

      if (imageExtensions.contains(extension) || videoExtensions.contains(extension)) {
        // 请求相册权限
        if (Platform.isAndroid || Platform.isIOS) {
          final status = await Permission.photos.request();
          if (!status.isGranted) {
            print('相册权限未授予，跳过保存到相册');
            return;
          }
        }

        // 使用 Gal 保存到相册
        await Gal.putImage(filePath, album: 'FileFly');
        print('✅ 文件已自动保存到相册: $fileName');
      }
    } catch (e) {
      print('保存到相册时出错: $e');
      // 不抛出错误，因为这是额外功能
    }
  }

  /// 检查文件是否为图片
  bool isImageFile(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.heic'].contains(extension);
  }

  /// 检查文件是否为视频
  bool isVideoFile(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    return ['.mp4', '.mov', '.avi', '.mkv', '.flv', '.wmv', '.m4v'].contains(extension);
  }
}

