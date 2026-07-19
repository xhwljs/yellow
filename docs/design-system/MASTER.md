# VideoHub Design System — MASTER (Single Source of Truth)

> 由 UI-UX-Pro-Max Skill 推理生成，针对 **视频聚合 / 内容浏览** 类型应用定制。
> 严格遵守：**仅浅色模式（Light Mode Only）** + **支持主题色切换（Multi-Theme Color Switching）**。
> 任何页面、组件、动效均以本文件为唯一真理源；如需覆写，在 `design-system/videohub/pages/<page>.md` 中以 Override 模式记录。

---

## 1. 设计风格 (Style)

### 主风格：Bento Grids（Apple 风格模块化）+ Content-First

| 属性 | 取值 |
|------|------|
| 风格名称 | Bento Grids（Apple-style Modular） |
| 关键词 | modular, cards, organized, clean, hierarchy, grid, rounded, soft, content-first |
| 主背景 | `#F5F5F7`（Off-white） |
| 卡片背景 | `#FFFFFF`（Pure White） |
| 浅色模式支持 | ✓ Full（唯一模式） |
| 性能 | ⚡ Excellent（无 GPU 重特效） |
| 无障碍 | ✓ WCAG AA |
| 复杂度 | Low |

### 模式（Mode）声明
- **Light Mode**：唯一支持模式。禁止任何 `dark` / `OLED` / 深色背景配色。
- **主题色切换**：通过切换 `primaryColor / secondaryColor / accentColor` 三个语义令牌实现，背景保持 `#F5F5F7` 不变。
- 提供 5 套预设主题色（见 §3），用户可在设置页切换。

---

## 2. 设计变量（Design Tokens）

### 2.1 间距（Spacing）— 8dp 节奏

| Token | Value | 用途 |
|-------|-------|------|
| `space-xs` | 4 | 内边距微调 / 图标内边距 |
| `space-sm` | 8 | 列表项内边距 / 标签 |
| `space-md` | 12 | 卡片内边距 / 组件间距 |
| `space-lg` | 16 | 标准内边距 / Section 间距 |
| `space-xl` | 24 | 区块分隔 |
| `space-2xl` | 32 | 大区块分隔 |
| `space-3xl` | 48 | Hero 区垂直间距 |

### 2.2 圆角（Radius）

| Token | Value | 用途 |
|-------|-------|------|
| `radius-sm` | 8 | 小按钮 / 标签 |
| `radius-md` | 12 | 输入框 / 小卡片 |
| `radius-lg` | 16 | 标准卡片 |
| `radius-xl` | 20 | 视频卡片 / Bento Grid |
| `radius-pill` | 999 | 胶囊按钮 / Chip |
| `radius-full` | 999 | 圆形头像 / FAB |

### 2.3 字号（Typography Scale）

| Token | Size / Weight | 用途 |
|-------|---------------|------|
| `text-display` | 28 / w700 | 页面主标题 |
| `text-h1` | 22 / w700 | Section 标题 |
| `text-h2` | 18 / w600 | 卡片标题 / 视频标题 |
| `text-body` | 14 / w400 | 正文 / 描述 |
| `text-caption` | 12 / w400 | 辅助说明 / 时间戳 |
| `text-label` | 11 / w600 | Tab 标签 / Badge |

### 2.4 阴影（Elevation）

| Token | Shadow | 用途 |
|-------|--------|------|
| `elevation-0` | none | 扁平元素 / Section 分隔 |
| `elevation-1` | `0 1px 2px rgba(0,0,0,0.04)` | 默认卡片 |
| `elevation-2` | `0 4px 12px rgba(0,0,0,0.08)` | Hover / 选中卡片 |
| `elevation-3` | `0 8px 24px rgba(0,0,0,0.12)` | Modal / FAB |

### 2.5 动效时长（Motion Duration）

