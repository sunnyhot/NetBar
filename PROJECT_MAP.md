     1|# AGENTS.md — NetBar
     2|
     3|## 项目简介
     4|
     5|macOS 菜单栏网络流量监控 App，纯 Swift 编写，无外部依赖。
     6|- 读取 macOS 网络接口计数器（getifaddrs），按 1 秒间隔计算实时速率
     7|- 通过 `/usr/bin/nettop` 获取应用级流量（每 5 秒采样）
     8|- 不抓包、不读网络内容、不需要管理员权限
     9|- 支持中英文双语、浅色/深色主题、RunCat 动画角色、自动更新
    10|
    11|**技术栈**: Swift 5 (SPM swift-tools-version 6.0) | AppKit + SwiftUI | macOS 13+
    12|**无外部依赖**，纯系统框架（AppKit, SwiftUI, Combine, Foundation, SystemConfiguration）
    13|
    14|## 文件结构
    15|
    16|### 配置文件
    17|| 文件 | 行数 | 职责 |
    18||---|---|---|
    19|| `Package.swift` | 30 | SPM 配置：macOS .v13 平台，swiftLanguageMode .v5，单 executableTarget + testTarget |
    20|| `Resources/Info.plist` | 33 | Bundle ID `local.codex.NetBar`，版本 0.15.0 (build 22) |
    21|| `.gitignore` | 6 | 忽略 .build/ build/ dist/ 和 AppIcon 中间文件 |
    22|
### Sources/NetBar — 核心源码（39 个文件）

| 文件 | 行数 | 职责 |
|---|---|---|
| `Main.swift` | 14 | `@main` 入口：创建 AppDelegate 并启动 NSApplication.run() |
| `AppDelegate.swift` | 166 | NSApplicationDelegate：初始化 StatusBarController/PreferencesWindowController，配置主菜单（中英双语），管理 Dock 图标/外观/语言偏好 |
| `AppPreferences.swift` | 339 | 全局偏好管理（ObservableObject）：Dock 图标、隐藏系统进程、排序模式、语言、外观、开机启动、onboarding 状态 |
| `Formatters.swift` | 76 | `ByteFormat` 工具：速度/字节数/包数格式化 + `SystemResourceFormat`：内存/CPU/热状态格式化 |
| `InterfaceStats.swift` | 115 | 数据模型：InterfaceStats/InterfaceRate/NetworkSnapshot/ApplicationTrafficRate（含 residentMemory/cpuPercentage）/ApplicationTrafficState 等 |
| `NetworkStatsReader.swift` | 89 | 网络接口读取（getifaddrs + if_data），识别主接口（SCDynamicStore） |
| `ApplicationTrafficReader.swift` | 118 | 应用流量读取（`/usr/bin/nettop -P -L 1 -x`），解析 CSV 输出 |
| `SystemResourceReader.swift` | 229 | 系统资源读取层：MemoryUsage/CPUUsage/ThermalInfo/CPUTickSample/SystemResourceSnapshot 模型 + SystemResourceReading 协议 + LiveSystemResourceReader (Mach host_statistics) |
| `ApplicationResourceReader.swift` | 208 | 每应用资源读取：ProcessResourceUsage 模型 + ApplicationResourceReading 协议 + PSApplicationResourceReader (`ps aux`) + SystemResourceReader + SystemResourceSummary |
| `ApplicationTrafficPresentation.swift` | 129 | 应用列表展示逻辑：过滤系统进程、搜索、5 种排序模式 |
| `NetworkMonitor.swift` | 497 | **核心监控引擎**：1s 定时采样接口速率，5s 定时采样应用流量（含每应用内存/CPU），汇总系统资源，维护 90s 历史记录 |
| `StatusBarController.swift` | 425 | 状态栏控制器：NSStatusItem，渲染自定义图像，左键详情窗口，右键菜单 |
| `StatusBarStyle.swift` | 1609 | **最大文件**：CoreGraphics 渲染引擎，StatusBarSettings + StatusBarDisplayRenderer |
| `DetailsWindowController.swift` | 378 | 详情窗口：NSWindow 创建/定位，嵌入 SwiftUI NetworkPopoverView |
| `NetworkPopoverView.swift` | 1001 | SwiftUI 详情视图：总览、90s 趋势图、接口明细、应用级流量列表 + SystemResourceCard（内存/CPU/进程数） |
| `PreferencesWindowController.swift` | 1277 | 偏好设置窗口 UI（含 GitHub 地址 + 更新弹窗） |
| `RunCatAnimation.swift` | 314 | RunCat 动画系统：20+ 角色定义，FPS 随网速变化 2-24fps |
| `AppUpdater.swift` | 674 | 自动更新：GitHub Releases API 检查/下载/解压/codesign 验证/自替换安装 |
    43|
    44|### Scripts
    45|| 文件 | 行数 | 职责 |
    46||---|---|---|
    47|| `Scripts/build-app.sh` | 35 | `swift build --disable-sandbox -c release` → 组装 .app → codesign |
    48|| `Scripts/package-release.sh` | 20 | build + ditto 打 zip + shasum |
    49|| `Scripts/generate-icon.swift` | 210 | CoreGraphics 程序化生成 AppIcon |
    50|
    51|### Tests
    52|| 文件 | 行数 | 职责 |
    53||---|---|---|
