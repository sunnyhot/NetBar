# AGENTS.md — NetBar

## 项目概览

NetBar 是一个 macOS 菜单栏网络流量监控 App，纯 Swift 编写，无外部依赖。

- 读取 macOS 网络接口计数器（`getifaddrs`），按采样策略计算实时速率
- 通过 `/usr/bin/nettop` 获取应用级流量，详情窗口可见时才启用应用级采样
- 结合 SystemConfiguration 读取主网络接口；Mach API 系统资源仅用于可选的角色动画速度来源
- 内置 35 个 RunCat 动态角色，支持自定义角色（静态图 / GIF / 多帧图）
- 不抓包、不读取网络内容、不需要管理员权限
- 支持中英文双语、浅色/深色主题、高流量提醒、今日统计、自动更新

**技术栈**: Swift 5（SPM `swift-tools-version: 6.0`）| AppKit + SwiftUI | macOS 13+
**依赖策略**: 无第三方依赖，仅使用系统框架（AppKit, SwiftUI, Combine, Foundation, SystemConfiguration, ServiceManagement, UserNotifications, CommonCrypto 等）。

## 当前规模

### 配置与脚本

| 文件 | 行数 | 职责 |
|---|---:|---|
| `Package.swift` | 30 | SPM 配置：macOS .v13、Swift 5 语言模式、`NetBar` executable target + `NetBarTests` test target |
| `Resources/Info.plist` | 32 | Bundle ID `local.codex.NetBar`，当前版本 `0.43.1` |
| `Resources/NetBar.entitlements` | 10 | App 沙盒与自动化相关 entitlements |
| `.github/workflows/release.yml` | 141 | tag 触发的 GitHub Release 构建、测试、打包与发布流程 |
| `Scripts/build-app.sh` | 117 | `swift build --disable-sandbox -c release` 后组装 `build/NetBar.app`，可选 codesign |
| `Scripts/package-release.sh` | 25 | build + release app 验证 + zip + sha256 |
| `Scripts/verify-release-app.sh` | 48 | 验证 `.app` 可执行文件、架构和签名形态 |
| `Scripts/generate-icon.swift` | 260 | CoreGraphics 程序化生成 AppIcon |
| `Scripts/generate-pet-gifs.swift` | 106 | 从 `Resources/RunCat/` 帧图合成 README 展示 GIF 到 `docs/images/pets/` |
| `docs/images/pets/` | — | README 角色展示 GIF（由 `Scripts/generate-pet-gifs.swift` 生成） |

### Sources/NetBar

当前 `Sources/NetBar` 共 54 个 Swift 文件，约 12,589 行：

- 顶层核心文件 35 个
- `Sources/NetBar/Popover/` 详情窗口子视图 7 个
- `Sources/NetBar/Preferences/` 偏好设置子视图 12 个
- 最大文件：`StatusBarRenderer.swift` 965 行、`AppUpdater.swift` 600 行、`StatusBarController.swift` 596 行、`CustomCharacterImageProcessor.swift` 482 行、`ApplicationTrafficPanel.swift` 465 行

