# AGENTS.md — NetBar

## 项目概览

macOS 菜单栏网络流量监控 App。纯 Swift 编写，无外部依赖。
- 读取 macOS 网络接口计数器（getifaddrs），1 秒间隔计算实时速率
- 通过 `/usr/bin/nettop` 获取应用级流量（每 5 秒采样）
- 不抓包、不读网络内容、不需要管理员权限
- 支持中英文双语、浅色/深色主题、RunCat 动画角色、自动更新

**技术栈**: Swift 5 (SPM swift-tools-version 6.0) | AppKit + SwiftUI | macOS 13+
**无外部依赖**，纯系统框架（AppKit, SwiftUI, Combine, Foundation, SystemConfiguration）

## 目录结构与行数

### 配置文件
| 文件 | 行数 | 职责 |
|---|---|---|
| `Package.swift` | 30 | SPM 配置：macOS .v13 平台，swiftLanguageMode .v5，executableTarget + testTarget |
| `Resources/Info.plist` | 33 | Bundle ID `local.codex.NetBar`，版本 0.29.3 |
| `Resources/NetBar.entitlements` | — | 沙盒权限 |
| `.gitignore` | 6 | 忽略 .build/ build/ dist/ 和 AppIcon 中间文件 |

### Sources/NetBar — 核心源码（39 文件，~11100 行）
| 文件 | 行数 | 职责 |
|---|---|---|
| `Main.swift` | 16 | `@main` 入口：创建 AppDelegate，启动 NSApplication.run() |
| `AppDelegate.swift` | 166 | NSApplicationDelegate：初始化各控制器，配置主菜单（中英双语），管理 Dock/外观/语言 |
| `StatusBarStyle.swift` | 1609 | **最大文件** — CoreGraphics 渲染引擎：StatusBarSettings + StatusBarDisplayRenderer |
| `PreferencesWindowController.swift` | 1277 | 偏好设置窗口 UI（含 GitHub 地址 + 更新弹窗） |
| `NetworkPopoverView.swift` | 1001 | SwiftUI 详情视图：总览、90s 趋势图、接口明细、应用级流量列表 + 系统资源卡片 |
| `AppUpdater.swift` | 674 | 自动更新：GitHub Releases API 检查/下载/解压/codesign 验证/自替换安装 |
| `StatusBarController.swift` | 425 | 状态栏控制器：NSStatusItem，渲染自定义图像，左键详情右键菜单 |
| `CustomCharacterImageProcessor.swift` | 407 | 自定义角色图片处理器 |
| `DetailsWindowController.swift` | 378 | 详情窗口：NSWindow 创建/定位，嵌入 SwiftUI NetworkPopoverView |
| `SystemResourceReader.swift` | 229 | 系统资源读取层：MemoryUsage/CPUUsage/ThermalInfo 模型 + SystemResourceReading 协议 + LiveSystemResourceReader (Mach API) |
| `CustomCharacterStore.swift` | 341 | 自定义角色存储管理 |
| `RunCatAnimation.swift` | 314 | RunCat 动画系统：20+ 角色，FPS 随网速变化 2-24fps |
| `ApplicationResourceReader.swift` | 208 | 每应用资源读取：ProcessResourceUsage 模型 + ApplicationResourceReading 协议 + PSApplicationResourceReader (`ps aux`) + SystemResourceReader + SystemResourceSummary |
| `NetworkMonitor.swift` | 497 | **核心监控引擎**：1s 接口采样 + 5s 应用流量采样（含每应用内存/CPU）+ 系统资源汇总，维护 90s 历史 |
| `PetController.swift` | 292 | 宠物控制器（虚拟宠物功能） |
| `PetState.swift` | 266 | 宠物状态模型 |
| `AppPreferences.swift` | 339 | 全局偏好（ObservableObject）：Dock/语言/外观/排序/开机启动/onboarding |
| `CustomCharacter.swift` | 214 | 自定义角色定义 |
| `NetBarDesignSystem.swift` | 230 | 设计系统常量 |
| `StatusBarPopoverContentView.swift` | 193 | 状态栏弹出内容视图 |
| `ApplicationTrafficReader.swift` | 118 | 应用流量读取（`/usr/bin/nettop -P -L 1 -x`），解析 CSV |
| `InterfaceStats.swift` | 115 | 数据模型：InterfaceStats/InterfaceRate/NetworkSnapshot/ApplicationTrafficRate（含 residentMemory/cpuPercentage）等 |
| `ApplicationTrafficPresentation.swift` | 129 | 应用列表展示逻辑：过滤/搜索/5 种排序 |
| `NetworkStatsReader.swift` | 89 | 网络接口读取（getifaddrs + if_data），识别主接口（SCDynamicStore） |
| `PetSkill.swift` | 70 | 宠物技能定义 |
| `Formatters.swift` | 76 | ByteFormat 工具 + SystemResourceFormat（内存/CPU/热状态格式化） |
| `NetworkInterfaceClassifier.swift` | 24 | 网络接口分类器 |

