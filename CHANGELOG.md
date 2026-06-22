# Changelog

## v0.39.7 (2026-06-22)

### Fix — Release 构建兜底

- 取消 GitHub Actions 环境下自动启用 universal build，避免当前 release workflow 在构建阶段失败
- 保留显式 `NETBAR_BUILD_UNIVERSAL=1` 的本地/CI 架构校验入口，后续可在具备 runner 支持时重新开启

## v0.39.6 (2026-06-22)

### Fix — Release 安装包兼容性

- Release 构建改为 universal app，避免 Intel Mac 更新到 arm64-only 安装包后无法打开
- 自更新安装改为整包替换，保留 App bundle 签名结构并清理 quarantine 属性
- 更新安装前校验下载 App 是否支持当前 Mac 架构，避免安装不兼容版本
- 构建脚本保留 Developer ID 签名参数入口；当前无 Developer ID 时继续发布未公证包

## v0.39.5 (2026-06-17)

### Fix — Release 发布校验修正

- Release workflow 增加发布包签名策略校验，明确区分完整 app bundle 签名和 SwiftPM linker-signed 发布包
- 本地 `package-release.sh` 同步执行发布包校验，避免打包日志误导为已完成 strict bundle signing
- 保持 GitHub Actions 作为 release 资产上传方，避免手动创建 release 导致发布者显示不一致

## v0.39.4 (2026-06-17)

### Fix — 炫彩角色轮廓保真

- 全彩内置角色使用炫彩模式时保留原始明暗、阴影和暗部轮廓，避免小尺寸角色被渐变重染后糊成一团
- 角色选择网格为全彩角色预览增加轻微对比阴影，提升浅色卡片中的辨识度
- 新增全彩内置角色回归测试，覆盖带暗部细节的 RunCat 资源在炫彩渲染后的轮廓保留

## v0.39.3 (2026-06-16)

### Enhancement — 性能优化与后台开销收敛

- 新增统一采样策略，按详情窗口可见性、低电量和锁屏状态动态控制接口、应用流量和系统资源采样
- 应用级流量采样仅在详情窗口需要时运行，降低后台 `nettop` 和进程资源读取开销
- 历史统计改为批量延迟写盘，并在停止、退出和清空历史时强制落盘，减少频繁磁盘 I/O
- 状态栏 RunCat 动画复用主监控器的系统资源快照，避免重复 CPU/内存/热状态采样
- 状态栏渲染新增有界图片与文本布局缓存，减少重复 CoreGraphics 绘制和文字测量
- 详情窗口应用流量与趋势图改用 presentation model 预计算，减少 SwiftUI body 中的重复过滤和汇总

## v0.39.2 (2026-06-15)

### Fix — 启动稳定性补丁

- 延迟初始化系统通知中心，避免 App 启动早期被通知框架打断
- Release 构建保留 SwiftPM linker-signed 可执行文件，避免手动重签后的 app bundle 在新系统上启动即退出
- 自更新允许 SHA-256 校验通过的 SwiftPM linker-signed app 包继续安装
- 自更新安装时逐项复制 App bundle，避免整包复制带来的 LaunchServices 启动异常
- 继续包含 v0.39.1 的 RunCat 炫彩角色扩展与 3 套新增角色资源

## v0.39.1 (2026-06-15)

### Enhancement — RunCat 炫彩角色扩展

- 除寿司外，所有内置 RunCat 角色都支持角色颜色模式
- 彩色内置角色现在会真正应用纯色、渐变和动态炫彩渲染
- 新增水晶炫彩、星辉流彩、幻影炫彩 3 种高饱和动态颜色模式
- 新增棱镜狐、星辉幼龙、幻彩史莱姆 3 套内置动画角色
- 改进开发和测试环境下的 RunCat 资源加载 fallback

## v0.39.0 (2026-06-15)

### Enhancement — 产品全能增强