| 文件 | 行数 | 职责 |
|---|---:|---|
| `Main.swift` | 16 | `@main` 入口，创建 `AppDelegate` 并启动 `NSApplication.run()` |
| `AppDelegate.swift` | 272 | 初始化偏好、状态栏、历史、通知和更新器；配置标准主菜单、Dock/外观/语言 |
| `NetworkMonitor.swift` | 690 | 核心监控引擎：接口采样、应用流量采样、generation 防旧结果覆盖、历史和高流量检测 |
| `StatusBarController.swift` | 596 | `NSStatusItem` 控制器：状态栏渲染调度、详情窗口、右键菜单、RunCat 动画、无障碍和通知联动 |
| `StatusBarStyle.swift` | 235 | `StatusBarSettings` 状态栏偏好模型和 UserDefaults 持久化 |
| `StatusBarColorStyle.swift` | 281 | 状态栏颜色模式（solid/rainbow/neon/flame/aurora）、动态调色板和布局枚举 |
| `StatusBarRenderer.swift` | 965 | CoreGraphics 状态栏布局、签名 diff、文字、角色与特效渲染 |
| `StatusBarRenderCache.swift` | 150 | 状态栏图片、预览和文字布局 LRU cache |
| `Popover/NetworkPopoverView.swift` | 134 | SwiftUI 详情窗口容器：组合头部、趋势图、今日统计、应用列表和首启引导 |
| `Popover/PopoverHeaderView.swift` | 115 | 详情窗口头部：总速率、上下行与主接口名 |
| `Popover/TrafficPulseChartView.swift` | 173 | 趋势脉冲图，支持时间窗口切换 |
| `Popover/NetworkSummaryPanel.swift` | 300 | 今日统计与「最爱英雄」角色播放计数卡片 |
| `Popover/ApplicationTrafficPanel.swift` | 465 | 应用流量列表：搜索、系统进程过滤、归因说明 |
| `Popover/PopoverFooterView.swift` | 62 | 详情窗口底部操作栏 |
| `Popover/LivingSignalDesignSystem.swift` | 330 | 详情窗口设计系统：布局常量、卡片和面板背景 |
| `DetailsWindowController.swift` | 477 | 详情窗口创建、定位、外部点击关闭策略；打开后延迟刷新以避开首帧动画 |
| `AppUpdater.swift` | 600 | 自动更新协调器：检查、下载、解压、校验和自替换安装 |
| `AppUpdateRelease.swift` | 263 | Release/manifest 模型、GitHub fetch、SHA256 和更新错误 |
| `AppUpdateDialogView.swift` | 153 | SwiftUI 更新提示与下载进度界面 |
| `LockedObjectCache.swift` | 55 | 严格并发兼容的同步缓存和值容器 |
| `AppPreferences.swift` | 309 | 全局偏好：Dock、语言、外观、排序、提醒与历史设置、开机启动、动画速度来源 |
| `NetworkHistoryStore.swift` | 287 | 本地今日统计持久化与全时段动画播放计数 |
| `NetworkIntelligenceModels.swift` | 228 | 网络提醒设置、异常事件和今日汇总模型 |
| `NetworkAnomalyDetector.swift` | 70 | 持续高流量检测 |
| `NetworkNotificationController.swift` | 144 | macOS 通知授权、发送和冷却控制 |
| `ApplicationTrafficReader.swift` | 285 | 应用级流量读取：持久 `StreamingNettopReader`，解析 nettop CSV（`NettopLineParser`） |
| `NetworkStatsReader.swift` | 103 | `getifaddrs` 网络接口读取、主接口识别、显示名映射 |
| `NetworkInterfaceClassifier.swift` | 24 | 接口分类：判断虚拟/环回接口是否计入外部流量 |
| `SystemResourceReader.swift` | 231 | Mach/system API 系统内存、CPU tick、热状态读取（驱动可选的动画速度来源） |
| `SystemMetricsReader.swift` | 88 | 系统指标到动画活动等级（`ActivityLevel`）的映射 |
| `SystemPowerObserver.swift` | 54 | 低电量模式与锁屏状态监听（DistributedNotificationCenter） |
| `PerformanceSamplingPolicy.swift` | 48 | 采样策略状态模型：详情窗口可见性、锁屏、低电量与动画来源决定采样档位 |
| `DiagnosticsCenter.swift` | 84 | 诊断快照模型（版本、运行状态、采样开关） |
| `Formatters.swift` | 37 | 字节与速率格式化 |
| `InterfaceStats.swift` | 108 | 接口、快照、应用流量状态等基础数据模型 |
| `ApplicationTrafficPresentation.swift` | 343 | 应用列表过滤、搜索、排序、归因状态和展示模型 |
| `NetworkHistoryPresentation.swift` | 33 | 最近趋势窗口展示模型 |
| `RunCatAnimation.swift` | 405 | 内置角色定义、帧推进、速度映射、轮换播放 |
| `CustomCharacter*.swift` | 1150 | 自定义角色模型、GIF/帧图处理和渲染接入（3 个文件） |
| `NetBarDesignSystem.swift` | 187 | SwiftUI 设计系统组件、颜色、卡片样式 |
| `Preferences/*.swift` | 2039 | 偏好设置窗口与各 Tab/Section 子视图（12 个文件） |

### Tests

当前测试共 2 个 Swift 文件、约 4,849 行、217 个测试：

| 文件 | 行数 | 职责 |
|---|---:|---|
| `Tests/NetBarTests/PreferencesAndPresentationTests.swift` | 3642 | 偏好、状态栏渲染、窗口布局、标准菜单与无障碍、高流量提醒、历史统计、自定义角色、内置角色资源、更新 manifest、应用列表展示 |
| `Tests/NetBarTests/SystemResourceTests.swift` | 1207 | 系统资源模型、采样策略、NetworkMonitor 集成、旧采样丢弃和 streaming nettop 行为 |

