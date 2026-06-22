# AGENTS.md — NetBar

## 项目概览

NetBar 是一个 macOS 菜单栏网络流量监控 App，纯 Swift 编写，无外部依赖。

- 读取 macOS 网络接口计数器（`getifaddrs`），按采样策略计算实时速率
- 通过 `/usr/bin/nettop` 获取应用级流量，详情窗口可见时才启用应用级采样
- 结合 `ps`、Mach API、SystemConfiguration 读取应用资源、系统资源和主网络接口
- 不抓包、不读取网络内容、不需要管理员权限
- 支持中英文双语、浅色/深色主题、RunCat 动画角色、自定义角色、智能角色推荐、网络智能提醒、历史统计、自动更新

**技术栈**: Swift 5（SPM `swift-tools-version: 6.0`）| AppKit + SwiftUI | macOS 13+
**依赖策略**: 无第三方依赖，仅使用系统框架（AppKit, SwiftUI, Combine, Foundation, SystemConfiguration, ServiceManagement, UserNotifications, CommonCrypto 等）。

## 当前规模

### 配置与脚本

| 文件 | 行数 | 职责 |
|---|---:|---|
| `Package.swift` | 30 | SPM 配置：macOS .v13、Swift 5 语言模式、`NetBar` executable target + `NetBarTests` test target |
| `Resources/Info.plist` | 32 | Bundle ID `local.codex.NetBar`，当前版本 `0.39.9` |
| `Resources/NetBar.entitlements` | 10 | App 沙盒与自动化相关 entitlements |
| `.github/workflows/release.yml` | 141 | tag 触发的 GitHub Release 构建、测试、打包与发布流程 |
| `Scripts/build-app.sh` | 117 | `swift build --disable-sandbox -c release` 后组装 `build/NetBar.app`，可选 codesign |
| `Scripts/package-release.sh` | 25 | build + release app 验证 + zip + sha256 |
| `Scripts/verify-release-app.sh` | 48 | 验证 `.app` 可执行文件、架构和签名形态 |
| `Scripts/generate-icon.swift` | 260 | CoreGraphics 程序化生成 AppIcon |

### Sources/NetBar

当前 `Sources/NetBar` 共 54 个 Swift 文件，约 16,742 行：

- 顶层核心文件 40 个
- `Sources/NetBar/Preferences/` 偏好设置子视图 14 个
- 最大文件：`StatusBarStyle.swift` 2054 行、`NetworkPopoverView.swift` 2004 行、`AppUpdater.swift` 1008 行、`StatusBarController.swift` 816 行、`NetworkMonitor.swift` 748 行

