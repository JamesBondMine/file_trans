import 'dart:io';
import 'package:flutter/material.dart';
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

class _SenderPageState extends State<SenderPage> {
  FileServer? _fileServer;
  File? _selectedFile;
  String? _localIP;
  final int _port = 8080;
  bool _isServerRunning = false;
  final List<String> _connectionLog = [];

  @override
  void initState() {
    super.initState();
    _getLocalIP();
  }

  @override
  void dispose() {
    _stopServer();
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
            _addLog('设备连接: $clientIP');
          });
        },
        onDownloadStart: () {
          setState(() {
            _addLog('开始传输文件...');
          });
        },
        onDownloadComplete: () {
          setState(() {
            _addLog('文件传输完成！');
          });
        },
      );

      await _fileServer!.start();
      setState(() {
        _isServerRunning = true;
        _addLog('服务器已启动: http://$_localIP:$_port');
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
        _addLog('服务器已停止');
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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
      appBar: AppBar(
        title: const Text('发送文件'),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 设备信息卡片
            _buildDeviceInfoCard(deviceInfo),
            const SizedBox(height: 16),

            // 文件选择卡片
            _buildFileSelectionCard(),
            const SizedBox(height: 16),

            // 二维码卡片（服务器运行时显示）
            if (_isServerRunning && _localIP != null && _localIP != '无法获取IP')
              _buildQRCodeCard(deviceInfo),
            
            if (_isServerRunning && _localIP != null && _localIP != '无法获取IP')
              const SizedBox(height: 16),

            // 连接日志
            _buildConnectionLog(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfoCard(DeviceInfo deviceInfo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.devices, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '本机信息',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow('设备类型', deviceInfo.deviceType),
            _buildInfoRow('IP地址', deviceInfo.ip),
            _buildInfoRow('端口', deviceInfo.port.toString()),
            _buildInfoRow('状态', _isServerRunning ? '运行中' : '未启动',
                statusColor: _isServerRunning ? Colors.green : Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.insert_drive_file, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '文件选择',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(),
            if (_selectedFile != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '已选择文件:',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedFile!.path.split('/').last,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '大小: ${(_selectedFile!.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isServerRunning ? null : _pickFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('选择文件'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _isServerRunning
                      ? FilledButton.tonalIcon(
                          onPressed: _stopServer,
                          icon: const Icon(Icons.stop),
                          label: const Text('停止服务'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade100,
                            foregroundColor: Colors.red.shade900,
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: _selectedFile != null ? _startServer : null,
                          icon: const Icon(Icons.send),
                          label: const Text('开始发送'),
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              '扫描二维码快速连接',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: deviceInfo.address,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              deviceInfo.address,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionLog() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '连接日志',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                if (_connectionLog.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _connectionLog.clear();
                      });
                    },
                    child: const Text('清除'),
                  ),
              ],
            ),
            const Divider(),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: _connectionLog.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          '暂无日志',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _connectionLog.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            _connectionLog[index],
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
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

  Widget _buildInfoRow(String label, String value, {Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
          ),
        ],
      ),
    );
  }
}

