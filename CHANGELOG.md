# Changelog

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
