# NetBar

NetBar 是一个免费的 macOS 菜单栏网络流量监控 App。它把实时下载、上传速度放进菜单栏，点击后可以查看网络趋势、接口明细、应用级流量、系统资源和网络提醒。

它适合想长期观察网络状态、排查网速异常、了解哪些应用正在使用网络的人。NetBar 使用 macOS 系统接口和系统自带工具读取统计数据，不抓包，不读取网页、请求、聊天、文件等网络内容，也不需要管理员权限。

## 为什么用 NetBar

- **一眼看见实时网速**：菜单栏直接显示当前下载 / 上传速度，不需要打开活动监视器。
- **知道谁在用网**：详情窗口展示应用级实时流量，并支持按实时流量、内存占用、CPU 占用查看。
- **发现异常更快**：支持高流量、应用突增、断流 / 恢复、代理 / VPN 归因差异等本地提醒。
- **趋势不只看瞬间**：内置最近趋势、今日估算和最近 7 天汇总，适合判断网络是不是持续异常。
- **轻量、透明、免费**：纯 Swift 实现，无外部依赖，不抓包，不需要管理员权限。
- **菜单栏可自定义**：支持多种菜单栏预设、字号、颜色、顺序、宽度、对齐、背景和动画角色。
- **适合长期挂着**：低流量、低电量、锁屏等场景会自动降低采样或暂停部分刷新，减少不必要的资源消耗。

## 主要功能

### 菜单栏实时监控

NetBar 会在菜单栏显示当前网络速度，默认展示下载和上传速率。你可以在偏好设置里切换不同显示模式，例如极简、上下行、总流量、应用关注和宠物模式。

菜单栏支持的自定义项包括：

- 下载 / 上传 / 总流量显示模式
- 单行或双行布局
- 自动宽度或手动宽度
- 字号、行距、文字颜色、背景颜色
- 下载 / 上传顺序和对齐方式
- 透明背景和紧凑样式
- RunCat 动画角色，动画速度会随网络活动变化

### 详情窗口

点击菜单栏项目后，NetBar 会打开详情窗口，集中展示当前网络状态：

- 总下载 / 上传速度
- 最近趋势图
- 网络接口明细
- Wi-Fi、VPN、Bridge 等接口识别
- 每个接口的实时上下行、累计收发流量、收发包数
- 应用级实时流量列表
- 应用级归因覆盖率说明
- 系统资源概览，包括内存、CPU、进程数和热状态

### 应用级流量

NetBar 通过 macOS 自带的 `/usr/bin/nettop` 获取应用级网络统计，并结合 `ps` 补充每个进程的内存和 CPU 数据。

应用列表支持：

- 实时流量
- 内存占用
- CPU 占用
- 应用搜索
- 系统进程隐藏
- 代理、VPN、子进程和系统服务标记

需要注意的是，应用级流量和接口总流量不一定完全一致。代理、VPN、浏览器 Helper、系统网络扩展或子进程可能会承接真实流量，NetBar 会尽量给出归因提示，帮助你理解差异。

### 网络智能提醒

NetBar 可以在本地检测一些常见网络状态变化，并通过 macOS 通知提醒你：

- 当前总流量过高
- 某个应用流量突然升高
- 网络断流或恢复
- 代理 / VPN 导致应用归因差异

首次使用时可以选择是否开启系统通知。所有提醒都可以在偏好设置中关闭。

### 历史统计

NetBar 会基于本地采样维护轻量历史数据，用于趋势判断：

- 最近趋势窗口
- 今日估算流量
- 最近 7 天汇总
- 实时 Top 应用
- 今日累计 Top 应用

这些数据用于观察趋势，不等同于运营商账单或系统网络用量报表。

### 外观与体验

NetBar 支持：

- 中文和英文界面
- 跟随系统、浅色、深色外观
- 显示 Dock 图标或仅保留菜单栏
- 开机启动
- 自动更新检查
- 内置 RunCat 动画角色
- 自定义角色图片处理和存储

## 隐私与权限

NetBar 的设计目标是只读取必要的系统统计数据。

- 不抓包
- 不读取网络请求内容
- 不读取网页内容
- 不读取聊天内容
- 不需要管理员权限
- 不需要安装内核扩展或系统扩展
- 不上传你的网络数据

NetBar 使用的数据来源主要是：

- `getifaddrs`：读取 macOS 网络接口累计计数器，用于计算实时接口速率。
- `/usr/bin/nettop`：读取 macOS 自带的应用级网络统计。
- `ps`：读取应用进程的 CPU 和内存信息。
- Mach / SystemConfiguration：读取系统资源和主网络接口信息。

## 下载安装

你可以从 GitHub Releases 下载最新版本：

