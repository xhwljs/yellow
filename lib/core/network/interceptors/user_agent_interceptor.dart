import 'package:dio/dio.dart';
import 'package:videohub/core/constants/api_endpoints.dart';
import 'package:videohub/core/utils/user_agent_utils.dart';

/// 随机 User-Agent + 反爬识别 Header 拦截器
///
/// 每次请求注入：
/// 1. 随机移动端 UA — 规避基于 UA 的频控
/// 2. `X-Requested-With: com.mmbox.xbrowser` — **关键反爬识别**
///    源站通过此 header 判定请求来自 X Browser 安卓应用，
///    缺失会被源站直接 connection reset（DioException connectionError）。
/// 3. `Referer: <base>` — 模拟从首页跳转
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
    options.headers['Accept-Language'] = 'zh-CN,zh-HK;q=0.9,zh;q=0.7,en;q=0.5';
    // 关键反爬识别：X Browser 应用包名
    options.headers['X-Requested-With'] = 'com.mmbox.xbrowser';
    // 模拟从首页跳转
    options.headers['Referer'] = ApiEndpoints.base;
    // 不设置 Accept-Encoding，让 Dio 自动注入并自动解压
    options.headers['Cache-Control'] = 'no-cache';
    options.headers['Pragma'] = 'no-cache';
    handler.next(options);
  }
}
