# PROJECT_MAP.md — NetBar

## 1. 项目定位

NetBar 是一个纯 Swift 的 macOS 菜单栏网络流量监控 App。

核心能力：

- 菜单栏实时显示下载/上传/总流量
- 点击打开详情窗口，展示趋势、接口、应用级流量、系统资源、网络智能洞察
- 通过 `getifaddrs` 读取接口计数器，通过 `/usr/bin/nettop` 读取应用级流量
- 通过 `ps`、Mach API、SystemConfiguration 补充进程资源、系统资源和主接口信息
- 内置 RunCat 动画、自定义角色、智能角色推荐、宠物系统、历史统计、系统通知、自动更新

技术边界：

- Swift Package Manager，`swift-tools-version: 6.0`
- Swift 5 语言模式
- macOS 13+
- AppKit + SwiftUI + Combine
- 无第三方依赖

## 2. 顶层目录

```text
.
├── Package.swift
├── Sources/NetBar/
├── Sources/NetBar/Preferences/
├── Tests/NetBarTests/
├── Resources/
├── Scripts/
├── .github/workflows/release.yml
├── README.md
├── AGENTS.md
├── PROJECT_MAP.md
└── CHANGELOG.md
```

当前规模：

- `Sources/NetBar`: 54 个 Swift 文件，约 16,742 行
- `Tests/NetBarTests`: 2 个 Swift 文件，约 6,444 行，284 个测试
- `Resources/RunCat`: 35 个内置动画角色帧资源
- 当前 App 版本：`Resources/Info.plist` 中 `0.39.9`

## 3. 启动与对象装配

```text
Main.swift
  └─ AppDelegate
       ├─ AppPreferences
       ├─ StatusBarSettings
       ├─ CustomCharacterStore
       ├─ SystemPowerObserver
       ├─ NetworkHistoryStore
       ├─ NetworkNotificationController
       ├─ PetController
       ├─ AppUpdater
       ├─ PreferencesWindowController
       └─ StatusBarController
            └─ NetworkMonitor
```

关键文件：

- `Main.swift`: `@main` 入口，创建 `AppDelegate` 并启动 `NSApplication.run()`
- `AppDelegate.swift`: 统一装配控制器、设置主菜单、应用外观、Dock policy、更新检查和 onboarding 展示
- `AppPreferences.swift`: App 级偏好、语言、外观、Dock、登录项、网络智能设置
- `StatusBarStyle.swift`: `StatusBarSettings` 持久化状态栏显示偏好

## 4. 监控数据流

```text
SystemNetworkStatsReader
StreamingNettopReader / NettopApplicationTrafficReader
PSApplicationResourceReader
LiveSystemResourceReader
        │
        ▼
NetworkMonitor
        │
        ├─ @Published snapshot
        ├─ @Published appTraffic
        ├─ @Published systemResources
        ├─ @Published intelligenceSummary
        └─ recentHistory
        │
        ▼
StatusBarController / NetworkPopoverView / NetworkNotificationController / PetController
```

关键文件：

- `NetworkMonitor.swift`: 核心采样引擎，维护接口速率、应用流量、系统资源、历史 buffer 和智能摘要
- `NetworkStatsReader.swift`: `getifaddrs` + `if_data` 读取网络接口累计计数器
- `NetworkInterfaceClassifier.swift`: 判断哪些接口计入外部总流量
- `ApplicationTrafficReader.swift`: 应用级流量读取；默认使用持久 `StreamingNettopReader`
- `ApplicationResourceReader.swift`: `ps aux` 读取进程 CPU/内存
- `SystemResourceReader.swift`: Mach API 读取内存、CPU tick、热状态
- `PerformanceSamplingPolicy.swift`: 根据运行状态、详情窗口、低电量、锁屏和活动等级决定采样频率

采样原则：

- 接口速率由当前累计计数器减去上次计数器得到
- 虚拟/代理类接口通过 `NetworkInterfaceClassifier` 从总量中过滤
- 应用级流量仅在详情窗口可见时启用；窗口关闭后延迟暂停
- 低电量模式会降低接口、应用、系统资源采样频率
- 屏幕休眠时停止采样并暂停动画相关刷新