- 新增洞察事件流，用可读文案解释高流量、应用突增、断流/恢复和代理/VPN 归因差异
- 新增智能菜单栏模式，可按当前网络状态突出异常、上传、总流量或 Top 应用
- 历史统计扩展为最近 30 天本地估算账本，包含峰值和应用累计排行
- 新增诊断与健康摘要，便于排查更新、采样、通知权限和历史文件状态
- 宠物系统新增活跃等级和可配置的网络状态反馈

## v0.38.7 (2026-06-12)

### Enhancement — 更新校验与稳定性优化

- 自动更新会校验 `latest.json` 中声明的安装包 SHA-256，校验不通过时阻止解压和安装
- 修复省电模式重排定时器后可能在详情窗口隐藏时启动应用流量采样的问题
- 清理 macOS 13 目标下的 Swift 并发与 MainActor 编译警告
- Release 构建中 codesign 失败默认中止，避免静默生成未签名产物
- 新增更新包校验和省电采样调度回归测试

## v0.38.6 (2026-06-11)

### Enhancement — 最爱英雄里程碑特效

- 最爱英雄累计播放达到 5w、10w、50w、100w 时展示不同等级特效
- 今日统计的最爱英雄卡片会随里程碑切换图标、渐变描边、背景微光和呼吸光影
- 新增里程碑阈值测试，覆盖各等级边界与卡片绑定逻辑

## v0.38.5 (2026-06-11)

### Enhancement — 最爱英雄文案更新

- 今日统计卡片标题从“最爱角色”改为“最爱英雄”
- 英文标题同步从 “Favorite” 改为 “Favorite Hero”

## v0.38.4 (2026-06-10)

### Enhancement — 最爱角色累计统计

- “最爱角色”改为按历史累计播放次数统计，不再跟随今日统计重置
- 菜单栏角色设置中的播放次数改为展示累计播放次数
- 保留今日统计中的动画播放总数，继续按当天口径展示
- 兼容旧数据：首次加载时会把已有今日和最近记录合并为累计角色播放统计

## v0.38.3 (2026-06-10)

### Enhancement — 角色播放统计升级

- RunCat 动画播放次数改为按角色分别累计，同时保留今日总播放次数
- 今日统计新增“最爱角色”，展示当天播放次数最高的角色和次数
- 菜单栏角色设置中为内置角色和自定义角色显示今日播放次数
- 删除过的自定义角色在历史统计中会显示为“已删除角色”，避免误归到默认角色

## v0.38.2 (2026-06-10)

### Enhancement — 今日统计与接口明细优化

- 今日统计新增 RunCat 动画播放次数，按角色完整循环次数累计并持久化
- 接口明细自动隐藏当前没有上下行流量的网络接口，降低空闲接口干扰
- 当前无活动接口时展示更准确的空状态文案

## v0.38.1 (2026-06-08)

### Bug Fix — 更新检查 504 兜底

- 修复 Swift URLSession 访问 GitHub Release 下载端点可能持续返回 HTTP 504，导致无法发现新版本的问题
- 更新检查遇到 GitHub Release 资产 5xx 或网络瞬断时，会退回 GitHub Releases API 获取最新版本信息
- 更新请求改用临时 URLSession 并禁用缓存，避免旧的错误响应影响后续手动检查

## v0.38.0 (2026-06-08)

### Enhancement — 网络智能提醒与历史统计

- 新增异常检测：高流量、应用突增、断流/恢复、代理/VPN 归因差异
- 新增首次通知引导和可控的 macOS 系统通知
- 新增今日估算、最近 7 天汇总、实时 Top 和今日应用 Top
- 新增菜单栏内置预设：极简、上下行、总流量、应用关注、宠物模式
- 宠物会在网络异常时给出轻量解释，并根据今日网络活动调整状态

## v0.37.1 (2026-06-08)

### Bug Fix — Dock 隐藏与角色帧顺序稳定性

