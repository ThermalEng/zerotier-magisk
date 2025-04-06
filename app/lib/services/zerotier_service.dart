import 'dart:io';
import 'dart:developer' as developer;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'auth_service.dart';
import '../models/peer_info.dart';

/// ZeroTier服务状态详情
class ZerotierStatus {
  final String address;
  final String version;
  final bool online;
  final int primaryPort;
  final List<String> listeningOn;

  ZerotierStatus({ 
    required this.address,
    required this.version,
    required this.online,
    required this.primaryPort,
    required this.listeningOn,
  });
  
  /// 从JSON创建状态对象
  factory ZerotierStatus.fromJson(Map<String, dynamic> json) {
    // 提取监听地址列表
    List<String> listeningAddresses = [];
    if (json['config'] != null && 
        json['config']['settings'] != null && 
        json['config']['settings']['listeningOn'] != null) {
      listeningAddresses = List<String>.from(json['config']['settings']['listeningOn']);
    }
    
    // 提取主端口
    int port = 0;
    if (json['config'] != null && 
        json['config']['settings'] != null && 
        json['config']['settings']['primaryPort'] != null) {
      port = json['config']['settings']['primaryPort'];
    }
    
    return ZerotierStatus(
      address: json['address'] ?? '',
      version: json['version'] ?? '',
      online: json['online'] ?? false,
      primaryPort: port,
      listeningOn: listeningAddresses,
    );
  }
}

/// ZeroTier服务，提供所有ZeroTier相关功能
class ZerotierService {  
  final AuthService _authService = AuthService();
  
  // 内部成员变量，存储最后一次加载的数据
  List<String> _networkList = [];
  List<PeerInfo> _peersList = [];
  ZerotierStatus? _statusInfo;
  
  // 表示ZeroTier服务是否正在运行
  bool runningStatus = false;
  
  // 允许外部访问最新数据的getter方法
  List<String> get networkList => _networkList;
  List<PeerInfo> get peersList => _peersList;
  ZerotierStatus? get statusInfo => _statusInfo;

  /// 向ZeroTier服务发送命令
  Future<bool> zerotierCommand(String command) async {
    try {
      final path = (await getApplicationDocumentsDirectory()).path;
      final file = File('$path/run/pipe');
      
      if (!await file.exists()) {
        developer.log('未找到ZeroTier命令管道: ${file.path}');
        runningStatus = false;
        // 特定错误，表示Magisk模块未运行
        throw const FileSystemException('MODULE_NOT_RUNNING');
      }
      
      await file.writeAsString(command);
      developer.log('已发送ZeroTier命令: $command');
      return true;
    } on FileSystemException catch (e) {
      if (e.message == 'MODULE_NOT_RUNNING') {
        developer.log('ZeroTier Magisk模块未运行');
      } else {
        developer.log('未找到ZeroTier命令管道，服务可能未运行');
      }
      runningStatus = false;
      return false;
    } catch (e) {
      developer.log('发送ZeroTier命令失败', error: e.toString());
      return false;
    }
  }