## 5. 状态栏渲染

```text
StatusBarController
  ├─ 监听 NetworkMonitor / StatusBarSettings / AppPreferences / CustomCharacterStore
  ├─ 合并高频刷新请求
  ├─ 计算 StatusBarRenderSignature
  ├─ 命中 StatusBarRenderedImageCache 或调用 StatusBarDisplayRenderer
  └─ 写入 NSStatusItem.button.image
```

关键文件：

- `StatusBarController.swift`: 状态栏交互、渲染调度、右键菜单、详情窗口、RunCat 动画、Googly Eyes 鼠标追踪
- `StatusBarStyle.swift`: 状态栏布局、文字、背景、角色、颜色模式、特效绘制
- `StatusBarRenderCache.swift`: 图片和文字布局 cache
- `StatusBarContextEvaluator.swift`: 智能状态栏内容选择、智能角色推荐
- `RunCatAnimation.swift`: 内置角色元数据、动画帧推进、速度和轮换
- `CustomCharacter.swift`
- `CustomCharacterStore.swift`
- `CustomCharacterImageProcessor.swift`

性能设计：

- `StatusBarRenderSignature` 避免相同输入重复绘制
- `StatusBarRenderedImageCache` 缓存最近渲染图
- 文本 layout cache 降低重复排版成本
- 智能角色推荐通过 render override 生效，不写回用户选择的角色
- render coalescing 根据实时流量动态从 1fps 到 15fps
- 动态颜色时间桶以 4Hz 量化，避免过密刷新

## 6. 详情窗口

```text
StatusBarController.showDetailsWindow()
  ├─ DetailsWindowController.show()
  └─ ApplicationTrafficVisibilityScheduler.scheduleResume()
       └─ monitor.isApplicationTrafficVisible = true
```

关键文件：

- `DetailsWindowController.swift`: 详情窗口创建、定位、关闭和外部点击监控
- `NetworkPopoverView.swift`: SwiftUI 详情页主体，展示总览、趋势、接口、应用、历史、智能、系统资源；滚动内容懒构建，应用图标延迟解析并复用缓存
- `ApplicationTrafficPresentation.swift`: 应用列表过滤、搜索、排序、归因摘要和展示模型
- `NetworkHistoryPresentation.swift`: 最近历史窗口和流量估算展示
- `NetBarDesignSystem.swift`: 详情页和偏好页复用的视觉组件

注意点：

- 详情窗口先展示，再延迟启用应用级 `nettop` 采样，避免打开时同步启动进程导致下滑卡顿
- 详情窗口打开后延迟触发接口刷新，避免首帧下滑动画同时承受 SwiftUI 重绘
- 详情窗口关闭后延迟暂停应用级采样，短时间重开可复用热状态
- 应用列表的实时流量模式会隐藏当前无流量应用；内存/CPU 模式会保留资源型应用
- 代理/VPN/浏览器 helper 归因可能导致应用总量与接口总量不一致，展示层会给出提示

## 7. 偏好设置

```text
PreferencesWindowController
  └─ PreferencesView
       ├─ GeneralPreferencesView
       ├─ MenuBarPreferencesView
       │    ├─ MenuBarDisplayPreferencesView
       │    ├─ MenuBarLayoutPreferencesView
       │    ├─ MenuBarAnimationPreferencesView
       │    ├─ MenuBarCharacterPreferencesView
       │    └─ MenuBarSubcomponents
       ├─ IntelligencePreferencesView
       └─ AboutPreferencesView
```

关键文件：