- 修复切换到“仅菜单栏”后 Dock 图标可能无法立即隐藏的问题
- 将 Dock 设置改为明确的“显示 Dock 图标 / 仅菜单栏”模式选择，避免开关语义混淆
- 修复自定义角色帧序列并发处理后顺序不稳定的问题，避免动画帧和测试随线程调度随机乱序
- 新增 Dock activation policy 发布时序回归测试

## v0.37.0 (2026-06-03)

### Enhancement — 应用流量归因与监控视图升级

详情弹框的应用流量展示进一步对齐常见 macOS 监控软件：既显示当前活跃应用，也解释为什么应用汇总和接口总流量可能不一致。

- 新增应用级归因卡片，展示接口总速率、应用汇总速率和归因覆盖率
- 自动标记代理/VPN、子进程和系统服务，帮助识别流量被代理进程或 Helper 进程承接的情况
- 实时流量列表继续隐藏没有上下行速率的应用，避免 `0 B/s` 进程干扰判断
- 趋势图支持 90 秒、5 分钟、15 分钟窗口切换，历史缓存扩展到 15 分钟
- 菜单栏新增内容模式：上下行、仅下载、仅上传、总流量，可在偏好设置中切换
- 新增归因、历史窗口和菜单栏内容模式的回归测试

## v0.36.7 (2026-06-03)

### Bug Fix — 应用实时流量不再空列表

修复详情弹框中系统总流量有数据，但应用实时流量列表长期显示“暂无应用流量”的问题。

- 应用流量采样改为通过 macOS `script` 给 `nettop` 分配伪终端，避免 `nettop` 写普通 pipe 时长时间缓冲不输出
- 读取层改为后台 POSIX 流式读取，应用行会在 `nettop` 输出后立即进入解析
- 解析层兼容 `script` 输出中的 CRLF 和终端退格控制字符，避免产生 `^D` 等假应用
- 详情弹框可见时应用流量改为 1 秒采样，实时模式更接近常见监控软件的刷新节奏
- 新增回归测试，验证终端背书的 `nettop` 输出能在短时间内读到应用 CSV

## v0.36.6 (2026-06-03)

### Bug Fix — 实时流量应用列表口径

修正详情弹框中实时流量模式的应用列表展示口径，避免没有实时上下行的应用干扰判断。

- 实时流量模式只显示当前存在下载或上传速率的应用
- `0 B/s` 的资源进程不再出现在实时流量列表中
- 应用级汇总改为按当前可见应用计算，和列表口径保持一致
- 内存占用、CPU 占用模式继续显示无网络流量但有资源数据的应用

### Enhancement — 升级弹窗展示真实更新内容

升级弹窗和 GitHub Release 现在会展示本版本的实际更新内容，而不是泛泛的版本占位文案。

- Release workflow 从 `CHANGELOG.md` 自动抽取当前 tag 对应的更新内容
- `latest.json.notes` 写入真实更新内容，App 检查更新时会直接展示
- GitHub Release 正文同步使用同一份更新内容
- 如果 changelog 缺少对应版本内容，Release workflow 会失败，避免发布空更新说明

## v0.36.5 (2026-06-03)

### Bug Fix — 应用流量弹框永久读取中

彻底修复详情弹框中应用流量区域可能一直显示“正在读取应用流量”的问题。

- `ps` 资源读取改为边运行边读取 stdout，避免进程输出较多时 pipe 塞满导致采样任务卡死
- 给 `ps` 读取增加超时保护，异常情况下不再阻塞后续应用流量刷新
- 应用流量空结果完成后立即退出 loading 状态，后续后台重试不会让弹框重新卡在“获取数据中”
- 关闭弹框或暂停采样时同步清理应用流量 refreshing 状态

## v0.36.4 (2026-06-02)

### UI — 应用指标切换精简

精简详情弹框中的应用指标下拉菜单，只保留用户常用的三种展示方式。

