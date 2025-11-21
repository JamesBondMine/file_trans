import 'dart:io';
import 'package:multicast_dns/multicast_dns.dart';
import '../models/device_info.dart';

class DeviceDiscovery {
  MDnsClient? _mdnsClient;
  bool _isScanning = false;

  /// 开始发现设备
  void startDiscovery(Function(DeviceInfo) onDeviceFound) async {
    if (_isScanning) return;

    _isScanning = true;

    try {
      // 使用 mDNS 扫描
      await _scanWithMDns(onDeviceFound);

      // 同时使用网络扫描（备用方案）
      await _scanNetwork(onDeviceFound);
    } catch (e) {
      print('设备发现错误: $e');
    }
  }

  /// 使用 mDNS 扫描设备
  Future<void> _scanWithMDns(Function(DeviceInfo) onDeviceFound) async {
    try {
      _mdnsClient = MDnsClient();
      await _mdnsClient!.start();

      // 查询自定义服务类型
      await for (final PtrResourceRecord ptr in _mdnsClient!
          .lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer('_file-transfer._tcp'),
      )) {
        print('发现 mDNS 设备: ${ptr.domainName}');
        // 这里可以进一步解析设备信息
      }
    } catch (e) {
      print('mDNS 扫描错误: $e');
    } finally {
      _mdnsClient?.stop();
    }
  }

  /// 扫描本地网络（简单实现）
  Future<void> _scanNetwork(Function(DeviceInfo) onDeviceFound) async {
    try {
      // 获取本机 IP
      final interfaces = await NetworkInterface.list();
      
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            // 扫描同一网段
            await _scanSubnet(addr.address, onDeviceFound);
          }
        }
      }
    } catch (e) {
      print('网络扫描错误: $e');
    }
  }

  /// 扫描子网
  Future<void> _scanSubnet(String localIP, Function(DeviceInfo) onDeviceFound) async {
    final parts = localIP.split('.');
    if (parts.length != 4) return;

    final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
    final port = 8080; // 默认端口

    // 扫描网段（为了演示，只扫描部分IP）
    final scanTargets = [
      1, 2, 100, 101, 102, 103, 104, 105, // 常见的IP范围
    ];

    for (final lastOctet in scanTargets) {
      final ip = '$subnet.$lastOctet';
      
      if (ip == localIP) continue; // 跳过本机

      // 尝试连接
      _tryConnect(ip, port, onDeviceFound);
    }
  }

  /// 尝试连接到设备
  Future<void> _tryConnect(
    String ip,
    int port,
    Function(DeviceInfo) onDeviceFound,
  ) async {
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(milliseconds: 500),
      );
      
      socket.destroy();

      // 连接成功，添加设备
      final device = DeviceInfo(
        name: '设备 ($ip)',
        ip: ip,
        port: port,
        deviceType: 'unknown',
      );

      onDeviceFound(device);
    } catch (e) {
      // 连接失败，忽略
    }
  }

  /// 停止发现
  void stop() {
    _isScanning = false;
    _mdnsClient?.stop();
  }

  /// 注册 mDNS 服务（发送端使用）
  Future<void> registerService({
    required String serviceName,
    required int port,
  }) async {
    try {
      _mdnsClient = MDnsClient();
      await _mdnsClient!.start();

      // 这里应该注册服务，但由于 multicast_dns 包的限制，
      // 实际注册可能需要更复杂的实现
      print('注册 mDNS 服务: $serviceName on port $port');
    } catch (e) {
      print('注册服务错误: $e');
    }
  }

  /// 取消注册服务
  Future<void> unregisterService() async {
    _mdnsClient?.stop();
  }
}

