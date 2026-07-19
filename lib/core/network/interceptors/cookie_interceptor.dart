import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:videohub/core/utils/cookie_storage.dart';

/// Cookie 持久化拦截器
///
/// 全局自动持久化处理 Cookie 和 Session 会话。
/// 委托给 dio_cookie_manager.CookieManager（基于 cookie_jar）。
class CookieInterceptor extends CookieManager {
  CookieInterceptor._(super.jar);

  static Future<CookieInterceptor> create() async {
    final jar = await CookieStorageFactory.getInstance();
    return CookieInterceptor._(jar);
  }
}
