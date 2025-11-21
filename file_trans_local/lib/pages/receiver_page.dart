import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/device_discovery.dart';
import '../services/file_transfer.dart';
import '../models/device_info.dart';
import '../models/transfer_info.dart';

class ReceiverPage extends StatefulWidget {
  const ReceiverPage({super.key});

  @override
  State<ReceiverPage> createState() => _ReceiverPageState();
}

class _ReceiverPageState extends State<ReceiverPage> {
  final DeviceDiscovery _discovery = DeviceDiscovery();
  final FileTransferService _transferService = FileTransferService();
  List<DeviceInfo> _devices = [];
  bool _isScanning = false;
  TransferInfo? _transferInfo;

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  @override
  void dispose() {
    _discovery.stop();
    super.dispose();
  }

  Future<void> _startScanning() async {
    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    try {
      _discovery.startDiscovery((device) {
        setState(() {
          // 避免重复添加
          if (!_devices.any((d) => d.ip == device.ip && d.port == device.port)) {
            _devices.add(device);
          }
        });
      });
    } catch (e) {
      _showError('扫描设备失败: $e');
    } finally {
      // 模拟扫描过程
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
        }
      });
    }
  }

  Future<void> _downloadFile(DeviceInfo device) async {
    try {
      setState(() {
        _transferInfo = TransferInfo(
          fileName: '获取中...',
          fileSize: 0,
          status: TransferStatus.preparing,
        );
      });

      await _transferService.downloadFile(
        device: device,
        onProgress: (fileName, fileSize, progress) {
          setState(() {
            _transferInfo = TransferInfo(
              fileName: fileName,
              fileSize: fileSize,
              progress: progress,
              status: TransferStatus.transferring,
            );
          });
        },
        onComplete: (filePath) {
          setState(() {
            _transferInfo = _transferInfo?.copyWith(
              status: TransferStatus.completed,
              progress: 1.0,
            );
          });
          _showSuccess('文件已保存至: $filePath');
          
          // 如果是APK文件，提示安装
          if (filePath.endsWith('.apk') && Platform.isAndroid) {
            _showInstallDialog(filePath);
          }
        },
        onError: (error) {
          setState(() {
            _transferInfo = _transferInfo?.copyWith(
              status: TransferStatus.failed,
              errorMessage: error,
            );
          });
          _showError('下载失败: $error');
        },
      );
    } catch (e) {
      _showError('下载文件失败: $e');
    }
  }

  void _showInstallDialog(String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('APK文件已下载'),
        content: const Text('是否立即安装此APK文件？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _installApk(filePath);
            },
            child: const Text('安装'),
          ),
        ],
      ),
    );
  }

  Future<void> _installApk(String filePath) async {
    try {
      await _transferService.installApk(filePath);
      _showSuccess('正在打开安装程序...');
    } catch (e) {
      _showError('打开安装程序失败: $e');
    }
  }

  void _showQRScanner() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('扫描二维码'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(
              height: 400,
              width: 400,
              child: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      Navigator.pop(context);
                      _connectByUrl(barcode.rawValue!);
                      break;
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _connectByUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final device = DeviceInfo(
        name: '扫描的设备',
        ip: uri.host,
        port: uri.port,
        deviceType: 'unknown',
      );
      _downloadFile(device);
    } catch (e) {
      _showError('无效的二维码: $e');
    }
  }

  void _showManualInputDialog() {
    final ipController = TextEditingController();
    final portController = TextEditingController(text: '8080');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('手动输入地址'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'IP地址',
                hintText: '例如: 192.168.1.100',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: portController,
              decoration: const InputDecoration(
                labelText: '端口',
                hintText: '例如: 8080',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final ip = ipController.text.trim();
              final port = int.tryParse(portController.text.trim()) ?? 8080;
              
              if (ip.isEmpty) {
                _showError('请输入IP地址');
                return;
              }

              Navigator.pop(context);
              final device = DeviceInfo(
                name: '手动输入',
                ip: ip,
                port: port,
                deviceType: 'unknown',
              );
              _downloadFile(device);
            },
            child: const Text('连接'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('接收文件'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _showQRScanner,
            tooltip: '扫描二维码',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showManualInputDialog,
            tooltip: '手动输入',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _startScanning,
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          // 传输进度卡片
          if (_transferInfo != null) _buildTransferProgress(),

          // 设备列表
          Expanded(
            child: _buildDeviceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferProgress() {
    if (_transferInfo == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _transferInfo!.status == TransferStatus.completed
                      ? Icons.check_circle
                      : _transferInfo!.status == TransferStatus.failed
                          ? Icons.error
                          : Icons.download,
                  color: _transferInfo!.status == TransferStatus.completed
                      ? Colors.green
                      : _transferInfo!.status == TransferStatus.failed
                          ? Colors.red
                          : Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _transferInfo!.fileName,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _transferInfo!.fileSizeFormatted,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_transferInfo!.progressPercentage}%',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _transferInfo!.progress,
              backgroundColor: Colors.grey[300],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_isScanning && _devices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在扫描局域网设备...'),
          ],
        ),
      );
    }

    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_other,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '未发现设备',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '请确保发送端已启动服务',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _startScanning,
              icon: const Icon(Icons.refresh),
              label: const Text('重新扫描'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(_getDeviceIcon(device.deviceType)),
            ),
            title: Text(device.name),
            subtitle: Text('${device.ip}:${device.port}'),
            trailing: FilledButton.icon(
              onPressed: () => _downloadFile(device),
              icon: const Icon(Icons.download),
              label: const Text('接收'),
            ),
          ),
        );
      },
    );
  }

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'android':
        return Icons.android;
      case 'ios':
        return Icons.phone_iphone;
      case 'macos':
        return Icons.laptop_mac;
      case 'windows':
        return Icons.laptop_windows;
      case 'linux':
        return Icons.computer;
      default:
        return Icons.devices;
    }
  }
}

