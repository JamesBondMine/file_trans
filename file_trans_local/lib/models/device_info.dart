/// 设备信息模型
class DeviceInfo {
  final String name;
  final String ip;
  final int port;
  final String deviceType; // 'android', 'ios', 'macos', 'windows', 'linux'

  DeviceInfo({
    required this.name,
    required this.ip,
    required this.port,
    required this.deviceType,
  });

  String get displayName => '$name ($deviceType)';
  
  String get address => 'http://$ip:$port';

  Map<String, dynamic> toJson() => {
        'name': name,
        'ip': ip,
        'port': port,
        'deviceType': deviceType,
      };

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        name: json['name'] as String,
        ip: json['ip'] as String,
        port: json['port'] as int,
        deviceType: json['deviceType'] as String,
      );
}