## 常用命令

```bash
swift test                       # 运行全部单元测试
./Scripts/build-app.sh           # 构建并组装 build/NetBar.app
./Scripts/verify-release-app.sh build/NetBar.app
./Scripts/package-release.sh     # 生成 dist/NetBar.app.zip + sha256
swift run NetBar                 # 开发运行可执行目标
open build/NetBar.app            # 运行构建后的 App
```

构建要求：Xcode 15+、macOS 13+、Swift 6.0 工具链；源码以 Swift 5 模式编译。

## 架构与数据流

```text
Main.swift (@main)
  └─ AppDelegate
       ├─ NetworkMonitor
       │    ├─ SystemNetworkStatsReader (getifaddrs, 协议可注入)
       │    ├─ StreamingNettopReader / NettopApplicationTrafficReader (nettop, 协议可注入)
       │    ├─ SystemResourceReading (Mach API, 协议可注入, 仅动画速度来源启用时采样)
       │    ├─ PerformanceSamplingPolicy + SystemPowerObserver (采样档位与省电决策)
       │    └─ NetworkHistoryStore + NetworkAnomalyDetector (今日统计与高流量检测)
       ├─ StatusBarController
       │    ├─ StatusBarSettings + StatusBarDisplayRenderer + StatusBarRenderedImageCache
       │    ├─ RunCatAnimation + CustomCharacterStore
       │    ├─ DetailsWindowController → NetworkPopoverView
       │    └─ NetworkNotificationController（高流量事件直接转发）
       ├─ PreferencesWindowController → Preferences/*.swift
       ├─ NetworkNotificationController
       └─ AppUpdater
```

**数据流**: `getifaddrs/nettop/Mach` → Reader 协议 → `NetworkMonitor.@Published` → Combine/SwiftUI → `StatusBarController` / `NetworkPopoverView` / 通知。

## 发布链路

### 本地发布验证

发布前至少运行：

```bash
swift test
./Scripts/build-app.sh
./Scripts/verify-release-app.sh build/NetBar.app
./Scripts/package-release.sh
```

`package-release.sh` 会调用 `build-app.sh`，随后执行 `verify-release-app.sh`，最后生成：

```text
dist/NetBar.app.zip
dist/NetBar.app.zip.sha256
```

### GitHub Release workflow

`.github/workflows/release.yml` 在推送 `v*` tag 时触发，顺序是：

1. Checkout
2. 从 tag 提取版本号
3. 写入 `Resources/Info.plist` 的 `CFBundleShortVersionString` 和 `CFBundleVersion`
4. **运行 `swift test`，失败即阻断发布**
5. 构建 `build/NetBar.app`
6. 运行 `Scripts/verify-release-app.sh`
7. 打包 `dist/NetBar.app.zip` 并生成 SHA256
8. 从 `CHANGELOG.md` 提取对应版本 release notes
9. 生成 `latest.json`
10. 创建 GitHub Release 并上传 `NetBar.app.zip`、`.sha256`、`latest.json`

自动更新优先读取 `https://github.com/sunnyhot/NetBar/releases/latest/download/latest.json`，失败后回退 GitHub Releases API。Release 必须包含固定资产名 `NetBar.app.zip`，该名称来自 `Resources/Info.plist` 的 `NBUpdateAssetName`。

## 关键约定

1. **@MainActor 全局使用**：UI 类和 ObservableObject 基本都在主 actor；后台读取使用 `Task.detached(priority: .utility)`。
2. **协议注入**：`NetworkStatsReading`、`ApplicationTrafficReading`、`SystemResourceReading`、`LoginItemManaging`、通知中心等均可替换，测试优先用 mock。
3. **i18n 模式**：新增用户可见字符串使用 `appPreferences.text("中文", "English")` 或 `AppLanguage.text(...)` 双参数。
4. **偏好持久化**：`AppPreferences` 和 `StatusBarSettings` 多数属性通过 `didSet { save() }` 写入 UserDefaults。
5. **状态栏渲染**：CoreGraphics 生成 `NSImage`；`StatusBarRenderSignature` 做 diff；`StatusBarRenderedImageCache` 和文字 layout cache 避免重复绘制。
6. **采样节流**：应用级 `nettop` 只在详情窗口可见时启用，关闭后延迟暂停；低电量/锁屏会调整或停止采样；系统资源采样仅在动画速度来源需要时启动。
7. **无 Storyboard/XIB**：窗口、菜单和 SwiftUI hosting 均纯代码创建。
8. **资源打包**：SPM target 不声明 resources；`.app` 资源由 `Scripts/build-app.sh` 从 `Resources/` 复制。

