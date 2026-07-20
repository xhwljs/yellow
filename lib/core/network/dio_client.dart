import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:yellow_depot/core/constants/app_constants.dart';
import 'package:yellow_depot/core/network/interceptors/cookie_interceptor.dart';
import 'package:yellow_depot/core/network/interceptors/error_interceptor.dart';
import 'package:yellow_depot/core/network/interceptors/logging_interceptor.dart';
import 'package:yellow_depot/core/network/interceptors/retry_interceptor.dart';
import 'package:yellow_depot/core/network/interceptors/user_agent_interceptor.dart';

/// Dio 客户端单例
///
/// 严格遵循需求：
/// - 设置移动端随机 User-Agent
/// - 全局自动持久化处理 Cookie 和 Session 会话
/// - 支持网络失败重试机制（3 次，间隔 2s）
/// - 全局超时设置: 30 秒
/// - 统一请求拦截、异常封装、日志打印
class DioClient {
  static Dio? _instance;

  /// 同步获取 Dio（仅可在 ensureInitialized 之后调用）
  static Dio get instance {
    final dio = _instance;
    if (dio == null) {
      throw StateError('DioClient 尚未初始化，请先调用 DioClient.ensureInitialized()');
    }
    return dio;
  }

  /// 异步初始化 Dio 实例，注入所有拦截器
  static Future<Dio> ensureInitialized() async {
    if (_instance != null) return _instance!;

    final cookieInterceptor = await CookieInterceptor.create();

    final dio = Dio(
      BaseOptions(
        connectTimeout:
            const Duration(milliseconds: AppConstants.connectTimeoutMs),
        receiveTimeout:
            const Duration(milliseconds: AppConstants.receiveTimeoutMs),
        sendTimeout: const Duration(milliseconds: AppConstants.sendTimeoutMs),
        responseType: ResponseType.plain, // 返回原始字符串用于 HTML 解析
        followRedirects: true,
        maxRedirects: 5,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );

    // 关键：使用 IOHttpClientAdapter 并显式启用自动解压
    // （Dio 5.x 默认不自动解压 gzip，必须显式开启）
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient()
          // 自动解压 gzip/deflate（重要：否则收到压缩二进制无法解析）
          ..autoUncompress = true
          // 清空 Dio 默认 UA（由 UserAgentInterceptor 注入随机移动 UA）
          ..userAgent = null;
        return client;
      },
      // 容错源站证书链路问题（Let's Encrypt 等偶发校验失败）
      validateCertificate: (cert, host, port) => true,
    );

    // 拦截器顺序：UA → Cookie → Log → Retry → Error
    dio.interceptors.addAll([
      UserAgentInterceptor(),
      cookieInterceptor,
      LoggingInterceptor(),
      // dioProvider 回调到 _instance 而非闭包变量 dio，
      // 这样 baseUrl 切换重建后，重试会自动用最新 Dio 而非已关闭的旧 Dio。
      RetryInterceptor(dioProvider: () => _instance ?? dio),
      ErrorInterceptor(),
    ]);

    _instance = dio;
    return dio;
  }

  /// 清理所有 Cookie（登出场景）
  static Future<void> clearCookies() async {
    final jar = await cookieInterceptorJar();
    await jar.deleteAll();
  }

  static Future<CookieJar> cookieInterceptorJar() async {
    final interceptor = (await CookieInterceptor.create());
    return interceptor.cookieJar;
  }

  /// 重建 Dio 实例（切换 baseUrl 后调用）
  ///
  /// 保留所有拦截器配置，仅关闭旧 Dio、创建新 Dio、重新注入拦截器。
  /// 调用前需先更新 [AppConstants.baseUrl]。
  static Future<Dio> rebuildWithBaseUrl(String newBaseUrl) async {
    // 关闭旧 Dio
    _instance?.close();

    // 重新创建（沿用 ensureInitialized 的所有配置）
    final cookieInterceptor = await CookieInterceptor.create();

    final dio = Dio(
      BaseOptions(
        baseUrl: newBaseUrl,
        connectTimeout:
            const Duration(milliseconds: AppConstants.connectTimeoutMs),
        receiveTimeout:
            const Duration(milliseconds: AppConstants.receiveTimeoutMs),
        sendTimeout: const Duration(milliseconds: AppConstants.sendTimeoutMs),
        responseType: ResponseType.plain,
        followRedirects: true,
        maxRedirects: 5,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient()
          ..autoUncompress = true
          ..userAgent = null;
        return client;
      },
      validateCertificate: (cert, host, port) => true,
    );

    dio.interceptors.addAll([
      UserAgentInterceptor(),
      cookieInterceptor,
      LoggingInterceptor(),
      RetryInterceptor(dioProvider: () => _instance ?? dio),
      ErrorInterceptor(),
    ]);

    _instance = dio;
    return dio;
  }

  /// 仅用于测试或重置
  static void resetForTesting() {
    _instance = null;
  }
}