| `Tests/NetBarTests/PreferencesAndPresentationTests.swift` | 2131 | 偏好和展示逻辑测试 |
| `Tests/NetBarTests/SystemResourceTests.swift` | 393 | 系统资源模型、格式化、每应用资源、NetworkMonitor 集成测试 |

## 构建命令
    57|
    58|```bash
    59|./Scripts/build-app.sh          # → build/NetBar.app
    60|swift run NetBar                 # 开发运行
    61|swift test                       # 运行测试
    62|./Scripts/package-release.sh    # → dist/NetBar.app.zip + sha256
    63|```
    64|
    65|**构建要求**: Xcode 15+, macOS 13+, Swift 6.0 工具链（源码以 Swift 5 模式编译）
    66|
    67|## 架构概览
    68|
    69|```
    70|Main.swift (@main)
    71|  └─ AppDelegate
       ├─ NetworkMonitor (核心引擎, 1s/5s 定时采样)
       │    ├─ SystemNetworkStatsReader (getifaddrs, 协议可注入)
       │    ├─ NettopApplicationTrafficReader (nettop, 协议可注入)
       │    ├─ ApplicationResourceReading (ps aux, 协议可注入) — 每应用内存/CPU
       │    └─ SystemResourceReading (Mach API, 协议可注入) — 系统内存/CPU/热状态
       ├─ StatusBarController (NSStatusItem + CoreGraphics 渲染)
       │    ├─ StatusBarSettings + StatusBarDisplayRenderer
       │    └─ RunCatAnimation (角色动画)
       ├─ DetailsWindowController → NetworkPopoverView (SwiftUI)
       ├─ PreferencesWindowController (设置 UI)
       └─ AppUpdater (GitHub Releases 自更新)
```

**数据流**: `getifaddrs/nettop/ps` → `Reader协议` → `NetworkMonitor.@Published` → `Combine.sink` → `StatusBarController` → `NSStatusItem.image`
    84|
    85|## 关键约定
    86|
    87|1. **@MainActor 全局使用** — UI 类和 ObservableObject 均标记 `@MainActor`，后台读取用 `Task.detached(priority: .utility)`
    88|2. **协议注入** — NetworkStatsReading/ApplicationTrafficReading/LoginItemManaging 通过协议抽象，init 默认实现可替换
    89|3. **i18n 模式** — 统一 `appPreferences.text("简体中文", "English")` 双参数，自动跟随系统语言
    90|4. **偏好持久化** — AppPreferences 通过 `didSet { save() }` 自动写 UserDefaults，key 前缀 `app.`
    91|5. **状态栏渲染** — CoreGraphics 绘制完整 NSImage（文字+猫动画帧），`StatusBarRenderSignature` 做 diff 避免重绘
    92|6. **无 Storyboard/XIB** — 纯代码创建窗口菜单，SwiftUI 通过 NSHostingController 嵌入
    93|7. **Combine 响应式** — `.$property.sink { }` 监听偏好变化
    94|
    95|## 已知坑点
    96|
    97|1. **StatusBarStyle.swift 巨大 (1370 行)** — CoreGraphics 渲染全在一个文件，修改需精确定位
    98|2. **PreferencesWindowController.swift 近千行** — 偏好设置 UI 缺少拆分
    99|3. **nettop 进程依赖** — 沙盒环境可能无法 spawn；nettop 输出格式变化会导致解析失败
   100|4. **构建需 `--disable-sandbox`** — 运行时需访问系统工具
   101|5. **自更新机制** — 临时 shell 脚本实现替换安装，需 codesign --force --deep
   102|6. **ad-hoc 签名** — 正式分发需替换为开发者签名
   103|7. **版本号三处维护** — Info.plist + AppDelegate about 面板 + Git tag
   104|8. **GitHub API 限流** — 未认证 60 次/小时
   105|9. **RunCat 资源硬编码** — 角色定义在代码中，需同步维护 Resources/RunCat/ 帧图片
   106|