| 文件 | 行数 | 职责 |
|---|---:|---|
| `Main.swift` | 16 | `@main` 入口，创建 `AppDelegate` 并启动 `NSApplication.run()` |
| `AppDelegate.swift` | 235 | 初始化偏好、状态栏、历史、通知、宠物、更新器；配置主菜单、Dock/外观/语言 |
| `NetworkMonitor.swift` | 748 | 核心监控引擎：接口采样、应用流量采样、系统资源采样、历史记录和网络智能摘要 |
| `StatusBarController.swift` | 816 | `NSStatusItem` 控制器：状态栏渲染调度、详情窗口、右键菜单、RunCat 动画、通知/宠物联动 |
| `StatusBarStyle.swift` | 2054 | CoreGraphics 状态栏渲染引擎：设置模型、布局、签名 diff、文字/角色/特效绘制 |
| `StatusBarRenderCache.swift` | 70 | 状态栏图片和文字布局 LRU cache |
| `NetworkPopoverView.swift` | 2004 | SwiftUI 详情窗口：总览、趋势、接口、应用列表、系统资源、智能与历史展示；滚动内容懒构建、应用图标延迟解析 |
| `DetailsWindowController.swift` | 435 | 详情窗口创建、定位、外部点击关闭策略；打开后延迟刷新以避开首帧动画 |
| `AppUpdater.swift` | 1008 | 自动更新：`latest.json`/GitHub API、下载、SHA256、解压、架构/签名校验、自替换安装 |
| `AppPreferences.swift` | 398 | 全局偏好：Dock、语言、外观、排序、popover 位置、网络智能设置、开机启动 |
| `NetworkHistoryStore.swift` | 418 | 本地历史统计持久化、日汇总、Top 应用、动画播放计数 |
| `NetworkIntelligenceModels.swift` | 456 | 网络智能设置、异常事件、洞察卡片、日汇总模型 |
| `NetworkAnomalyDetector.swift` | 285 | 高流量、应用突增、断流/恢复、代理归因差异检测 |
| `NetworkIntelligenceCoordinator.swift` | 19 | 将异常事件分发到通知、宠物 cue 和每日摘要 |
| `NetworkNotificationController.swift` | 172 | macOS 通知授权、发送和冷却控制 |
| `ApplicationTrafficReader.swift` | 341 | 应用级流量读取：持久 `StreamingNettopReader` + one-shot fallback，解析 nettop CSV |
| `ApplicationResourceReader.swift` | 278 | 每应用 CPU/内存读取（`ps aux`）与系统资源摘要 |
| `SystemResourceReader.swift` | 242 | Mach/system API 系统内存、CPU tick、热状态读取 |
| `SystemMetricsReader.swift` | 236 | 动画速度可用的系统指标采样与映射 |
| `NetworkStatsReader.swift` | 102 | `getifaddrs` 网络接口读取、主接口识别、显示名映射 |
| `InterfaceStats.swift` | 119 | 接口、快照、应用流量状态等基础数据模型 |
| `ApplicationTrafficPresentation.swift` | 402 | 应用列表过滤、搜索、排序、归因状态和展示模型 |
| `NetworkHistoryPresentation.swift` | 114 | 历史窗口聚合和展示模型 |
| `StatusBarContextEvaluator.swift` | 159 | 智能状态栏上下文与角色推荐评估 |
| `RunCatAnimation.swift` | 437 | 内置角色定义、帧推进、速度映射、轮换播放 |
| `CustomCharacter*.swift` | 1163 | 自定义角色模型、存储、图片处理和渲染接入 |
| `Pet*.swift` | 878 | 宠物状态、控制器、技能与提醒 |
| `NetBarDesignSystem.swift` | 230 | SwiftUI 设计系统组件、颜色、卡片样式 |
| `Preferences/*.swift` | 2269 | 偏好设置窗口与各 Tab/Section 子视图 |

### Tests

当前测试共 2 个 Swift 文件、约 6,444 行、284 个测试：

