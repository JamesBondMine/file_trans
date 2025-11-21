import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

class _ReceiverPageState extends State<ReceiverPage> with SingleTickerProviderStateMixin {
  final DeviceDiscovery _discovery = DeviceDiscovery();
  final FileTransferService _transferService = FileTransferService();
  List<DeviceInfo> _devices = [];
  bool _isScanning = false;
  TransferInfo? _transferInfo;
  late AnimationController _scanAnimationController;

  @override
  void initState() {
    super.initState();
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _startScanning();
    _checkLocalIP();
  }

  String? _localIP;

  Future<void> _checkLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            setState(() {
              _localIP = addr.address;
            });
            break;
          }
        }
        if (_localIP != null) break;
      }
    } catch (e) {
      print('获取本地IP失败: $e');
    }
  }

  @override
  void dispose() {
    _discovery.stop();
    _scanAnimationController.dispose();
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
          if (!_devices.any((d) => d.ip == device.ip && d.port == device.port)) {
            _devices.add(device);
          }
        });
      });
    } catch (e) {
      _showError('扫描设备失败: $e');
    } finally {
      // 增加扫描时间到10秒
      Future.delayed(const Duration(seconds: 10), () {
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

          final fileName = filePath.split('/').last;
          final isImage = _transferService.isImageFile(fileName);
          final isVideo = _transferService.isVideoFile(fileName);

          // 显示成功消息
          if (isImage || isVideo) {
            _showSuccess('✨ 文件已保存\n📁 位置: $filePath\n📱 已自动保存到相册');
          } else {
            _showSuccess('✨ 文件已保存至: $filePath');
          }

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('📦', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('APK文件已下载')),
          ],
        ),
        content: const Text('是否立即安装此APK文件？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _installApk(filePath);
            },
            icon: const Icon(Icons.install_mobile_rounded),
            label: const Text('立即安装'),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('扫描二维码'),
              automaticallyImplyLeading: false,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.edit_rounded, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            const Text('手动输入地址'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'IP地址',
                hintText: '例如: 192.168.1.100',
                prefixIcon: Icon(Icons.wifi_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: portController,
              decoration: const InputDecoration(
                labelText: '端口',
                hintText: '例如: 8080',
                prefixIcon: Icon(Icons.lan_rounded),
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
          FilledButton.icon(
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
            icon: const Icon(Icons.link_rounded),
            label: const Text('连接'),
          ),
        ],
      ),
    );
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                Icons.download_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('接收文件'),
                  if (_localIP != null)
                    Text(
                      '本机: $_localIP',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: _showQRScanner,
            tooltip: '扫描二维码',
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: _showManualInputDialog,
            tooltip: '手动输入',
          ),
          IconButton(
            icon: AnimatedBuilder(
              animation: _scanAnimationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _isScanning ? _scanAnimationController.value * 2 * 3.14159 : 0,
                  child: Icon(
                    Icons.refresh_rounded,
                    color: _isScanning ? Theme.of(context).colorScheme.primary : null,
                  ),
                );
              },
            ),
            onPressed: _isScanning ? null : _startScanning,
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          // 传输进度卡片
          if (_transferInfo != null)
            _buildTransferProgress()
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: -0.2, end: 0),

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

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (_transferInfo!.status) {
      case TransferStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        statusText = '完成';
        break;
      case TransferStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error_rounded;
        statusText = '失败';
        break;
      case TransferStatus.preparing:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty_rounded;
        statusText = '准备中';
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.downloading_rounded;
        statusText = '下载中';
    }

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.1),
            statusColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _transferInfo!.fileName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _transferInfo!.fileSizeFormatted,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '${_transferInfo!.progressPercentage}%',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _transferInfo!.progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_isScanning && _devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '正在扫描局域网设备...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '请确保发送端已启动服务',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '提示：也可以使用右上角的扫码或手动输入功能',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ).animate(onPlay: (controller) => controller.repeat()).shimmer(
              duration: 2000.ms,
              color: Colors.white.withOpacity(0.1),
            ),
      );
    }

    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.devices_other_rounded,
                size: 80,
                color: Colors.grey[400],
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(duration: 2000.ms, begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
            const SizedBox(height: 32),
            Text(
              '未发现设备',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              '请确保发送端已启动服务',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.amber[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '推荐连接方式：',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• 点击右上角 📷 扫描二维码（最快）\n• 点击右上角 ✏️ 手动输入IP地址（最可靠）\n\n💡 如果始终扫描不到设备，请确保:\n  - 两台设备连接同一WiFi\n  - 设备在同一网段（IP前3段相同）',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _startScanning,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新扫描'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.secondaryContainer,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(20),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getDeviceIcon(device.deviceType),
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(
              device.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(Icons.wifi_rounded, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${device.ip}:${device.port}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                        ),
                  ),
                ],
              ),
            ),
            trailing: FilledButton.icon(
              onPressed: () => _downloadFile(device),
              icon: const Icon(Icons.download_rounded),
              label: const Text('接收'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
        )
            .animate()
            .fadeIn(delay: (index * 100).ms, duration: 400.ms)
            .slideX(begin: 0.2, end: 0);
      },
    );
  }

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'android':
        return Icons.android_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      case 'macos':
        return Icons.laptop_mac_rounded;
      case 'windows':
        return Icons.laptop_windows_rounded;
      case 'linux':
        return Icons.computer_rounded;
      default:
        return Icons.devices_rounded;
    }
  }
}
