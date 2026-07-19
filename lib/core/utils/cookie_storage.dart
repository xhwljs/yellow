import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cookie 持久化存储
///
/// 实现 PersistCookieJar 的存储适配，将 Cookie 持久化到 SharedPreferences
/// 用于全局自动持久化处理 Cookie 和 Session 会话。
class CookieStorage implements Storage {
  static const String _keyPrefix = 'cookie_';
  final SharedPreferences _prefs;

  CookieStorage(this._prefs);

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {
    // No-op: SharedPreferences 已初始化
  }

  @override
  Future<String?> read(String key) async {
    return _prefs.getString('$_keyPrefix$key');
  }

  @override
  Future<void> write(String key, String value) async {
    await _prefs.setString('$_keyPrefix$key', value);
  }

  @override
  Future<void> delete(String key) async {
    await _prefs.remove('$_keyPrefix$key');
  }

  @override
  Future<void> clear() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }
}

/// 单例 CookieJar 工厂
class CookieStorageFactory {
  static PersistCookieJar? _instance;

  static Future<PersistCookieJar> getInstance() async {
    if (_instance != null) return _instance!;
    final prefs = await SharedPreferences.getInstance();
    _instance = PersistCookieJar(
      storage: CookieStorage(prefs),
      ignoreExpires: false,
    );
    return _instance!;
  }

  /// 强制清理所有 Cookie（登出场景）
  static Future<void> clearAll() async {
    final jar = await getInstance();
    await jar.deleteAll();
  }
}