| Token | Value | 用途 |
|-------|-------|------|
| `motion-fast` | 150ms | Tap 反馈 / 状态切换 |
| `motion-base` | 250ms | 标准过渡 |
| `motion-slow` | 400ms | 页面转场 / Hero 入场 |
| `motion-slower` | 600ms | 复杂 choreography（非默认） |

**Easing**: `Curves.easeOutCubic`（出场）/ `Curves.easeInCubic`（入场）/ `Curves.fastOutSlowIn`（标准）

---

## 3. 主题色系统（Multi-Theme Color Switching）

### 3.1 不变令牌（所有主题共享）

| Token | Value | 说明 |
|-------|-------|------|
| `--color-background` | `#F5F5F7` | 页面背景（Off-white） |
| `--color-surface` | `#FFFFFF` | 卡片表面 |
| `--color-surface-variant` | `#FAFAFA` | 次级卡片 |
| `--color-on-background` | `#1D1D1F` | 主文本（深灰，对比 15:1） |
| `--color-on-surface` | `#1D1D1F` | 卡片内文本 |
| `--color-on-surface-muted` | `#6E6E73` | 次级文本（对比 7:1） |
| `--color-border` | `#E5E7EB` | 分隔线 |
| `--color-scrim` | `rgba(0,0,0,0.5)` | Modal 遮罩 |
| `--color-destructive` | `#DC2626` | 错误 / 删除 |
| `--color-success` | `#10B981` | 成功 / 已收藏 |
| `--color-warning` | `#F59E0B` | 警告 |

### 3.2 可切换主题预设（5 套）

> 用户在「设置 → 主题色」中切换。切换后所有 `primary / secondary / accent` 令牌同步更新，背景与文字色保持不变。

| 主题名 | Primary | Secondary | Accent | 适用场景 |
|--------|---------|-----------|--------|---------|
| **Pink (默认)** | `#EC4899` | `#DB2777` | `#2563EB` | 娱乐 / 视频 |
| **Red** | `#DC2626` | `#EF4444` | `#1E40AF` | 资讯 / 紧凑感 |
| **Blue** | `#3B82F6` | `#2563EB` | `#F59E0B` | 工具 / 专业 |
| **Purple** | `#8B5CF6` | `#A855F7` | `#10B981` | 创意 / 年轻 |
| **Orange** | `#F97316` | `#EA580C` | `#0EA5E9` | 活力 / 阳光 |

### 3.3 On-Color（保证对比）

| Token | Value |
|-------|-------|
| `--color-on-primary` | `#FFFFFF` |
| `--color-on-secondary` | `#FFFFFF` |
| `--color-on-accent` | `#FFFFFF` |
| `--color-ring` | 与 primary 同色，alpha=0.4 |

### 3.4 视频占位与渐变

| Token | Value | 用途 |
|-------|-------|------|
| `--color-video-placeholder` | Linear `#E5E7EB → #F5F5F7` | 视频封面加载占位 |
| `--color-skeleton` | `#E5E7EB` | 骨架屏闪烁基色 |
| `--color-overlay` | `rgba(0,0,0,0.4)` | 视频卡片底部文字遮罩 |

---

## 4. 字体（Typography）

| 角色 | Font | 用途 |
|------|------|------|
| Heading | `Righteous` | 大标题 / Hero / Logo |
| Body | `Poppins` (w300,400,500,600,700) | 正文 / 按钮 / 描述 |
| Mono | `JetBrains Mono` | 时长 / 进度时间码 |

Google Fonts 引入（在 pubspec 中通过 `google_fonts` 包动态加载）：
```
https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&family=Righteous&family=JetBrains+Mono:wght@400;500&display=swap
```

> 若离线/无网络，fallback 到 `SF Pro Display / Roboto / system`。

---

## 5. 关键动效（Motion）

### 5.1 标准动效清单

