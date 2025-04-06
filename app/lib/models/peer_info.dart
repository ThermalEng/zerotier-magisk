import 'dart:math'; // For min function

class PeerInfo implements Comparable<PeerInfo> {
  final String address;
  final int latency;
  final String? version;
  final String role;
  final String? preferredPath;
  final bool isPlanet;
  final bool tunneled; // 是否通过中继

  PeerInfo({
    required this.address,
    required this.latency,
    this.version,
    required this.role,
    this.preferredPath,
    required this.tunneled,
  }) : isPlanet = (role == 'PLANET');

  factory PeerInfo.fromJson(Map<String, dynamic> json) {
    String? bestPath;
    List<dynamic> paths = json['paths'] as List<dynamic>? ?? [];

    // Find the preferred active path
    var preferred = paths.firstWhere(
        (p) =>
            p is Map<String, dynamic> &&
            p['active'] == true &&
            p['expired'] == false &&
            p['preferred'] == true,
        orElse: () => null);

    if (preferred != null) {
      bestPath = preferred['address'] as String?;
    } else {
      // If no preferred, find the first active path
      var firstActive = paths.firstWhere(
          (p) =>
              p is Map<String, dynamic> &&
              p['active'] == true &&
              p['expired'] == false,
          orElse: () => null);
      if (firstActive != null) {
        bestPath = firstActive['address'] as String?;
      }
    }

    return PeerInfo(
      address: json['address'] as String? ?? 'Unknown',
      latency: json['latency'] as int,
      version: json['version'] as String?,
      role: json['role'] as String? ?? 'UNKNOWN',
      preferredPath: bestPath,
      tunneled: json['tunneled'] as bool,
    );
  }

  // Comparison logic for sorting: PLANETs first, then by tunneled (直连优先), then by latency
  @override
  int compareTo(PeerInfo other) {
    if (isPlanet != other.isPlanet) {
      return isPlanet ? 1 : -1;
    }
    
    if (tunneled != other.tunneled) {
      return tunneled ? -1 : 1; 
    }
    
    // 最后按延迟排序（如果有的话）
    if (latency != null && other.latency != null) {
      return latency!.compareTo(other.latency!);
    } else if (latency != null) {
      return -1; // 有延迟信息的优先
    } else if (other.latency != null) {
      return 1;
    }
    
    // 如果都没有延迟信息，按地址排序
    return address.compareTo(other.address);
  }
} 