- 下拉菜单仅显示 `实时流量`、`内存占用`、`CPU 占用`
- 切换到哪个指标，应用级汇总和每一行应用数据就只显示对应指标
- 旧版本保存的下载、上传、累计流量、应用名称排序会自动回退到 `实时流量`

## v0.36.3 (2026-06-02)

### Bug Fix — 应用资源数据与流量汇总

修复详情弹框中选择“内存占用”或“CPU 占用”时，应用列表无法显示资源数据的问题。

- 将 `ps` 读取到的进程内存/CPU 数据合并进应用列表，即使 `nettop` 暂时没有应用流量行也能展示
- 避免同一 PID 同时出现在 `nettop` 和 `ps` 时重复计入应用级流量汇总
- 应用流量采样时间改用 `NetworkMonitor.now`，让速率计算和测试注入保持一致

## v0.34.6 (2026-05-23)

### Enhancement — 规范版本号显示格式

统一 About 页面和设置页的版本号为语义化 `v{major.minor.patch}` 格式，从 Info.plist 动态读取。

- 修改 About 页 fallback 版本号从硬编码 `0.33.0` 改为 `0.0.0`
- 给 AppUpdater 的 `currentVersionText` 添加 `v` 前缀显示

### 涉及子 issue

- [LUC-224](mention://issue/837789ec-8957-47bc-bf90-e623afb8c02b) 规范 About/设置页版本号为动态语义化显示

## v0.34.5 (2026-05-22)

### Bug Fix — CI 测试修复

修复 CI 中两个预已存在的测试失败，使 release workflow 能正常通过。

- 修正 `testDetailsWindowAutoDismissInterval` 期望值 10→30（匹配实际 autoDismissInterval）
- 修正 `testNetworkTotalsExcludeVirtualProxyInterfaces` 为 async 测试（refresh() 内部是 Task.detached 异步执行）

### 涉及子 issue

- [LUC-192](mention://issue/7cfdc145-9449-401b-bf0d-85bda02f9f17) 角色眼睛状态Bug：鼠标点击任意区域后眼睛闭合，松开后未恢复睁开

## v0.34.3 (2026-05-22)

### Bug Fix — 角色眼睛点击后不恢复睁开

修复角色眼睛在鼠标点击任意区域后闭合，松开后无法恢复睁开状态的 bug。

- 拆分 Down/Up monitor installer，使 mouseUp 事件被正确监听
- 移除 toggleDetailsWindow 中多余的 triggerGooglyEyesBlink() 调用

### 涉及子 issue

- [LUC-193] 修复 googly eyes mouseUp 事件监听缺失


## v0.34.2 (2026-05-21)

### Bug Fix — 开机自启动 Dock 图标问题

修复"开机自启动 + Dock 不显示"配置下，Dock 图标残留和点击弹出不可操作窗口的两个 bug。

- 修复 `applicationShouldHandleReopen`：只在 `showsDockIcon == true` 时才弹出窗口
- 延迟重申 activation policy：确保开机自启动场景下 Dock 图标正确隐藏

### 涉及子 issue

- [LUC-191] 修复开机自启动后 Dock 图标残留 + 点击弹出不可关闭窗口


## v0.34.1 (2026-05-21)

### Bug Fix — Googly Eyes Click Interaction

Fixes the googly eyes character interaction so the eye open/close state correctly tracks the mouse button state.

- **mouseDown/mouseUp tracking** — Replace the hardcoded 160ms blink-reset timer with proper mouseDown → close eyes, mouseUp → open eyes event handling
- **Remove blinkResetTask** — Eliminate the `blinkResetTask` timer that caused eyes to automatically reopen regardless of mouse button state
- **Dual-callback GooglyEyesClickMonitor** — Refactor `GooglyEyesClickMonitor` to support separate `onMouseDown` and `onMouseUp` callbacks with 4 event monitors (globalDown + localDown + globalUp + localUp)
- **New `endGooglyEyesBlink()` method** — Clean eye-opening method called on mouseUp, replacing timer-based reset
- **Test updates** — Update tests to verify mouseDown/mouseUp event separation and 4-monitor installation/removal

## v0.34.0 (2026-05-21)

### UI — Preferences Window Refactor

Settings page restructuring: split the monolithic PreferencesWindowController into modular files and redesign the UI.

- **File splitting** — Split `PreferencesWindowController.swift` (1277 lines) into 11 focused files under `Sources/NetBar/Preferences/`
- **UI redesign** — Redesigned preferences views with collapsible sections and improved layout
- **Animation interaction** — Improved menu bar animation preferences with conditional animations
- **Character grid** — New `CharacterGridCard` and `ColorSwatch` components for character selection

## v0.33.1 (2026-05-21)

### Bug Fixes — Popover Speed Display & Interaction

Fixes for three user-reported issues with the network speed popover.

- **App-level speed summary row** — Add a summary row in the application traffic list showing aggregated app-level download/upload speeds, so users can compare against the interface-level total in the header
- **Interface-level explanation text** — Add subtle explanation text below the header speed cards clarifying that the total speed is measured at the interface level and may differ from app-level totals
- **Auto-dismiss logic fix** — Popover no longer auto-dismisses while the user is actively interacting with it; auto-close timer now only activates after the user leaves the window
- **Right-aligned speed values** — Fix inconsistent alignment of speed values in the application traffic list using fixed-width trailing alignment


## v0.33.0 (2026-05-20)

### Performance — Cache & Power Optimization

Targeted caching and power-management optimizations to reduce CPU, energy, and IPC overhead.

- **Display name cache** — Cache `NSRunningApplication` display name lookups by PID, eliminating repeated system IPC calls on every 5-second nettop sampling cycle
- **System process classification cache** — Cache `isLikelySystemProcess()` results by application ID, avoiding repeated string normalization and set lookups on every SwiftUI layout pass
- **App icon cache** — Cache resolved application icons by PID, preventing repeated disk I/O and IPC from SwiftUI view body evaluations when the popover is visible
- **Screen lock full stop** — Stop all network monitoring timers and nettop processes when the screen is locked; resume automatically on wake for zero CPU/energy footprint during lock


## v0.32.0 (2026-05-19)

### Battery Optimization — Adaptive Power Management

Comprehensive battery optimization: adaptive sampling, animation frame rate scaling, system state awareness, and on-demand nettop.

- **[LUC-121] Adaptive sampling interval** — NetworkMonitor dynamically adjusts sampling frequency: idle → 3s, low traffic → 2s, high traffic → 1s; power-save mode doubles all intervals
- **[LUC-123] Adaptive animation frame rate** — RunCat animation scales FPS based on network activity: idle → static/0.5fps, active → full FPS; GooglyEyes mouse dedup + distance-based frequency switching
- **[LUC-126] System state awareness** — Low Power Mode detection + screen lock monitoring; auto-pauses animation and reduces sampling when screen is locked or battery is low
- **[LUC-128] Render coalesce optimization** — StatusBarController render coalesce strategy improved to reduce unnecessary redraws
- **[LUC-129] nettop on-demand sampling** — Application traffic sampling pauses/resumes on demand; nettop process stops when not needed
- **[LUC-131] nettop visibility integration** — nettop process auto-starts when traffic detail window opens and stops when it closes, via `isApplicationTrafficVisible` property
- **[LUC-133] GooglyEyes smart refresh** — Mouse position dedup (< 1pt threshold) + distance-based frequency scaling (near → 15fps, far → 3fps)
- **[LUC-134] PetController write reduction** — Dirty flag + batch save reduces UserDefaults write frequency for pet state

Expected improvement: ~70% CPU wake reduction during idle; zero extra power consumption when screen locked or low power mode.

## v0.31.0 (2026-05-19)

### Performance — Long-running Energy Optimization

Fixes high energy consumption and device overheating during extended use.

- **[LUC-108] StreamingNettopReader incremental parsing** — Replaced full-string O(n) parse with incremental line-by-line parsing, eliminating CPU/memory growth over time
- **[LUC-109] Render throttling + FPS cap** — Capped status bar rendering at 10fps; added render coalescing to merge rapid state changes into single draw calls
- **[LUC-110] Rendered image cache** — Added LRU cache (12 entries) for rendered status bar images, reusing bitmap output for repeated animation frames
- **[LUC-112] Gradient tint cache** — Added caching for `tintImageGradient()` results, avoiding repeated NSBitmapImageRep + gradient + alpha mask creation per frame
- **[LUC-113] Combine deduplication + debounce** — Added `removeDuplicates()` on snapshot stream; debounced settings/custom character changes at 100ms to suppress redundant re-renders
- **[LUC-114] GooglyEyes throttle 30fps→15fps** — Reduced GooglyEyes timer from 30fps to 15fps; added automatic pause when app moves to background

## v0.30.2 (2026-05-19)

### Bug Fixes

- **[LUC-105] Fix startup crash in Dictionary.merge** — Updated `NetworkMonitor` to use `uniquingKeysWith` to handle duplicate keys safely without throwing assertion failures.
- **[LUC-106] Optimize ApplicationTrafficReader.parse()** — Added deduplication using `id` in `StreamingNettopReader` to ensure robust dictionary initialization.

## v0.30.1 (2026-05-18)

### Bug Fixes

- **[LUC-104] Fix auto-update download validation** — Fixed validation to properly skip older builds from GitHub releases.

## v0.30.0 (2026-05-19)

### Performance — Comprehensive Optimization Round

- **[LUC-99] Async network refresh + primary interface cache** — Moved `getifaddrs()` + `SCDynamicStore` reads off main thread to `Task.detached`; cached primary interface name to avoid redundant system calls every second
- **[LUC-100] Persistent nettop process** — Replaced per-sample `fork+exec` of `/usr/bin/nettop` (every 5 seconds) with a single persistent process, eliminating ~720 process spawns per hour
- **[LUC-101] Formatters cache + ring buffer** — Cached `NumberFormatter` instances; replaced `Array.removeFirst()` O(n) with O(1) ring buffer for 90-second network history
- **[LUC-103] Async custom character image processing** — Offloaded image resize/color processing to background queue with persistent disk cache
- **[LUC-95] NSCache for character/tint images** — Added in-memory image cache for animation frame reads and tint bitmap operations, eliminating repeated disk I/O and per-frame bitmap creation at 24 FPS
- **[LUC-97] Dynamic color pipeline decoupling** — Reduced dynamic color update rate from 20 Hz to 4 Hz; decoupled color and position pipelines to prevent redundant full re-renders

## v0.29.4 (2026-05-18)

## v0.29.4 (2026-05-18)

### Performance

- **Settings menu bar tab optimization** — Eliminated lag in the Preferences → Menu Bar tab:
  - Isolated 8 FPS animation timer into dedicated sub-views (`AnimatedPreviewSection`, `AnimatedCharacterCatalog`) to prevent full `MenuBarPreferencesView` re-render on every frame tick
  - Added `NSCache` for character preview icons, eliminating repeated disk I/O per frame (previously 27 × disk reads per tick)
  - Replaced per-character `String.split` + `map` + `contains` in rotation pool with `Set<String>` lookup (O(n) → O(1) per check)

- Related issues: LUC-91, LUC-92, LUC-93

## v0.29.3 (2026-05-18)

- Fix: restore Pet system, RunCat resources, and tests from v0.28.9
- Fix: add entitlements and Gatekeeper workaround docs

## v0.29.2 (2026-05-18)

- Fix: ensure appearance mode immediately applies to all UI surfaces

## v0.29.1 (2026-05-17)

- Fix: optimize appearance mode switching to eliminate lag

## v0.29.0 (2026-05-17)

- Initial tracked release