| 场景 | 动效 | 时长 | Easing |
|------|------|------|--------|
| Tab 切换 | CrossFade + Slide | 250ms | easeOutCubic |
| 卡片点击 | Scale 0.97 + 涟漪 | 150ms | easeOut |
| 列表入场 | Staggered SlideUp 12pt | 400ms | fastOutSlowIn |
| 模态弹出 | Scale 0.92→1 + Fade | 250ms | easeOutCubic |
| FAB 出现 | Scale 0→1 + 旋转 45° | 300ms | easeOutBack |
| 下拉刷新 | Custom indicator | 600ms | linear |
| 视频封面加载 | Shimmer | 1200ms | linear (loop) |

### 5.2 页面转场（GetX route transition）

- 类型：`transition.fadeIn` + `Transition.downToUp`（详情页）
- 时长：400ms
- easing：`Curves.fastOutSlowIn`

### 5.3 视频播放器手势反馈

| 手势 | 反馈 | 时长 |
|------|------|------|
| 双击暂停/播放 | Icon Pulse | 200ms |
| 长按倍速 (2x) | Toast 提示 "2x Speed" | 1500ms |
| 横向拖动 | 进度条 Thumb 同步 + 时间 Bubble | 实时 |
| 纵向左拖 | 亮度遮罩渐变 | 实时 |
| 纵向右拖 | 音量遮罩渐变 | 实时 |

---

## 6. 需要避免的反模式（Anti-Patterns）

> **任何 PR 都必须遵守。Code Review 必查项。**

| ❌ 禁止 | ✅ 替代方案 |
|---------|------------|
| 深色模式（任何 `#000` / `#121212` 背景） | 始终使用 `#F5F5F7` 背景 |
| Emoji 作为结构性图标（🎨 ⚙️ ▶️） | 使用 Phosphor / Lucide 矢量图标 |
| 像素级硬编码颜色（`Color(0xFFEC4899)` 散落各处） | 全部走 `AppTheme.of(context).primaryColor` 语义令牌 |
| 拟物化阴影（多层 box-shadow） | 仅用 `elevation-1/2/3` 三档 |
| 慢动画（>500ms 微交互） | 微交互 150-300ms |
| 触摸目标 < 44×44pt | 全部 ≥48×48 |
| 灰色正文文本对比 < 4.5:1 | `on-surface-muted` 至少 `#6E6E73` |
| 视频卡片无加载占位 | 必须用 Shimmer + 占位图 |
| Modal 透底遮罩 < 40% | `--color-scrim` 至少 50% black |
| 全屏视频卡片高度未适配 | 9:16 / 16:9 自适应 + SafeArea |
| 列表无空状态 | 必须有空数据/错误/加载三态占位 UI |
| 进度条无缓冲指示 | buffered + current 双轨 |
| 播放失败无重试按钮 | 错误 UI 必带「重试」CTA |

---

## 7. 页面级 Override 规则

页面级覆写在 `design-system/videohub/pages/<page>.md` 中：

| 页面 | 关键 Override |
|------|---------------|
| `home.md` | 顶部 Bento Hero 区 + 6 列网格推荐 |
| `category.md` | 横向 Chip 滚动条 + 2 列瀑布流 |
| `detail.md` | 上方视频封面 / 下方信息卡片，SafeArea 顶部 inset 24 |
| `player.md` | 全黑播放器（视频内容黑底例外），底部渐变控件 |
| `favorites.md` | 与 `home.md` 网格一致，但加 "已收藏" 角标 |
| `history.md` | 时间分组 List，每条带删除滑动操作 |
| `settings.md` | 主题色色块预览，6 列 Grid |

> 视频播放器页面 `player.md` 是**唯一允许使用黑色背景**的页面（视频内容本身需要），但控件、文字仍走主题色令牌。

---

## 7.5 分类菜单 Tab（首页导航）

> **真理源**：所有分类菜单 Tab 必须遵循本节规范，禁止在其它页面定义不同样式。
> **设计依据**：参考 ui-ux-pro-max `Material You (MD3) Mobile` 风格 — pill-shaped + state-layer 思想。