| 文件 | 行数 | 职责 |
|---|---:|---|
| `Tests/NetBarTests/PreferencesAndPresentationTests.swift` | 4984 | 偏好、状态栏渲染、窗口布局、智能提醒、历史统计、自定义角色、内置角色资源、更新 manifest、宠物、应用列表展示 |
| `Tests/NetBarTests/SystemResourceTests.swift` | 1460 | 系统资源模型、采样策略、NetworkMonitor 集成、应用资源读取、streaming nettop 行为 |

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
       │    ├─ ApplicationResourceReading (ps aux, 协议可注入)
       │    ├─ SystemResourceReading (Mach API, 协议可注入)
       │    └─ NetworkHistoryStore + NetworkAnomalyDetector + NetworkInsightCenter
       ├─ StatusBarController
       │    ├─ StatusBarSettings + StatusBarDisplayRenderer + StatusBarRenderedImageCache
       │    ├─ RunCatAnimation + CustomCharacterStore
       │    ├─ DetailsWindowController → NetworkPopoverView
       │    └─ NetworkIntelligenceCoordinator → notifications + pet cues
       ├─ PreferencesWindowController → Preferences/*.swift
       ├─ PetController
       ├─ NetworkNotificationController
       └─ AppUpdater
```

**数据流**: `getifaddrs/nettop/ps/Mach` → Reader 协议 → `NetworkMonitor.@Published` → Combine/SwiftUI → `StatusBarController` / `NetworkPopoverView` / 通知 / 宠物。

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
2. **协议注入**：`NetworkStatsReading`、`ApplicationTrafficReading`、`ApplicationResourceReading`、`SystemResourceReading`、`LoginItemManaging`、通知中心等均可替换，测试优先用 mock。
3. **i18n 模式**：新增用户可见字符串使用 `appPreferences.text("中文", "English")` 或 `AppLanguage.text(...)` 双参数。
4. **偏好持久化**：`AppPreferences` 和 `StatusBarSettings` 多数属性通过 `didSet { save() }` 写入 UserDefaults。
5. **状态栏渲染**：CoreGraphics 生成 `NSImage`；`StatusBarRenderSignature` 做 diff；`StatusBarRenderedImageCache` 和文字 layout cache 避免重复绘制。
6. **采样节流**：应用级 `nettop` 只在详情窗口可见时启用，关闭后延迟暂停；低电量/锁屏会调整或停止采样。
7. **无 Storyboard/XIB**：窗口、菜单和 SwiftUI hosting 均纯代码创建。
8. **资源打包**：SPM target 不声明 resources；`.app` 资源由 `Scripts/build-app.sh` 从 `Resources/` 复制。

## 已知坑点

1. **`StatusBarStyle.swift` 很大**：修改渲染逻辑要精准定位，优先补测试覆盖签名、布局或像素行为。
2. **`NetworkPopoverView.swift` 很大**：详情页 UI 和展示逻辑集中，改动时注意不要引入布局回归。
3. **`AppUpdater.swift` 风险高**：涉及网络、zip、SHA256、架构/签名校验和自替换安装；发布相关改动必须跑测试和本地打包验证。
4. **`nettop` 进程依赖**：沙盒/系统版本差异可能影响输出和 spawn；streaming reader 依赖 `/usr/bin/script` 分配伪终端以减少缓冲。
5. **构建需 `--disable-sandbox`**：`build-app.sh` 已封装，不要手动拼装 `.app`。
6. **签名形态**：本地默认保留 SwiftPM linker-signed/ad-hoc 形态；正式分发如要公证，需要开发者签名和 hardened runtime 策略。
7. **版本发布一致性**：tag、`CHANGELOG.md`、Release notes、Info.plist 写入流程要保持一致；GitHub workflow 会在发布时按 tag 写 Info.plist。
8. **RunCat 资源硬编码**：内置角色定义在 `RunCatAnimation.swift`，需要同步维护 `Resources/RunCat/<id>/frame_N.png`。
9. **GUI 启动方式**：不要从 Codex/受限父进程直接执行 `build/NetBar.app/Contents/MacOS/NetBar`，AppKit 可能在 `HIServices _RegisterApplication` 阶段 `SIGABRT`；给用户试运行时优先让用户从 Finder/Terminal 用 `open build/NetBar.app` 启动。
10. **避免多开菜单栏实例**：不要用 `open -n build/NetBar.app`，除非明确要测多实例；误多开时先执行 `killall NetBar` 清理，再单实例启动。

## Agent 工作指南

- 先读 `PROJECT_MAP.md`，再动核心模块。
- 修改状态栏渲染先看 `StatusBarStyle.swift`、`StatusBarController.swift`、`StatusBarRenderCache.swift`。
- 新增偏好设置优先复用 `Preferences/*.swift` 的分组组件，并确认 UserDefaults key 和 reset 行为。
- 新增用户可见文案必须补中英文。
- 修改采样、历史、通知、更新或发布链路时必须跑 `swift test`。
- 修改 `.app` 打包、资源、签名、自动更新时还要跑 `./Scripts/build-app.sh` 和 `./Scripts/verify-release-app.sh build/NetBar.app`。
- 构建 App 必须用 `./Scripts/build-app.sh`；不要手动复制资源或拼 `.app`。
- 修改动画/角色时同步维护 `Resources/RunCat/` 帧图片、`RunCatAnimation.swift` 元数据和相关测试。
- 需要用户手测 App 时，不要从 Codex 直接执行 `Contents/MacOS/NetBar`；如果 Codex 环境无法通过 LaunchServices 启动，就说明原因并让用户在自己的 Terminal/Finder 里启动。
