import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;

/// 带有ZeroTier认证的HTTP客户端
class AuthedDioClient {
  final String _authToken;
  final Dio _dio;
  
  /// 创建带有ZeroTier认证的HTTP客户端
  /// 
  /// [authToken] - ZeroTier认证令牌
  /// [baseUrl] - API基础URL
  AuthedDioClient(this._authToken, String baseUrl) : _dio = Dio(BaseOptions(
      baseUrl: 'http://$baseUrl',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    )) {
    
    // 添加拦截器以处理身份验证
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 添加ZeroTier特定认证头
        options.headers['X-ZT1-Auth'] = _authToken;
        return handler.next(options);
      },
    ));
  }
  
  /// 获取底层的Dio实例
  Dio get dio => _dio;
  
  /// 发送GET请求
  Future<Response> get(String path) {
    return _dio.get(path);
  }
  
  /// 发送POST请求
  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }
  
  /// 发送PUT请求
  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }
  
  /// 发送DELETE请求
  Future<Response> delete(String path) {
    return _dio.delete(path);
  }
  
  /// 关闭客户端
  void close() {
    _dio.close();
  }
}

/// ZeroTier认证服务，用于管理认证和客户端创建
class AuthService {
  static const String API_HOST = 'localhost:9993';
  
  /// 缓存的HTTP客户端实例
  AuthedDioClient? _cachedClient;
  
  /// 获取已认证的HTTP客户端
  Future<AuthedDioClient> get client async {
    // 如果我们已经有缓存的客户端，直接返回
    if (_cachedClient != null) {
      return _cachedClient!;
    }
    
    try {
      final authToken = await _loadAuthToken();
      _cachedClient = AuthedDioClient(authToken, API_HOST);
      return _cachedClient!;
    } catch (e) {
      developer.log('加载认证令牌失败', error: e.toString());
      rethrow;
    }
  }

  /// 清理资源
  void dispose() {
    if (_cachedClient != null) {
      _cachedClient!.close();
      _cachedClient = null;
    }
  }

  /// 加载认证令牌
  Future<String> _loadAuthToken() async {
    try {
      final path = (await getApplicationDocumentsDirectory()).path;
      final file = File('$path/run/authtoken');
      
      // 检查文件是否存在
      if (!await file.exists()) {
        throw FileSystemException('认证令牌文件未找到', file.path);
      }
      
      final token = await file.readAsString();
      return token.trim();
    } catch (e) {
      developer.log('读取认证令牌失败', error: e.toString());
      rethrow;
    }
  }
}

/// 超时异常类
class TimeoutException implements Exception {
  final String message;
  
  TimeoutException(this.message);
  
  @override
  String toString() => message;
} 