### Scripts（327 行）
| 文件 | 行数 | 职责 |
|---|---|---|
| `Scripts/generate-icon.swift` | 260 | CoreGraphics 程序化生成 AppIcon |
| `Scripts/build-app.sh` | 46 | `swift build --disable-sandbox -c release` → 组装 .app → codesign |
| `Scripts/package-release.sh` | 21 | build + ditto zip + shasum |

### Tests（2524 行）
| 文件 | 行数 | 职责 |
|---|---|---|
| `Tests/NetBarTests/PreferencesAndPresentationTests.swift` | 2131 | 偏好和展示逻辑测试 |
| `Tests/NetBarTests/SystemResourceTests.swift` | 393 | 系统资源模型、格式化、每应用资源、NetworkMonitor 集成测试 |

### Resources/RunCat/
20+ 角色动画帧目录（cat, dog, parrot 等），每个角色含多帧 PNG。

## 构建与运行命令

```bash
./Scripts/build-app.sh          # → build/NetBar.app
swift run NetBar                 # 开发运行
swift test                       # 运行测试
./Scripts/package-release.sh    # → dist/NetBar.app.zip + sha256
open build/NetBar.app            # 直接运行
```

**构建要求**: Xcode 15+, macOS 13+, Swift 6.0 工具链（源码以 Swift 5 模式编译）

## 架构与数据流

```
Main.swift (@main)
  └─ AppDelegate
       ├─ NetworkMonitor (核心引擎, 1s/5s 定时采样)
       │    ├─ SystemNetworkStatsReader (getifaddrs, 协议可注入)
       │    ├─ NettopApplicationTrafficReader (nettop, 协议可注入)
       │    ├─ ApplicationResourceReading (ps aux, 协议可注入) — 每应用内存/CPU
       │    └─ SystemResourceReading (Mach API, 协议可注入) — 系统内存/CPU/热状态
       ├─ StatusBarController (NSStatusItem + CoreGraphics 渲染)
       │    ├─ StatusBarSettings + StatusBarDisplayRenderer
       │    └─ RunCatAnimation (角色动画)
       ├─ PetController (虚拟宠物系统)
       ├─ DetailsWindowController → NetworkPopoverView (SwiftUI)
       ├─ PreferencesWindowController (设置 UI)
       └─ AppUpdater (GitHub Releases 自更新)
```

**数据流**: `getifaddrs/nettop/ps` → `Reader协议` → `NetworkMonitor.@Published` → `Combine.sink` → `StatusBarController` → `NSStatusItem.image`

## 关键约定

1. **@MainActor 全局使用** — UI 类和 ObservableObject 均标记 `@MainActor`，后台读取用 `Task.detached(priority: .utility)`
2. **协议注入** — NetworkStatsReading/ApplicationTrafficReading/ApplicationResourceReading/SystemResourceReading/LoginItemManaging 通过协议抽象，init 默认实现可替换
3. **i18n 模式** — 统一 `appPreferences.text("简体中文", "English")` 双参数
4. **偏好持久化** — AppPreferences 通过 `didSet { save() }` 自动写 UserDefaults，key 前缀 `app.`
5. **状态栏渲染** — CoreGraphics 绘制 NSImage，`StatusBarRenderSignature` 做 diff 避免重绘
6. **无 Storyboard/XIB** — 纯代码创建窗口菜单，SwiftUI 通过 NSHostingController 嵌入
7. **Combine 响应式** — `.$property.sink { }` 监听偏好变化

## 已知坑点

1. **StatusBarStyle.swift 巨大 (1609 行)** — CoreGraphics 渲染全在一个文件，修改需精确定位
2. **PreferencesWindowController.swift 近千行 (1277)** — 偏好设置 UI 缺少拆分
3. **nettop 进程依赖** — 沙盒环境可能无法 spawn；nettop 输出格式变化会导致解析失败
4. **构建需 `--disable-sandbox`** — 运行时需访问系统工具
5. **自更新机制** — 临时 shell 脚本实现替换安装，需 codesign --force --deep
6. **ad-hoc 签名** — 正式分发需替换为开发者签名
7. **版本号三处维护** — Info.plist + AppDelegate about 面板 + Git tag
8. **GitHub API 限流** — 未认证 60 次/小时

## Agent 工作指南

- 修改 UI 渲染逻辑时先看 `StatusBarStyle.swift`，它是渲染引擎核心
- 新增偏好设置时注意 `AppPreferences` 的 `didSet { save() }` 自动持久化
- 新增 i18n 字符串必须用 `appPreferences.text("中文", "English")` 双参数
- 测试运行用 `swift test`，测试文件在 `Tests/NetBarTests/`
- 构建 App 必须用 `./Scripts/build-app.sh`，不要手动 `swift build`
- 修改动画/角色时同步维护 `Resources/RunCat/` 帧图片和 `RunCatAnimation.swift` 定义
- 参考 `PROJECT_MAP.md` 获取更详细的架构说明
