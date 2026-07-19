import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:videohub/core/constants/app_constants.dart';
import 'package:videohub/core/network/interceptors/cookie_interceptor.dart';
import 'package:videohub/core/network/interceptors/error_interceptor.dart';
import 'package:videohub/core/network/interceptors/logging_interceptor.dart';
import 'package:videohub/core/network/interceptors/retry_interceptor.dart';
import 'package:videohub/core/network/interceptors/user_agent_interceptor.dart';

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
        connectTimeout: const Duration(milliseconds: AppConstants.connectTimeoutMs),
        receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeoutMs),
        sendTimeout: const Duration(milliseconds: AppConstants.sendTimeoutMs),
        responseType: ResponseType.plain, // 返回原始字符串用于 HTML 解析
        followRedirects: true,
        maxRedirects: 5,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );

    // 拦截器顺序：UA → Cookie → Log → Retry → Error
    dio.interceptors.addAll([
      UserAgentInterceptor(),
      cookieInterceptor,
      LoggingInterceptor(),
      RetryInterceptor(),
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

  /// 仅用于测试或重置
  static void resetForTesting() {
    _instance = null;
  }
}
