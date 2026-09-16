# Yellow Depot

> Flutter 视频聚合 App — UI/UX-Pro-Max 设计系统驱动
>
> 适配 macCMS V10 + stui 主题源站，含域名动态迁移、播放地址解密、HTML 解析、反爬应对、GitHub Releases 自动更新。

---

## 目录

- [项目简介](#项目简介)
- [核心特性](#核心特性)
- [技术栈](#技术栈)
- [项目结构](#项目结构)
- [架构设计](#架构设计)
- [核心机制详解](#核心机制详解)
  - [启动流程](#启动流程)
  - [域名管理与跳转壳自动迁移](#域名管理与跳转壳自动迁移)
  - [播放地址解密](#播放地址解密)
  - [HTML 解析层](#html-解析层)
  - [反爬应对策略](#反爬应对策略)
  - [主题与设计系统](#主题与设计系统)
  - [自动更新机制](#自动更新机制)
- [页面与功能](#页面与功能)
- [构建与发布](#构建与发布)
- [本地开发](#本地开发)
- [常见问题](#常见问题)

---

## 项目简介

**Yellow Depot** 是一款基于 Flutter 的视频聚合 App，针对采用 macCMS V10 + stui 主题模板的源站设计。源站域名因反爬频繁更换，App 内置了一套完整的域名动态迁移、跳转壳自动解析、播放地址解密与反爬应对机制，保证在源站频繁变动下仍能持续可用。

- **应用名**：Yellow Depot（`AppConstants.appName`）
- **包名**：`yellow_depot`
- **目标平台**：Android（arm64-v8a）
- **最低 Flutter**：3.13.0（实测推荐 3.24.0）
- **最低 Dart SDK**：3.0.0

---

## 核心特性

### 网络与数据

- **域名动态迁移**：检测当前 baseUrl 是否变成"跳转壳"，自动通过跳转服务解析最新真实地址并切换
- **镜像列表管理**：支持手动添加 / 编辑 / 删除 / 重置镜像，当前生效域名受保护（不可删但可编辑）
- **播放地址解密**：从详情页 HTML 提取 token，POST `/static/count.php` 解密播放地址，含 3 次重试
- **HTML 解析**：基于 `package:html` 解析 stui 主题 DOM，复用列表页 / 详情页 / 相关推荐解析逻辑
- **反爬应对**：UA 轮换、Cookie 持久化、418 重试、证书容错、请求间隔限制

### 数据持久化

- **Floor 数据库**（Room 的 Flutter 适配版）：分类、视频、收藏、历史
- **SharedPreferences**：baseUrl、主题、搜索历史、镜像列表
- **数据备份迁移**：收藏 + 历史 JSON 导入导出，支持卸载重装 / 换机迁移

### 体验与设计

- **5 套预设主题 + 自定义色**：热情粉 / 资讯红 / 专业蓝 / 创意紫 / 活力橙 + HSV 选色盘
- **设计令牌驱动**：所有页面不硬编码 hex / 像素，统一从 `DesignTokens` 取值
- **卡片化 UI**：MD3 扁平卡片 + 圆角 + 阴影，与首页 / 收藏 / 历史统一视觉语言
- **卷帘菜单**：主题色 / API 服务器 / 关于 等选择类操作统一用 `showModalBottomSheet`
- **屏幕常亮**：前台时一直保持，避免播放页生命周期管理导致 wakelock 失效

### 自动更新

- **GitHub Releases 驱动**：CI 构建 APK 并发 Release，App 启动时检查 latest release
- **强制更新**：Release body 含 `[强制更新]` 标记时，对话框仅显示"立即更新"
- **多源检查 + 国内可用**：api.github.com 直连失败（DNS 污染 / 403 限流）时自动切换 gh-proxy.com 镜像，最后兜底 github.com 页面 302 解析；APK 下载同样镜像优先 + 直连兜底

---

## 技术栈

| 类别 | 依赖 | 版本 | 用途 |
|---|---|---|---|
| 状态管理 / 路由 / DI | `get` | ^4.6.6 | GetX 全家桶 |
| 网络层 | `dio` | ^5.4.3+1 | HTTP 客户端 |
| Cookie | `cookie_jar` / `dio_cookie_manager` | ^4.0.8 / ^3.1.1 | Cookie 持久化 |
| HTML 解析 | `html` | ^0.15.4 | Dart Jsoup 等价物 |
| 数据库 | `floor` | ^1.4.2 | Room 适配版 ORM |
| 播放器 | `video_player` / `chewie` | ^2.8.6 / ^1.8.1 | 视频播放 |
| 屏幕常亮 | `wakelock_plus` | ^1.2.4 | 播放时保持屏幕常亮 |
| UI | `google_fonts` / `phosphor_flutter` / `cached_network_image` / `shimmer` | - | 字体 / 图标 / 图片缓存 / 骨架屏 |
| 日志 | `logger` | ^2.3.0 | 分级日志 |
| 数据迁移 | `share_plus` / `file_picker` | ^10.0.0 / ^8.0.0 | 分享备份 / 选 JSON |
| 自动更新 | `open_file` / `permission_handler` | ^3.5.4 / ^11.3.1 | 安装 APK / 权限申请 |

---

## 项目结构

```
lib/
├── main.dart                      # 入口：HttpOverrides + Wakelock + Splash
├── core/
│   ├── constants/
│   │   ├── app_constants.dart     # App 名 / 版本 / baseUrl / SP keys
│   │   └── api_endpoints.dart     # 详情页 / 搜索 / 解密 POST 端点
│   ├── error/
│   │   └── exceptions.dart        # UrlExpiredException 等自定义异常
│   ├── network/
│   │   ├── dio_client.dart        # Dio 配置 + 拦截器链路 + 证书容错
│   │   ├── api_service.dart        # fetchVideoListHtml / fetchVideoDetailHtml
│   │   ├── api_server_switcher.dart  # 域名切换 + 跳转壳自动迁移 + 镜像管理
│   │   └── interceptors/
│   │       ├── user_agent_interceptor.dart  # 随机移动 UA
│   │       ├── cookie_interceptor.dart      # Cookie 注入 + 持久化
│   │       ├── retry_interceptor.dart       # 418 / 超时重试 + UA 切换
│   │       ├── error_interceptor.dart       # badCertificate / 网络错误分支
│   │       └── logging_interceptor.dart     # 请求 / 响应日志
│   ├── parser/
│   │   ├── category_parser.dart     # 首页"目录"区块 .stui-pannel__menu
│   │   ├── video_list_parser.dart   # 列表页 .stui-vodlist__box + .sub 字段
│   │   └── video_detail_parser.dart # 详情页 + 相关推荐（复用列表解析）
│   ├── player/
│   │   └── url_decryptor.dart      # token 提取 + count.php POST + 解密 + 重试
│   ├── services/
│   │   ├── github_release_service.dart  # latest release 多源检查（直连 / 镜像 / 302 兜底）
│   │   ├── app_update_service.dart     # APK 下载 + 安装
│   │   └── data_export_service.dart   # 收藏 / 历史 JSON 导入导出
│   ├── theme/
│   │   ├── design_tokens.dart      # spacing / radius / typography / motion
│   │   ├── theme_presets.dart      # 5 预设 + custom 枚举
│   │   ├── theme_controller.dart   # Rx 主题状态 + SharedPreferences 持久化
│   │   └── app_theme.dart         # ThemeData 构建 + ThemeColors 语义令牌
│   └── utils/
│       ├── logger.dart             # appLogger 单例
│       ├── cookie_storage.dart     # PersistCookieJar 持久化
│       ├── user_agent_utils.dart   # 随机 UA 池
│       └── number_formatter.dart   # 播放量 1.1w 等格式化
├── data/
│   ├── database/
│   │   ├── app_database.dart      # @Database base class
│   │   └── dao/                   # category / favorite / history / video
│   ├── models/                    # @entity 实体 + VideoDetail 运行时模型
│   ├── repositories/              # Repository 模式封装 DAO + API
│   └── services/
│       └── search_history_service.dart
└── presentation/
    ├── bindings/                  # AppBinding + 页级 Bindings
    ├── controllers/               # GetxController（home/favorites/history/...）
    ├── pages/
    │   ├── splash/splash_page.dart    # 启动页：初始化 + 更新检查
    │   ├── main_shell.dart            # GetMaterialApp + 4 Tab BottomNav
    │   ├── home/                      # 首页：分类目录卷帘 + 视频网格
    │   ├── category/                  # 分类详情列表
    │   ├── search/                    # 搜索页 + 搜索历史
    │   ├── detail/                    # 详情：SliverAppBar 内嵌播放 + 相关推荐
    │   ├── favorites/                 # 收藏列表（GridView + VideoCard）
    │   ├── history/                   # 历史记录（ListView + 缩略图）
    │   └── settings/                  # 设置：主题 / API 服务器 / 数据 / 关于
    ├── routes/app_pages.dart      # GetPage 路由表
    └── widgets/
        ├── video_card.dart        # 视频卡片（封面 + 标题 + 播放量 + 收藏数）
        ├── update_dialog.dart     # 强制 / 非强制更新对话框
        └── back_press_exit_wrapper.dart  # 双击退出
```

---

## 架构设计

整体采用 **分层 + GetX** 架构：

```
┌──────────────────────────────────────────────────────────┐
│  Presentation Layer（pages / controllers / widgets）     │
│   - GetxController 持有 Rx 状态，Obx 自动 rebuild          │
│   - GetView<T> + tag 区分同名路由的多 controller 实例      │
└────────────────────────┬─────────────────────────────────┘
                         │ Get.find<Repository>()
┌────────────────────────▼─────────────────────────────────┐
│  Data Layer（repositories / models / database）          │
│   - Repository 模式：DAO（本地）+ ApiService（远程）       │
│   - Floor @entity 持久化，VideoDetail 运行时构造           │
└────────────────────────┬─────────────────────────────────┘
                         │
┌────────────────────────▼─────────────────────────────────┐
│  Core Layer（network / parser / player / services）       │
│   - DioClient + 拦截器链路（UA → Cookie → Log → Retry）   │
│   - ApiServerSwitcher：域名切换 + 跳转壳迁移               │
│   - *Parser：HTML DOM 解析（不走 macCMS JSON API）         │
│   - UrlDecryptor：播放地址解密                            │
│   - GitHubReleaseService：更新检查                        │
└──────────────────────────────────────────────────────────┘
```

### 为什么用 HTML 解析而非 macCMS JSON API？

源站关闭了 `/api.php/provide/vod` 接口，且首页 / 详情页返回的就是 stui 主题 HTML。项目直接复用页面 HTML 解析，避免维护两套数据源。`api.php/provide` 字符串仅作为 `ApiServerSwitcher` 检测"是否是 macCMS 站点"的 marker。

---

## 核心机制详解

### 启动流程

```
main()
  ├─ WidgetsFlutterBinding.ensureInitialized()
  ├─ HttpOverrides.global = _BadCertHttpOverrides()   # 全局绕过证书校验
  ├─ WakelockPlus.enable()                            # 屏幕常亮
  └─ runApp(SplashPage())
       └─ SplashPage.initState()
            ├─ initializeApp()                         # DB / Dio / 主题 / 域名加载
            ├─ GitHubReleaseService.checkForUpdate()  # 检查更新（多源：直连/镜像/302 兜底）
            ├─ Future.delayed(2s)                      # 最小展示时长
            └─ 分支（更新优先）
                 ├─ 有新版本 → 不获取域名，直接弹 UpdateDialog
                 │    ├─ forceUpdate=true → 仅"立即更新"，不进入旧版本
                 │    └─ forceUpdate=false → "立即更新 / 稍后"
                 │         └─ 点"稍后" → 获取最新域名 → 进入 App
                 └─ 无新版本 → 获取最新域名
                      ├─ 显示"正在获取新域名"            # 获取中
                      ├─ 成功 → 提示成功及新域名         # 镜像列表精简为 [根域名, 新域名]
                      ├─ 失败 → 提示失败后继续           # 不阻塞进入 App
                      └─ MainShell（4 Tab）
```

详见 [main.dart](lib/main.dart) 与 [splash_page.dart](lib/presentation/pages/splash/splash_page.dart)。

### 域名管理与跳转壳自动迁移

源站老入口（如 `555973.xyz`）实际是"跳转壳"——返回 200 + ~425 字节 HTML，含 `var strU = "https://hk234.space:8899/?u=..."` 模拟点击跳转。跳转服务返回 302 `Location` 指向最新真实地址（如 `555980.xyz`），运营方每次被封就更新 302 的 Location。

`ApiServerSwitcher.testConnectivity` 检测到跳转壳后会自动完成迁移链路：

1. 检测跳转壳特征（< 3KB + `hao123` + `var strU`）
2. 正则提取 `strU` 表达式，模拟 JS 拼接构造完整 URL
3. 请求 `strU` 拿 302 `Location`
4. 用 `Location` 作为新 baseUrl 重新请求首页
5. 新地址通过 macCMS 标志检测 → `switchTo` 持久化并切换
6. `switchTo` 内部：持久化 baseUrl → 更新 `AppConstants.baseUrl` → 加入镜像列表头部 → 重建 Dio → 清空 DB 缓存 → 刷新首页 / 收藏 / 历史

启动时 Splash 页在检查更新完成后调用 `ApiServerSwitcher.fetchLatestDomain`（可见 + 阻塞式）：优先通过根域名 `http://68ck.net` 解析最新地址，失败则回退到跳转壳健康检查。获取成功时镜像列表精简为 `[根域名, 新域名]` 并按需切换；获取失败时启动页提示失败后正常进入 App，不影响后续功能。详见 [splash_page.dart](lib/presentation/pages/splash/splash_page.dart) 与 [api_server_switcher.dart](lib/core/network/api_server_switcher.dart)。

**根域名解析链路**（实测 2026-09-16）：根域名 `68ck.net` 本身是 JS 跳转壳（200 + hao123/strU HTML），`resolveLatestFromRoot` 复用跳转壳迁移链路完成解析，同时兼容根域名直接返回 3xx Location 的形态：

```
http://68ck.net/  --200+JS壳-->  https://2626.space:8899/?u=http://68ck.net/&p=/
                                 --302 Location-->  https://222478.xyz（最新真实源站）
```

**镜像列表管理**（设置页 → API 服务器 → 管理模式）：
- 多选删除 / 全选 / 取消全选（含二次确认）
- 长按单条 → 编辑 / 删除（当前生效域名不可删但可编辑，编辑会同步切换 baseUrl）
- 添加域名（不切换 baseUrl）
- 所有操作持久化到 SharedPreferences

### 播放地址解密

源站播放地址通过 token + POST 加密，解密链路：

1. 拉取详情页 HTML → 正则提取 `AID` / `ASID` / `ANID` / `AK` token
2. POST `/static/count.php`（带手势坐标、屏幕尺寸、时区等指纹）
3. 解析响应 JSON `{ ok: true, u: "<base64>" }`
4. Base64 解码拿到真实播放地址
5. 时效校验（过期抛 `UrlExpiredException`）
6. 失败时最多重试 3 次，每次间隔 2 秒

当前 baseUrl 失效时自动 fallback 到默认源站重新解密。详见 [url_decryptor.dart](lib/core/player/url_decryptor.dart)。

### HTML 解析层

列表页与详情页相关推荐复用同款 `.stui-vodlist__box` 选择器：

```html
<div class="stui-vodlist__box">
  <a class="stui-vodlist__thumb" href="/v5/8802-1-1.html" data-original="cover.jpg">
    <span class="pic-text text-right">31:05</span>   <!-- 时长 -->
  </a>
  <div class="stui-vodlist__detail">
    <h4 class="title"><a href="/v5/8802-1-1.html">标题</a></h4>
    <p class="sub">
      <span class="number pull-right"><i class="fa fa-heart"></i> 946 </span>   <!-- 收藏 -->
      <span class="pull-right"><i class="fa fa-eye"></i> 1817286 </span>        <!-- 播放 -->
      06-11                                                                     <!-- 更新 -->
    </p>
  </div>
</div>
```

解析要点：
- 过滤广告：优先 `a[href*="/v5/"]`，降级 `a[href*="/voddetail/"]`，外站广告 href 会被过滤
- 字段提取按 `fa-eye` / `fa-heart` 图标区分（不能按数字出现顺序，HTML 中 heart 在 eye 前）
- 复合 videoId：`/v5/8802-1-1.html` → `8802-1-1`（aid-sid-nid）

详见 [video_list_parser.dart](lib/core/parser/video_list_parser.dart) 与 [video_detail_parser.dart](lib/core/parser/video_detail_parser.dart)。

### 反爬应对策略

源站使用 Quantum 反爬系统，会概率性返回 418。应对链路：

| 拦截器 | 职责 |
|---|---|
| `UserAgentInterceptor` | 每次请求随机切换移动端 UA |
| `CookieInterceptor` | 注入持久化 Cookie，保存响应 Set-Cookie |
| `RetryInterceptor` | 418 / 超时自动重试（≤3 次），重试时切换 UA |
| `ErrorInterceptor` | `badCertificate` / 网络错误分支处理 |
| `LoggingInterceptor` | 请求 / 响应分级日志 |

- 全局 `HttpOverrides` + Dio `validateCertificate: (_, _, _) => true` 双层绕过证书校验
- `AppConstants.requestInterval = 2s` 限制请求频率

### 主题与设计系统

**设计令牌**（[design_tokens.dart](lib/core/theme/design_tokens.dart)）：
- Spacing：8dp rhythm（xs=4 / sm=8 / md=12 / lg=16 / xl=24 / 2xl=32 / 3xl=48）
- Radius：sm=8 / md=12 / lg=16 / xl=20 / pill=999
- Typography：display=28 / h1=22 / h2=18 / body=14 / caption=12 / label=11
- Motion：fast=150ms / base=250ms / slow=400ms / slower=600ms
- Elevation：3 级阴影（0.04 / 0.08 / 0.12 透明度）

**主题预设**（[theme_presets.dart](lib/core/theme/theme_presets.dart)）：

| 预设 | primary | secondary | accent | 描述 |
|---|---|---|---|---|
| 热情粉 | `#EC4899` | `#DB2777` | `#2563EB` | 娱乐 / 视频 |
| 资讯红 | `#DC2626` | `#EF4444` | `#1E40AF` | 资讯 / 紧凑感 |
| 专业蓝 | `#3B82F6` | `#2563EB` | `#F59E0B` | 工具 / 专业 |
| 创意紫 | `#8B5CF6` | `#A855F7` | `#10B981` | 创意 / 年轻 |
| 活力橙 | `#F97316` | `#EA580C` | `#0EA5E9` | 活力 / 阳光 |
| 自定义 | 用户选 | 自动派生 | `#2563EB` | HSV 选色盘 |

所有主题共享浅色背景 `#F5F5F7`，仅切换 primary / secondary / accent 三个语义令牌。自定义色由 `ThemeController.customColorRx` 持久化保存。

### 自动更新机制

**CI 端**（[ci.yml](.github/workflows/ci.yml)）：
1. push 到 main → `build-android` job
2. 计算 tag：`v{YYYY.MMDD.N}`（N 为当日递增序号）
3. `sed` 将去掉 `v` 的版本号注入 [app_constants.dart](lib/core/constants/app_constants.dart) 的 `appVersion`
4. `flutter build apk --debug --target-platform android-arm64 --split-per-abi`
5. 上传 `app-arm64-v8a-debug.apk` artifact
6. `auto-release` job 创建 GitHub Release，body 含 release notes

**App 端**（[github_release_service.dart](lib/core/services/github_release_service.dart)）：
1. 启动时多源依次 GET `/repos/{owner}/{repo}/releases/latest`：api.github.com 直连 → gh-proxy.com 镜像 → github.com 页面 302 解析兜底（国内网络 / 限流场景仍可检查更新）
2. 比较 `release.tagName`（去 `v` 前缀）与 `AppConstants.appVersion`
3. release 版本更大 → 返回 release 并弹出 `UpdateDialog`
4. Release body 含 `[强制更新]` 标记 → `UpdateDialog` 仅显示"立即更新"（兜底链路通过 tag 页面 HTML 补充判断标记）
5. 下载 APK 时镜像（gh-proxy.com）优先、直连兜底，并做 APK 魔数校验

---

## 页面与功能

| 页面 | 路由 | 功能 |
|---|---|---|
| Splash | - | 启动初始化 + 更新检查 |
| MainShell | `/` | 4 Tab：首页 / 收藏 / 历史 / 设置 |
| Home | - | 分类目录卷帘 + 视频网格 |
| Category | `/category` | 分类详情列表 |
| Search | `/search` | 搜索 + 搜索历史 |
| VideoDetail | `/detail` | SliverAppBar 内嵌播放 + 相关推荐 + 收藏 |
| Favorites | - | 收藏列表（GridView + VideoCard） |
| History | - | 历史记录（ListView + 缩略图 + 播放进度） |
| Settings | - | 主题色 / API 服务器 / 域名管理 / 数据导入导出 / 清缓存 / 关于 |

**详情页相关推荐跳转**：用 `Get.to` + `BindingsBuilder` + `tag: videoId` 注册独立 controller 实例，避免同名路由 `/detail` 复用旧 controller 导致显示旧数据。

---

## 构建与发布

### CI 自动构建（GitHub Actions）

push 到 `main` 分支自动触发 [.github/workflows/ci.yml](.github/workflows/ci.yml)：

1. **build-android** job：
   - 计算 `v{YYYY.MMDD.N}` tag
   - 注入版本号到 `app_constants.dart`
   - `flutter build apk --debug --target-platform android-arm64 --split-per-abi`
   - 上传 `app-arm64-v8a-debug.apk` artifact

2. **auto-release** job（依赖 build-android）：
   - 创建 GitHub Release，tag 为版本号
   - Release body 含 release notes + `[强制更新]` 标记
   - 上传 APK 到 Release assets

### 版本号规则

```
v{YYYY.MMDD.N}
    │  │    │
    │  │    └─ 当日第 N 次构建（从 0 递增）
    │  └────── 月日（如 0720）
    └───────── 年（如 2026）
```

例：`v2026.0720.0` = 2026 年 7 月 20 日第 0 次构建。

### 目标平台

- Android arm64-v8a（`--target-platform android-arm64`）
- split-per-abi 生成单架构 APK（体积更小）

---

## 本地开发

### 环境要求

- Flutter 3.24.0（推荐）/ 3.13.0+（最低）
- Dart SDK 3.0.0+
- Android SDK 34+（`flutter_plugin_android_lifecycle` 推荐 35）

### 运行

```bash
flutter pub get
flutter run
```

### Floor 代码生成

修改 DAO / 实体后需重新生成数据库实现：

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 配置源站

默认 baseUrl 在 [app_constants.dart](lib/core/constants/app_constants.dart) 的 `defaultBaseUrl`，运行时可在 设置 → API 服务器 切换。

---

## 常见问题

### Q: 为什么不用 macCMS 的 JSON API？

源站关闭了 `/api.php/provide/vod` 接口，且首页 / 详情页直接返回 stui 主题 HTML。项目复用页面 HTML 解析，避免维护两套数据源。

### Q: 为什么图片加载失败但浏览器能打开？

源站图片 CDN 常存在自签名 / 过期 / 链路不完整等证书问题。`main.dart` 已设置全局 `HttpOverrides.global` 绕过证书校验，与 Dio 的 `validateCertificate` 行为一致。

### Q: 切换域名后首页为什么是空的？

`ApiServerSwitcher.switchTo` 会清空本地 DB 缓存（categories + videos），旧数据来自旧源站避免误用。清空后 `HomeController.refresh()` 异步重新拉取，1-3 秒后自动刷新出新内容。

### Q: 跳转壳是什么？

源站老入口（如 `555973.xyz`）实际是"跳转壳"——返回 200 + ~425 字节 HTML，含 `var strU` 模拟点击跳转。跳转服务返回 302 指向最新真实地址。App 检测到跳转壳后会自动解析最新地址并切换，无需发版。

### Q: 强制更新是怎么实现的？

CI 在 Release body 里加 `[强制更新]` 标记，App 启动时 `GitHubReleaseService` 解析此标记设置 `forceUpdate=true`，`UpdateDialog` 仅显示"立即更新"按钮（无"稍后"）。

---

## License

本项目仅供学习交流使用，不得用于商业用途。使用者需自行承担使用风险。