[下载 NetBar 最新版本](https://github.com/sunnyhot/NetBar/releases/latest)

安装方式：

1. 下载 `NetBar.app.zip`。
2. 解压得到 `NetBar.app`。
3. 将 `NetBar.app` 拖入 `/Applications`。
4. 双击打开，或右键选择「打开」。

## macOS 提示“已损坏”的解决方法

如果从 GitHub Release 下载后，macOS 提示「NetBar 已损坏，无法打开」，通常是因为 App 未经过 Apple 公证，Gatekeeper 阻止了首次启动。

可以在终端执行：

```bash
xattr -cr /Applications/NetBar.app
```

如果你把 App 放在其他位置，请把路径替换为实际的 `NetBar.app` 路径。

也可以尝试右键点击 App，选择「打开」，然后在弹窗中再次点击「打开」。

## 系统要求

- macOS 13.0 或更高版本
- Apple Silicon 或 Intel Mac
- 构建源码需要 Xcode 15 或更高版本，以及 Swift 6.0 工具链

源码以 Swift 5 模式编译，项目使用 Swift Package Manager 管理。

## 从源码构建

克隆仓库后，在项目根目录执行：

```bash
./Scripts/build-app.sh
```

构建产物会生成在：

```text
build/NetBar.app
```

运行构建后的 App：

```bash
open build/NetBar.app
```

开发时也可以直接运行可执行目标：

```bash
swift run NetBar
```

运行测试：

```bash
swift test
```

## 打包 Release

执行：

```bash
./Scripts/package-release.sh
```

产物会生成在：

```text
dist/NetBar.app.zip
dist/NetBar.app.zip.sha256
```

当前构建脚本会使用 ad-hoc codesign 进行本地签名。正式分发时建议使用开发者证书签名并进行 Apple notarization，以减少用户首次打开时的 Gatekeeper 提示。

## 技术实现

NetBar 是纯 Swift macOS App，无第三方依赖，主要使用 AppKit、SwiftUI、Combine、Foundation、SystemConfiguration 和 Mach API。

核心数据流如下：

```text
getifaddrs / nettop / ps
  -> Reader 协议
  -> NetworkMonitor
  -> @Published 快照
  -> Combine 订阅
  -> StatusBarController
  -> NSStatusItem 图像
```

关键模块：

- `NetworkMonitor`：核心监控引擎，负责接口速率、应用流量、系统资源和历史数据。
- `NetworkStatsReader`：读取网络接口计数器，并识别主网络接口。
- `ApplicationTrafficReader`：通过 `nettop` 读取应用级流量。
- `ApplicationResourceReader`：通过 `ps` 读取应用级 CPU 和内存。
- `SystemResourceReader`：读取系统内存、CPU 和热状态。
- `StatusBarController`：管理 macOS 菜单栏项目、点击交互和渲染刷新。
- `StatusBarStyle`：CoreGraphics 渲染引擎，负责菜单栏文字、背景和角色绘制。
- `NetworkPopoverView`：SwiftUI 详情窗口内容。
- `AppPreferences`：偏好设置和 UserDefaults 持久化。
- `AppUpdater`：基于 GitHub Releases 的自动更新检查与安装。

## 项目结构

```text
NetBar
├── Sources/NetBar
│   ├── Main.swift
│   ├── AppDelegate.swift
│   ├── NetworkMonitor.swift
│   ├── StatusBarController.swift
│   ├── StatusBarStyle.swift
│   ├── NetworkPopoverView.swift
│   ├── Preferences/
│   └── ...
├── Resources
│   ├── Info.plist
│   ├── NetBar.entitlements
│   └── RunCat/
├── Scripts
│   ├── build-app.sh
│   ├── package-release.sh
│   └── generate-icon.swift
├── Tests/NetBarTests
├── Package.swift
└── README.md
```

更详细的架构说明可以查看 `PROJECT_MAP.md`。

## 常见问题

### 为什么应用流量总和小于菜单栏总流量？

菜单栏总流量来自网络接口计数器，表示网卡层面的总收发速度。应用列表来自 `nettop` 的进程统计。代理、VPN、系统服务、浏览器 Helper、网络扩展和子进程都可能影响归因，所以两者不会总是完全相等。

### NetBar 会不会看到我访问了什么网站？

不会。NetBar 不抓包，也不读取请求内容。它只读取系统已经汇总好的字节数、包数、进程名、CPU、内存等统计信息。

### 为什么历史统计只是估算？

历史统计基于 App 本地采样。如果 App 没有运行、系统休眠、锁屏暂停、采样间隔变化，都会影响统计精度。因此它适合判断趋势，不适合作为账单级精确数据。

### 为什么需要 `--disable-sandbox` 构建？

构建脚本需要组装 `.app`、复制资源并进行本地签名。运行时还需要访问系统工具，例如 `nettop` 和 `ps`。因此本项目的构建脚本使用 `swift build --disable-sandbox -c release`。

### 为什么没有上架 Mac App Store？

NetBar 依赖 `nettop`、`ps` 等系统工具读取本地统计数据，并包含自更新流程。目前更适合通过 GitHub Releases 分发。

## 反馈与贡献

欢迎通过 GitHub Issues 反馈问题、建议功能或描述你的使用场景：

[提交反馈](https://github.com/sunnyhot/NetBar/issues)

如果你想参与开发，可以先运行：

```bash
swift test
./Scripts/build-app.sh
```

提交修改时请尽量保持以下约定：

- UI 和用户可见文案同时考虑中文和英文。
- 新增偏好项需要持久化，并确认默认值合理。
- 修改状态栏渲染时重点检查 `StatusBarStyle.swift`。
- 修改网络读取逻辑时尽量保持协议可注入，方便测试。
- 修改发布流程时同步检查版本号、更新说明和打包产物。

## 许可与使用

NetBar 当前面向个人免费使用。如果你计划复制、修改或二次分发代码，请以仓库后续补充的 LICENSE 文件为准。