- `Sources/NetBar/Preferences/PreferencesWindowController.swift`: 偏好窗口壳和 tab 入口
- `GeneralPreferencesView.swift`: 通用设置
- `MenuBarPreferencesView.swift`: 菜单栏设置入口
- `MenuBarDisplayPreferencesView.swift`: 速率显示、文字、颜色、背景
- `MenuBarLayoutPreferencesView.swift`: 宽度、对齐、行距、排序等布局
- `MenuBarAnimationPreferencesView.swift`: 动画速度、头部摆动、速度来源
- `MenuBarCharacterPreferencesView.swift`: 内置/自定义角色选择
- `IntelligencePreferencesView.swift`: 网络智能、通知、历史、宠物设置
- `AboutPreferencesView.swift`: 关于、更新和诊断入口
- `PreferencesComponents.swift`: 通用设置组件

约定：

- 新增偏好要确认持久化 key、默认值、reset 行为和测试
- 用户可见字符串使用中英文双参数
- 偏好 UI 已拆分，避免重新堆回 `PreferencesWindowController`

## 8. 网络智能、历史、通知、宠物

```text
NetworkMonitor
  ├─ NetworkHistoryStore
  ├─ NetworkAnomalyDetector
  └─ NetworkInsightCenter
        │
        ▼
NetworkIntelligenceCoordinator
  ├─ NetworkNotificationController
  └─ PetController
```

关键文件：

- `NetworkIntelligenceModels.swift`: 设置、异常事件、洞察卡片、日汇总
- `NetworkAnomalyDetector.swift`: 持续高流量、应用突增、断流/恢复、代理归因差异
- `NetworkInsightCenter.swift`: 将异常事件聚合成可展示洞察卡片
- `NetworkHistoryStore.swift`: 日维度统计、Top 应用、动画播放计数、本地 JSON 持久化
- `NetworkNotificationController.swift`: 通知授权、发送和 cooldown
- `PetState.swift`
- `PetController.swift`
- `PetSkill.swift`

注意点：

- 历史文件默认在用户 Application Support 下的 `NetBar/NetworkHistory.json`
- 读取到损坏历史文件时会备份成 `NetworkHistory.corrupt-<timestamp>.json`
- 通知发送受系统授权、设置开关和事件 cooldown 三重限制
- 智能角色推荐默认关闭；开启后按异常、Top 应用突增、上传占优、高总流量、低速空闲即时推荐内置角色
- 宠物系统会观察异常事件和每日摘要，生成 mood/cue/reminder

## 9. 自动更新

关键文件：

- `AppUpdater.swift`
- `Resources/Info.plist`
- `.github/workflows/release.yml`
- `Scripts/package-release.sh`
- `Scripts/verify-release-app.sh`

更新信息来源：

1. 优先请求 `https://github.com/sunnyhot/NetBar/releases/latest/download/latest.json`
2. manifest 失败且属于临时错误时回退 GitHub Releases API
3. 如果 API 失败但 latest redirect 能拿到新 tag，会构造 fallback release 信息

下载与安装流程：

```text
checkForUpdates
  ├─ fetch latest tag via redirect
  ├─ fetch latest.json / GitHub API
  ├─ compare semantic-ish version
  └─ show update dialog

downloadForDialog / downloadAndInstall
  ├─ download zip with progress
  ├─ validate SHA256 when available
  ├─ validate zip magic
  ├─ unzip via ditto
  ├─ validate bundle, version, executable, architecture, codesign shape
  └─ write temp zsh installer, replace current .app, relaunch
```

风险点：

- 本地构建默认可能是 SwiftPM linker-signed/ad-hoc
- bundle id 不一致目前是 warning，不是 hard failure
- 正式分发若需要 Gatekeeper 体验更好，应引入开发者签名、公证和 hardened runtime

## 10. 发布链路

### 本地发布检查

```bash
swift test
./Scripts/build-app.sh
./Scripts/verify-release-app.sh build/NetBar.app
./Scripts/package-release.sh
```

`package-release.sh` 会执行 build、release app 验证、zip、sha256。

### GitHub Actions Release

触发条件：推送 `v*` tag。

顺序：

