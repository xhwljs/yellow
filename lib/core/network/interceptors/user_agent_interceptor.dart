import 'package:dio/dio.dart';
import 'package:videohub/core/utils/user_agent_utils.dart';

/// 随机 User-Agent 拦截器
///
/// 每次请求随机注入移动端 UA，规避反爬检测。
class UserAgentInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['User-Agent'] = UserAgentUtils.random();
    options.headers['Accept'] =
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
    options.headers['Accept-Language'] = 'zh-CN,zh;q=0.9,en;q=0.8';
    options.headers['Accept-Encoding'] = 'gzip, deflate';
    options.headers['Cache-Control'] = 'no-cache';
    options.headers['Pragma'] = 'no-cache';
    handler.next(options);
  }
}
