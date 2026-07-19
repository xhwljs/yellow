import 'package:dio/dio.dart';
import 'package:videohub/core/utils/user_agent_utils.dart';

/// 随机 User-Agent 拦截器
///
/// 每次请求随机注入移动端 UA，规避反爬检测。
///
/// 重要：不手动设置 `Accept-Encoding`。
/// Dio 的 IOHttpClientAdapter 仅在它自己注入 `Accept-Encoding: gzip` 时
/// 才会自动解压响应。手动设置会导致 Dio 拿到 gzip 二进制却不解压，
/// 后续 String 解码失败，最终抛出 `connection error`。
class UserAgentInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['User-Agent'] = UserAgentUtils.random();
    options.headers['Accept'] =
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
    options.headers['Accept-Language'] = 'zh-CN,zh;q=0.9,en;q=0.8';
    // 不设置 Accept-Encoding，让 Dio 自动注入并自动解压
    options.headers['Cache-Control'] = 'no-cache';
    options.headers['Pragma'] = 'no-cache';
    handler.next(options);
  }
}
