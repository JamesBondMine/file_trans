import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../services/file_server.dart';
import '../models/device_info.dart';

class SenderPage extends StatefulWidget {
  const SenderPage({super.key});

  @override
  State<SenderPage> createState() => _SenderPageState();
}

class _SenderPageState extends State<SenderPage> with SingleTickerProviderStateMixin {
  FileServer? _fileServer;
  File? _selectedFile;
  String? _localIP;
  final int _port = 8080;
  bool _isServerRunning = false;
  final List<String> _connectionLog = [];
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _getLocalIP();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _stopServer();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _getLocalIP() async {
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();
      setState(() {
        _localIP = wifiIP;
      });
    } catch (e) {
      setState(() {
        _localIP = '无法获取IP';
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
        _addLog('已选择文件: ${_selectedFile!.path.split('/').last}');
      }
    } catch (e) {
      _showError('选择文件失败: $e');
    }
  }

  Future<void> _startServer() async {
    if (_selectedFile == null) {
      _showError('请先选择要发送的文件');
      return;
    }

    if (_localIP == null || _localIP == '无法获取IP') {
      _showError('无法获取本机IP地址，请检查网络连接');
      return;
    }

    try {
      _fileServer = FileServer(
        file: _selectedFile!,
        port: _port,
        onConnection: (clientIP) {
          setState(() {
            _addLog('🔗 设备连接: $clientIP');
          });
        },
        onDownloadStart: () {
          setState(() {
            _addLog('📤 开始传输文件...');
          });
        },
        onDownloadComplete: () {
          setState(() {
            _addLog('✅ 文件传输完成！');
          });
        },
      );

      await _fileServer!.start();
      setState(() {
        _isServerRunning = true;
        _addLog('🚀 服务器已启动: http://$_localIP:$_port');
      });
    } catch (e) {
      _showError('启动服务器失败: $e');
    }
  }

  Future<void> _stopServer() async {
    if (_fileServer != null) {
      await _fileServer!.stop();
      setState(() {
        _isServerRunning = false;
        _addLog('⏹️ 服务器已停止');
      });
    }
  }

  void _addLog(String message) {
    setState(() {
      _connectionLog.insert(0, '${DateTime.now().toString().substring(11, 19)} - $message');
      if (_connectionLog.length > 50) {
        _connectionLog.removeLast();
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension)) {
      return '🖼️';
    } else if (['mp4', 'mov', 'avi', 'mkv'].contains(extension)) {
      return '🎬';
    } else if (['pdf'].contains(extension)) {
      return '📄';
    } else if (['apk'].contains(extension)) {
      return '📦';
    } else if (['zip', 'rar', '7z'].contains(extension)) {
      return '🗜️';
    } else if (['mp3', 'wav', 'flac'].contains(extension)) {
      return '🎵';
    }
    return '📁';
  }

  @override
  Widget build(BuildContext context) {
    final deviceInfo = DeviceInfo(
      name: Platform.isMacOS ? 'Mac' : Platform.isAndroid ? 'Android' : Platform.isIOS ? 'iOS' : 'Unknown',
      ip: _localIP ?? '获取中...',
      port: _port,
      deviceType: Platform.operatingSystem,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.send_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('发送文件'),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 设备信息卡片
            _buildDeviceInfoCard(deviceInfo)
                .animate()
                .fadeIn(duration: 600.ms)
                .slideX(begin: -0.2, end: 0),
            
            const SizedBox(height: 20),

            // 文件选择卡片
            _buildFileSelectionCard()
                .animate(delay: 100.ms)
                .fadeIn(duration: 600.ms)
                .slideX(begin: -0.2, end: 0),
            
            const SizedBox(height: 20),

            // 二维码卡片（服务器运行时显示）
            if (_isServerRunning && _localIP != null && _localIP != '无法获取IP')
              _buildQRCodeCard(deviceInfo)
                  .animate(delay: 200.ms)
                  .fadeIn(duration: 600.ms)
                  .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
            
            if (_isServerRunning && _localIP != null && _localIP != '无法获取IP')
              const SizedBox(height: 20),

            // 连接日志
            _buildConnectionLog()
                .animate(delay: 300.ms)
                .fadeIn(duration: 600.ms)
                .slideX(begin: -0.2, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfoCard(DeviceInfo deviceInfo) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.devices_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '本机信息',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _isServerRunning ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isServerRunning ? '运行中' : '未启动',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow(Icons.computer_rounded, '设备类型', deviceInfo.deviceType.toUpperCase()),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.wifi_rounded, 'IP地址', deviceInfo.ip),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.lan_rounded, '端口', deviceInfo.port.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
              ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
        ),
      ],
    );
  }

  Widget _buildFileSelectionCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insert_drive_file_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  '文件选择',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_selectedFile != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.tertiaryContainer,
                      Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _getFileIcon(_selectedFile!.path.split('/').last),
                          style: const TextStyle(fontSize: 40),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedFile!.path.split('/').last,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(_selectedFile!.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onTertiaryContainer.withOpacity(0.7),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isServerRunning ? null : _pickFile,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('选择文件'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _isServerRunning
                      ? FilledButton.tonalIcon(
                          onPressed: _stopServer,
                          icon: const Icon(Icons.stop_circle_rounded),
                          label: const Text('停止服务'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.red.shade100,
                            foregroundColor: Colors.red.shade900,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: _selectedFile != null ? _startServer : null,
                          icon: const Icon(Icons.rocket_launch_rounded),
                          label: const Text('开始发送'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCodeCard(DeviceInfo deviceInfo) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.surfaceContainerHighest,
              Theme.of(context).colorScheme.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_2_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  '扫描二维码快速连接',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: QrImageView(
                data: deviceInfo.address,
                version: QrVersions.auto,
                size: 220.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                deviceInfo.address,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionLog() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '连接日志',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                if (_connectionLog.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _connectionLog.clear();
                      });
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: '清除日志',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _connectionLog.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event_note_rounded,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '暂无日志记录',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      shrinkWrap: true,
                      itemCount: _connectionLog.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            _connectionLog[index],
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