1. Checkout
2. 提取 tag 和版本号
3. 写入 `Resources/Info.plist`
4. 运行 `swift test`
5. 构建 `build/NetBar.app`
6. 运行 `Scripts/verify-release-app.sh build/NetBar.app`
7. 生成 `dist/NetBar.app.zip` 和 SHA256
8. 从 `CHANGELOG.md` 提取当前 tag 对应 release notes
9. 生成 `latest.json`
10. 创建 GitHub Release

发布门禁：

- `swift test` 失败会阻断发布
- release notes 缺失会阻断发布
- app bundle、可执行文件、架构或签名形态不符合验证脚本会阻断发布

## 11. 测试地图

运行：

```bash
swift test
```

测试文件：

- `PreferencesAndPresentationTests.swift`: 偏好、状态栏、窗口、智能、历史、自定义角色、内置角色资源、更新、宠物、应用展示
- `SystemResourceTests.swift`: 系统资源、采样策略、NetworkMonitor 集成、应用资源、streaming nettop

重点测试方向：

- 修改 `StatusBarStyle.swift`：补状态栏 presentation/signature/image/layout 测试
- 修改采样或资源读取：补 `NetworkMonitor`、mock reader、采样策略测试
- 修改应用列表：补 `ApplicationTrafficPresentation` 测试
- 修改历史/智能：补 `NetworkHistoryStore`、`NetworkAnomalyDetector`、通知 cooldown、智能状态栏/角色推荐测试
- 修改自动更新：补 manifest、version compare、archive integrity、fetch fallback 测试
- 修改发布脚本：本地跑 build、verify、package

## 12. 常见改动入口

| 需求 | 优先查看 |
|---|---|
| 菜单栏显示格式、宽度、颜色、角色布局 | `StatusBarStyle.swift`, `StatusBarController.swift`, `StatusBarRenderCache.swift` |
| 详情窗口展示 | `NetworkPopoverView.swift`, `ApplicationTrafficPresentation.swift`, `NetworkHistoryPresentation.swift` |
| 应用级流量 | `ApplicationTrafficReader.swift`, `NetworkMonitor.swift` |
| 接口总流量 | `NetworkStatsReader.swift`, `NetworkInterfaceClassifier.swift`, `NetworkMonitor.swift` |
| 系统资源 | `SystemResourceReader.swift`, `ApplicationResourceReader.swift`, `SystemMetricsReader.swift` |
| 采样性能 | `PerformanceSamplingPolicy.swift`, `NetworkMonitor.swift`, `StatusBarController.swift` |
| 网络智能提醒 | `NetworkAnomalyDetector.swift`, `NetworkInsightCenter.swift`, `NetworkNotificationController.swift` |
| 历史统计 | `NetworkHistoryStore.swift`, `NetworkHistoryPresentation.swift`, `NetworkIntelligenceModels.swift` |
| 偏好设置 | `AppPreferences.swift`, `StatusBarStyle.swift`, `Sources/NetBar/Preferences/*.swift` |
| 自定义角色 | `CustomCharacter.swift`, `CustomCharacterStore.swift`, `CustomCharacterImageProcessor.swift`, `StatusBarStyle.swift` |
| RunCat 内置角色 | `RunCatAnimation.swift`, `Resources/RunCat/`, `PreferencesAndPresentationTests.swift` |
| 自动更新 | `AppUpdater.swift`, `.github/workflows/release.yml`, `Scripts/package-release.sh` |
| 发布打包 | `Scripts/build-app.sh`, `Scripts/verify-release-app.sh`, `Scripts/package-release.sh` |

## 13. 工程约定

- 保护用户已有改动，不做无关重构
- 使用 `rg` / `rg --files` 查找代码
- 手动编辑使用 `apply_patch`
- 新增用户可见文案必须中英文齐全
- UI/ObservableObject 默认考虑 `@MainActor`
- 后台系统读取优先 `Task.detached(priority: .utility)`
- Reader 类逻辑优先协议注入，方便测试
- 不引入第三方依赖，除非用户明确要求
- `.app` 资源由 `Scripts/build-app.sh` 复制，不依赖 SPM resources
- 修改发布链路、自动更新、签名、资源打包时，要同时更新 `AGENTS.md` 和本文件
