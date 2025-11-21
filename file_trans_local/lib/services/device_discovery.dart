import 'dart:io';
import 'dart:async';
import 'package:multicast_dns/multicast_dns.dart';
import '../models/device_info.dart';

class DeviceDiscovery {
  MDnsClient? _mdnsClient;
  bool _isScanning = false;
  Timer? _scanTimer;

  /// 开始发现设备
  void startDiscovery(Function(DeviceInfo) onDeviceFound) async {
    if (_isScanning) return;

    _isScanning = true;

    // 并行执行多种发现方式
    Future.wait([
      _scanWithMDns(onDeviceFound),
      _scanNetwork(onDeviceFound),
      _scanCommonIPs(onDeviceFound), // 新增：扫描常见IP
    ]).catchError((e) {
      print('设备发现错误: $e');
      return <void>[];
    });

    // 设置扫描超时（10秒）
    _scanTimer = Timer(const Duration(seconds: 10), () {
      stop();
    });
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

  /// 扫描本地网络
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

    // 扫描常见IP范围（更全面）
    final scanTargets = <int>[];
    
    // 添加常见的IP范围
    for (int i = 1; i <= 255; i++) {
      // 跳过当前设备IP
      if (i.toString() == parts[3]) continue;
      scanTargets.add(i);
    }

    // 并行扫描（每次30个，避免过载）
    for (int i = 0; i < scanTargets.length; i += 30) {
      final batch = scanTargets.skip(i).take(30);
      await Future.wait(
        batch.map((lastOctet) {
          final ip = '$subnet.$lastOctet';
          return _tryConnect(ip, port, onDeviceFound);
        }),
      );
      
      // 如果停止扫描，退出
      if (!_isScanning) break;
    }
  }

  /// 扫描常见IP（针对Mac电脑和手机的常见IP）
  Future<void> _scanCommonIPs(Function(DeviceInfo) onDeviceFound) async {
    // 获取本机IP来确定网段
    try {
      final interfaces = await NetworkInterface.list();
      String? subnet;
      
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
              break;
            }
          }
        }
        if (subnet != null) break;
      }

      if (subnet == null) return;

      final port = 8080;
      
      // Mac和手机通常使用的IP范围
      final commonRanges = [
        // 路由器分配的常见IP
        ...List.generate(20, (i) => i + 100), // 100-119
        ...List.generate(20, (i) => i + 1),   // 1-20
        ...List.generate(10, (i) => i + 200), // 200-209
      ];

      // 快速扫描这些常见IP
      await Future.wait(
        commonRanges.map((lastOctet) {
          final ip = '$subnet.$lastOctet';
          return _tryConnect(ip, port, onDeviceFound);
        }),
      );
    } catch (e) {
      print('常见IP扫描错误: $e');
    }
  }

  /// 尝试连接到设备
  Future<void> _tryConnect(
    String ip,
    int port,
    Function(DeviceInfo) onDeviceFound,
  ) async {
    if (!_isScanning) return;

    try {
      // 尝试HTTP连接而不是纯Socket
      final client = HttpClient();
      client.connectionTimeout = const Duration(milliseconds: 500);
      
      final request = await client.getUrl(Uri.parse('http://$ip:$port/'));
      final response = await request.close().timeout(
        const Duration(milliseconds: 500),
      );

      if (response.statusCode == 200) {
        // 连接成功，尝试获取设备信息
        final deviceInfo = DeviceInfo(
          name: '发现的设备 ($ip)',
          ip: ip,
          port: port,
          deviceType: 'unknown',
        );

        print('✅ 发现设备: $ip:$port');
        onDeviceFound(deviceInfo);
      }

      client.close();
    } catch (e) {
      // 连接失败，忽略（这是正常的）
    }
  }

  /// 停止发现
  void stop() {
    _isScanning = false;
    _scanTimer?.cancel();
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