  /// 加载网络列表
  Future<List<String>?> loadNetwork() async {
    developer.log('开始加载网络列表');
    try {
      final client = await _authService.client;
      // 使用相对路径，基础URL已在客户端中配置
      final resp = await client.get('/network');
      
      if (resp.statusCode != 200) {
        throw HttpException('加载网络列表失败: ${resp.statusCode}');
      }
      
      final body = resp.data;
      _networkList = List<String>.from(body.map((u) => u['id']));
      developer.log('成功加载网络列表: ${_networkList.length} 个网络');
      return _networkList;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        developer.log('无法连接到ZeroTier服务：服务可能未运行');
      } else {
        developer.log('加载网络列表失败', error: e.toString());
      }
      _networkList = [];
      return null;
    } on SocketException {
      developer.log('无法连接到ZeroTier服务：服务可能未运行');
      _networkList = [];
      return null;
    } catch (e) {
      developer.log('加载网络列表失败', error: e.toString());
      _networkList = [];
      return null;
    }
  }

  /// 离开指定网络
  Future<bool> leaveNetwork(String id) async {
    try {
      final client = await _authService.client;
      // 使用相对路径
      final resp = await client.delete('/network/$id');
      final success = resp.statusCode == 200;
      
      if (success) {
        developer.log('成功离开网络: $id');
      } else {
        developer.log('离开网络失败: $id, 状态码: ${resp.statusCode}');
      }
      
      return success;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        developer.log('无法连接到ZeroTier服务：服务可能未运行');
        // 更新运行状态
        runningStatus = false;
      } else {
        developer.log('离开网络错误', error: e.toString());
      }
      return false;
    } on SocketException {
      developer.log('无法连接到ZeroTier服务：服务可能未运行');
      // 更新运行状态
      runningStatus = false;
      return false;
    } catch (e) {
      developer.log('离开网络错误', error: e.toString());
      return false;
    }
  }

  /// 加入指定网络
  Future<bool> joinNetwork(String id) async {
    try {
      if (id.isEmpty) {
        developer.log('无法加入空网络ID');
        return false;
      }
      
      final client = await _authService.client;
      // 使用相对路径
      final resp = await client.put('/network/$id');
      final success = resp.statusCode == 200;
      
      if (success) {
        developer.log('成功加入网络: $id');
      } else {
        developer.log('加入网络失败: $id, 状态码: ${resp.statusCode}');
      }
      
      return success;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        developer.log('无法连接到ZeroTier服务：服务可能未运行');
        // 更新运行状态
        runningStatus = false;
      } else {
        developer.log('加入网络错误', error: e.toString());
      }
      return false;
    } on SocketException {
      developer.log('无法连接到ZeroTier服务：服务可能未运行');
      // 更新运行状态
      runningStatus = false;
      return false;
    } catch (e) {
      developer.log('加入网络错误', error: e.toString());
      return false;
    }
  }

  /// 加载 Peer 列表
  Future<List<PeerInfo>?> loadPeers() async {
    developer.log('开始加载 Peer 列表');
    try {
      final client = await _authService.client;
      final resp = await client.get('/peer');

      if (resp.statusCode != 200) {
        throw HttpException('加载 Peer 列表失败: ${resp.statusCode}');
      }

      final List<dynamic> rawPeers = resp.data;
      _peersList = rawPeers
          .map((p) => PeerInfo.fromJson(p as Map<String, dynamic>))
          .toList();

      // Sort the list (PLANETs first, then LEAFs by address)
      _peersList.sort();

      developer.log('成功加载 Peer 列表: ${_peersList.length} 个 Peers');
      return _peersList;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        developer.log('无法连接到ZeroTier服务：服务可能未运行');
      } else {
        developer.log('加载 Peer 列表 Dio 错误', error: e.toString(), stackTrace: e.stackTrace);
      }
      _peersList = [];
      return null;
    } on SocketException {
      developer.log('无法连接到ZeroTier服务：服务可能未运行');
      _peersList = [];
      return null;
    } catch (e, s) {
      developer.log('加载 Peer 列表失败', error: e.toString(), stackTrace: s);
      _peersList = [];
      return null;
    }
  }

  /// 加载ZeroTier服务状态
  Future<ZerotierStatus?> loadStatus() async {
    developer.log('检查ZeroTier服务状态');
    Map<String, dynamic>? statusData;

    try {
      // 尝试获取状态信息
      final client = await _authService.client;
      final response = await client.get('/status');
      
      if (response.statusCode == 200) {
        statusData = response.data;
        developer.log('已获取ZeroTier状态信息');
      } else {
        developer.log('获取ZeroTier状态信息失败: ${response.statusCode}');
        statusData = null;
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        developer.log('无法连接到ZeroTier服务：服务可能未运行');
      } else {
        developer.log('获取ZeroTier状态信息错误', error: e.toString());
      }
      statusData = null;
    } on SocketException {
      developer.log('无法连接到ZeroTier服务：服务可能未运行');
      statusData = null;
    } catch (e) {
      developer.log('检查ZeroTier状态错误', error: e.toString());
      statusData = null;
    }

    // 根据获取的状态信息更新运行状态和详情
    if (statusData != null) {
      runningStatus = true;
      _statusInfo = ZerotierStatus.fromJson(statusData);
      developer.log('ZeroTier服务状态: 运行中');
      developer.log('已加载ZeroTier详细状态信息');
      return _statusInfo;
    } else {
      runningStatus = false;
      _statusInfo = null;
      developer.log('ZeroTier服务状态: 未运行');
      return null;
    }
  }

  /// 释放资源
  void dispose() {
    _authService.dispose();
  }
} 