## 已知坑点

1. **状态栏渲染仍是高复杂度区域**：设置在 `StatusBarStyle.swift`，颜色和布局枚举在 `StatusBarColorStyle.swift`，绘制在 `StatusBarRenderer.swift`；修改时优先补签名、布局或像素测试。
2. **详情窗口 UI 分散在 `Popover/`**：容器 `NetworkPopoverView.swift` 很薄，大头是 `ApplicationTrafficPanel.swift` 和 `LivingSignalDesignSystem.swift`，改动时注意不要引入布局回归。
3. **自动更新风险高**：`AppUpdater.swift`、`AppUpdateRelease.swift` 和 `AppUpdateDialogView.swift` 共同覆盖网络、zip、SHA256、架构/签名校验和自替换安装；发布相关改动必须跑测试和本地打包验证。
4. **`nettop` 进程依赖**：沙盒/系统版本差异可能影响输出和 spawn；streaming reader 依赖 `/usr/bin/script` 分配伪终端以减少缓冲。
5. **构建需 `--disable-sandbox` 且依赖完整 Xcode**：`build-app.sh` 已封装。若 `swift build` 报 `SwiftUIMacros.StateMacro could not be found`，说明 `xcode-select` 指向了 CommandLineTools（其 SDK 缺宏插件），用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` 前缀执行或把 `xcode-select` 切到 Xcode。
6. **签名形态**：本地默认保留 SwiftPM linker-signed/ad-hoc 形态；正式分发如要公证，需要开发者签名和 hardened runtime 策略。
7. **版本发布一致性**：tag、`CHANGELOG.md`、Release notes、Info.plist 写入流程要保持一致；GitHub workflow 会在发布时按 tag 写 Info.plist。
8. **RunCat 资源硬编码**：内置角色定义在 `RunCatAnimation.swift`，需要同步维护 `Resources/RunCat/<id>/frame_N.png`；README 角色展示 GIF（`docs/images/pets/`）由 `Scripts/generate-pet-gifs.swift` 从这些帧图生成，改角色帧或换展示角色后需重新运行并同步 README 引用。
9. **GUI 启动方式**：不要从 Codex/受限父进程直接执行 `build/NetBar.app/Contents/MacOS/NetBar`，AppKit 可能在 `HIServices _RegisterApplication` 阶段 `SIGABRT`；给用户试运行时优先让用户从 Finder/Terminal 用 `open build/NetBar.app` 启动。
10. **避免多开菜单栏实例**：不要用 `open -n build/NetBar.app`，除非明确要测多实例；误多开时先执行 `killall NetBar` 清理，再单实例启动。受限 shell 可能杀不掉 GUI 进程，此时改用 `osascript -e 'tell application id "local.codex.NetBar" to quit'` 走 Apple Events。

## Agent 工作指南

- 先读 `PROJECT_MAP.md`，再动核心模块。
- 修改状态栏渲染先看 `StatusBarRenderer.swift`、`StatusBarColorStyle.swift`、`StatusBarController.swift`、`StatusBarRenderCache.swift`；设置持久化看 `StatusBarStyle.swift`。
- 修改详情窗口先看 `Popover/` 下相关子视图，尤其是 `ApplicationTrafficPanel.swift` 和 `LivingSignalDesignSystem.swift`。
- 新增偏好设置优先复用 `Preferences/*.swift` 的分组组件，并确认 UserDefaults key 和 reset 行为。
- 新增用户可见文案必须补中英文。
- 修改采样、历史、通知、更新或发布链路时必须跑 `swift test`。
- 修改 `.app` 打包、资源、签名、自动更新时还要跑 `./Scripts/build-app.sh` 和 `./Scripts/verify-release-app.sh build/NetBar.app`。
- 构建 App 必须用 `./Scripts/build-app.sh`；不要手动复制资源或拼 `.app`。
- 修改动画/角色时同步维护 `Resources/RunCat/` 帧图片、`RunCatAnimation.swift` 元数据和相关测试；如影响 README 展示的角色，运行 `swift Scripts/generate-pet-gifs.swift` 重新生成 GIF 并同步 README 引用。
- 需要用户手测 App 时，不要从 Codex 直接执行 `Contents/MacOS/NetBar`；如果 Codex 环境无法通过 LaunchServices 启动，就说明原因并让用户在自己的 Terminal/Finder 里启动。