### 视觉规范

| 状态 | 背景 | 文字 | 边框 | 阴影 |
|------|------|------|------|------|
| **选中态** | `colors.primary` | `colors.onPrimary` (w700) | 无 | `elevation-1` |
| **未选中态** | `colors.surface` | `colors.onSurfaceMuted` (w500) | `colors.border` (1px) | 无 |

### 形状与尺寸

| 属性 | 值 |
|------|----|
| 圆角 | `radius-pill` (999) |
| 高度 | 40pt（含 8pt 上下 padding） |
| 横向 padding | `space-lg` (16) |
| 纵向 padding | `space-sm` (8) |
| Tab 间距 | `space-sm` (8) |
| 列表左右 padding | `space-md` (12) |

### 内容布局

- **Tab 列表**：横向滚动 `ListView.separated`，第一项固定为 "推荐"，其余依次为各分类
- **选中"推荐"**：保留原 Section 布局，所有分类横向滚动 6 条
- **选中具体分类**：网格布局（2 列）+ 分页懒加载（滚动到距底部 200pt 触发加载更多）
- **切换动效**：`AnimatedContainer` + `motion-fast` (150ms) + `Curves.easeOutCubic`
- **主题切换**：通过 `Obx` 监听 `ThemeController.presetRx`，自动重建颜色

### 反模式（禁止）

- ❌ 使用下划线 indicator（TabBar 默认风格）— 与 MD3 pill 风格冲突
- ❌ Tab 跳转到独立页面（除"更多"按钮外）— 应原地切换内容
- ❌ Tab 高度 < 40pt — 触摸目标不足
- ❌ 切换动效 > 300ms — 用户感知迟滞
- ❌ 未选中态使用 `colors.primary.withOpacity(0.1)` 之类的临时色 — 必须用语义令牌

---

## 8. Pre-Delivery Checklist（交付前必查）

### 视觉质量
- [ ] 无 emoji 作为图标，全部使用 Phosphor / Lucide 矢量图标
- [ ] 所有图标来自同一图标族（Phosphor Duo Tone / Linear 一致）
- [ ] 所有颜色均通过 `AppTheme` 语义令牌读取，无硬编码 hex
- [ ] 卡片阴影仅使用 `elevation-1/2/3`

### 交互
- [ ] 所有可点击元素 ≥ 48×48pt
- [ ] 微交互 150-300ms，使用 `Curves.fastOutSlowIn`
- [ ] Disabled 状态视觉清晰且不可点
- [ ] 滚动列表无嵌套手势冲突

### 主题切换
- [ ] 切换主题后 5 套预设色全部正确生效
- [ ] 切换不重建整个 widget tree（使用 `Obx` / `AnimatedTheme`）
- [ ] 主题选择持久化到 SharedPreferences
- [ ] **不出现任何深色背景**

### 布局
- [ ] SafeArea 顶部 / 底部均已遵守
- [ ] 375px 小屏 + 平板均验证
- [ ] 8dp 间距节奏统一
- [ ] 长文本在平板上不出现 edge-to-edge

### 无障碍
- [ ] 视频封面带 accessibilityLabel
- [ ] 所有按钮有 tooltip / semantics
- [ ] 颜色不是唯一指示器（已收藏带角标 + 颜色）
- [ ] Reduce Motion 时禁用所有非必要动画

---

## 9. 引用与版本

- 生成工具：UI-UX-Pro-Max Skill v2.11.0（`.trae/skills/ui-ux-pro-max`）
- 生成查询：`"video aggregation entertainment media content browsing modern immersive"`
- 配套查询：`style: "minimalism light mode content-first clean"` / `color: "entertainment video media vibrant"` / `typography: "video streaming entertainment modern bold"`
- 设计刻度：Variance=5 / Motion=5 / Density=7
- 版本：v1.0.0 — 2026-07-19
