# NetBar 应用流量面板 UX 优化实施计划

> 状态：**已实施**（2026-09-03，提交 9f92a35…；P2-6 排序切换与 P3 全部按用户决定裁剪）
> 范围：菜单栏详情窗口「应用流量」面板的用户体验优化
> 基线：v0.43.1，本文所有行号以当前 `Sources/NetBar` 代码为准

> **实施偏差记录**（相对本草案）：
> 1. P1-3 字段设计反转：`download/uploadBytesPerSecond` 保持 raw 语义，新增 `display*BytesPerSecond` 平滑字段（未显式提供时回落 raw），存量 presentation 测试零改动，归因/汇总天然用 raw；
> 2. P1-2 修复重启计数在 spawn 成功时被清零的问题（改为解析到真实数据才重置预算），否则瞬死循环永不耗尽、耗尽分支不可达；
> 3. P1-2 重启尝试期间保留 `latestStats`（草案会在重启窗口期闪空态），仅放弃重启时清空；
> 4. P1-4 跟随采样仅在样本成功时触发（错误样本保留错误卡片等待手动重试）；
> 5. 宽限期过后显示值硬归零（EMA 自然衰减太慢，空闲行会滞留十几秒）；
> 6. P2-8 细节收进 `.help` tooltip 而非 popover（零 UI 占位，回避与设计系统的统一问题）。

## 1. 背景与目标

「应用流量」面板的数据链路为：

```
/usr/bin/script → nettop(-P -L 0 -x -t external -J bytes_in,bytes_out)
  → StreamingNettopReader（常驻进程 + 伪终端）
  → NettopLineParser（CSV 逐行解析）
  → NetworkMonitor.refreshApplicationTraffic（1s 定时 / 低电量 5s，Task.detached）
  → 速率差量计算 + 按显示名聚合（groupApplications）
  → ApplicationTrafficState（@Published）
  → ApplicationTrafficPresentation（过滤/搜索/排序/归因）
  → ApplicationTrafficPanel（SwiftUI）
```

采样生命周期：详情窗口打开 → `ApplicationTrafficVisibilityScheduler` 延迟 500ms resume → 起 nettop；窗口关闭 → 延迟 30s pause → 停 nettop 并清空 reader 缓存。采样间隔由 `PerformanceSamplingPolicy` 决定（正常 1s，低电量 5s，锁屏停止）。

当前存在 4 个高优先级、5 个中优先级、若干低优先级体验问题。本计划的目标是：

1. 消除「重开窗口数据闪烁」与「冷启动三段式困惑」；
2. 让 nettop 启动/运行失败可被用户感知并重试；
3. 稳定每秒刷新的列表（平滑 + 宽限期 + 滞后阈值）；
4. 补齐搜索、排序、截断提示等控件级体验；
5. 保持现有架构约定：无第三方依赖、协议注入、`appPreferences.text("中文", "English")` 双语、全部测试通过。

## 2. 现状与根因总览

| 编号 | 问题（用户视角） | 根因（代码位置） |
|---|---|---|
| P1-1 | 重开窗口：旧列表 → 空态 → 新列表，闪烁 2–3 秒 | `pauseApplicationTrafficSampling()`（`NetworkMonitor.swift:141-153`）不重置 `previousApplicationStats` / `previousApplicationSampleDate`；`StreamingNettopReader.stop()`（`ApplicationTrafficReader.swift:58-67`）清空 `latestStats`。重开后新 nettop 进程计数器从 0 开始，首次差量用旧时间戳做 interval，`positiveDelta` 结果为 0 → 列表被清空 |
| P1-2 | nettop 起不来时用户只看到「暂无应用流量」，无法诊断、无重试 | `StreamingNettopReader.readApplications()`（`ApplicationTrafficReader.swift:69-80`）恒返回 `errorMessage: nil`；spawn 失败（`launchProcess` catch，99-110 行）静默；重启 3 次耗尽后 `handleProcessTermination`（163-180 行）静默且 **`isRunning` 仍为 true**，`start()` 无法再拉起 |
| P1-3 | 列表每秒抖动：间歇性活动的进程反复进出列表、整列重排 | `hasVisibleRealtimeTraffic` 硬阈值 ≥1 B/s（`ApplicationTrafficPresentation.swift:256-258`）+ 1s 采样间隔，无平滑、无宽限期、无滞后 |
| P1-4 | 冷启动 2–4 秒：正在读取 → 暂无应用流量 → 数据，像出了三次 bug | resume 延迟 500ms（`StatusBarController.swift:30-80`）+ nettop spawn + 首个样本只是基线（全 0 速率，`NetworkMonitor.swift:437-461`）→ 被 `displayApplications` 过滤 → 空态；第二个样本才出速率 |
| P2-5 | 搜索框无清除按钮；「隐藏系统进程」开关不在面板上 | `AppTrafficControls`（`ApplicationTrafficPanel.swift:256-267`）只有裸 TextField；`hidesSystemProcesses` 仅在偏好设置可改（`AppPreferences.swift:189`） |
| P2-6 | 排序不可控 | `ApplicationTrafficPresentation.sorted`（142-150 行）硬编码总速率降序 |
| P2-7 | 只显示 18 行，无截断提示 | `makeModel(limit: 18)`（`ApplicationTrafficPresentation.swift:106-134`）`prefix(limit)` 后无任何反馈 |
| P2-8 | 归因卡片信息密度高、术语不直观 | `AppTrafficAttributionCard`（`ApplicationTrafficPanel.swift:155-252`）堆叠覆盖率、接口/应用速率、代理候选、采样次数 |
| P2-9 | VoiceOver 重复朗读行内容 | `AppBadge`（443-465 行）首字母 Text 与名称 Text 各自可读 |
| P3-* | 行无点击操作、数值无动画、时间非相对、低电量无提示 | — |

## 3. 高优先级优化项详细方案

### P1-1 重开窗口数据不闪烁

**目标**：重开窗口时保留上一次列表（置灰 + 「重新采样中」标记），新数据就绪后无缝替换；消除空态闪现。

**方案**

1. `NetworkMonitor` 状态机改造：
   - `pauseApplicationTrafficSampling()` 增加：`previousApplicationStats = [:]`、`previousApplicationSampleDate = nil`（基线重置），并给 `appTraffic` 打上 `isStale = true`，**保留** `applications` 内容。
   - `resumeApplicationTrafficSampling()` 复位基线后正常起 reader；在首个新样本应用前，`appTraffic` 维持旧数据 + `isStale = true`。
   - `applyApplicationTraffic(_:sampledAt:)` 应用首个样本（此时走「无 previousDate」分支，`NetworkMonitor.swift:437-461`）时：若有旧列表，用「旧行 + 新速率 0」合并显示（或直接沿用旧行内容），并把 `isStale` 置 false；后续样本正常更新。
   - 样本为空（nettop 尚未吐出数据）时不覆盖 `applications`，仅更新 `isRefreshing`。
2. 数据模型（`InterfaceStats.swift`）：`ApplicationTrafficState` 增加 `var isStale: Bool`（默认 false，`empty` 为 false）。
3. UI（`ApplicationTrafficPanel.swift`）：
   - `isStale` 为 true 时：面板头部时间戳后追加「重新采样中」chip；行 `opacity(0.55)` + `allowsHitTesting(false)`（或不加交互限制，仅视觉置灰）；空态判断改为「stale 且有旧数据时显示置灰列表，不显示空态」。
   - `ApplicationTrafficRow` 增加 `isDimmed` 参数（默认 false）。

**改动文件**：`NetworkMonitor.swift`、`InterfaceStats.swift`、`ApplicationTrafficPanel.swift`。

**实现步骤**

1. 模型加字段 → 2. Monitor 状态机 → 3. UI 置灰分支 → 4. 补测试 → 5. 手测。

**测试点（新增/修改）**

- 新增：pause → resume 后 `previousApplicationSampleDate` 为 nil，首个新样本走基线分支；
- 新增：pause 后 `appTraffic.isStale == true` 且 `applications` 保留；首个新样本应用后 `isStale == false`；
- 新增：stale 状态 + 空样本时 `applications` 不被清空；
- 修改：`testPausedApplicationTrafficIgnoresInFlightResult`（`SystemResourceTests.swift:695`）兼容基线重置。

**验收标准**：关闭窗口 >30s 后重开，列表始终有内容（先置灰旧数据，再平滑换新），全程无「暂无应用流量」闪现。

---

### P1-2 nettop 失败可诊断、可重试

**目标**：spawn 失败、进程反复退出时显示明确错误卡片与「重试」按钮；重试能真正重启 reader。

**方案**

1. `StreamingNettopReader` 增加 `private var lastErrorMessage: String?`：
   - `launchProcess` 的 `catch` 分支设置「无法启动 /usr/bin/script 或 nettop」错误（区分 executable 与 spawn 两种情形）；
   - `handleProcessTermination` 重启次数耗尽时设置「nettop 进程多次退出，已暂停应用流量采样」，**并将 `isRunning = false`、`process = nil`**（修复当前无法再 `start()` 的 bug）；
   - 任意一次成功解析新数据（`appendOutput` 成功 parse 一行）或 `start()` 成功启动后清除错误。
   - `readApplications()` 返回错误：`stats` 非空时优先返回 stats（错误可保留在后台）；stats 为空且 `lastErrorMessage` 非空时返回 `ApplicationTrafficReadResult(stats: [], errorMessage: lastErrorMessage)`。
2. `NetworkMonitor.refreshApplicationTraffic()`（393-417 行）已有错误分支（`applyApplicationTraffic` 425-434 行保留旧 applications），无需大改；但「重试」需增强：`ApplicationTrafficPanel` 的 retry 回调改为新方法 `retryApplicationTrafficReading()`，逻辑 = `shouldSampleApplicationTraffic = true`（或保持）+ 强制 `streamingReader?.start()`（因为错误态下 reader 可能已停止）+ `refreshApplicationTraffic()`。
3. UI（`ApplicationTrafficPanel.swift:49-56`）错误卡片文案补上具体诊断：展示 `errorMessage` 全文，提示文案增加「可在终端运行 `nettop -P -L 1` 验证系统工具是否可用」。

**改动文件**：`ApplicationTrafficReader.swift`、`NetworkMonitor.swift`、`ApplicationTrafficPanel.swift`。

**测试点（新增/修改）**

- 新增：spawn 失败（注入不可执行 URL）→ `readApplications()` 返回非空 `errorMessage`；
- 新增：终止 3 次耗尽 → `errorMessage` 非空、`isRunning == false`、再次 `start()` 可重启；
- 新增：成功解析后错误被清除；
- 修改：`testRefreshApplicationTrafficErrorTransitionsOutOfRefreshing`（`SystemResourceTests.swift:645`）适配新错误路径；
- 修改：`testStreamingNettopReaderUsesTerminalBackedOutputForImmediateCSV`（`SystemResourceTests.swift:926`）确认无错误时不返回 errorMessage。

**验收标准**：`killall script`（或移除 nettop）后 1–2 个采样周期内面板出现错误卡片 + 重试；恢复环境后点重试恢复列表。

---

### P1-3 列表稳定：平滑 + 宽限期 + 滞后阈值

**目标**：显示速率平滑、行不闪烁进出、排序不跳动，同时保持归因覆盖率的原始性。

**方案**

1. 平滑与宽限期**放在 `NetworkMonitor`**（有状态，持久跨刷新；`ApplicationTrafficPresentation` 保持纯函数）：
   - 新增私有状态 `displayRates: [String: ApplicationTrafficDisplayRate]`，其中 `ApplicationTrafficDisplayRate = { smoothedDownload, smoothedUpload, lastActiveDate }`（可放 `InterfaceStats.swift` 或 `NetworkMonitor.swift`）。
   - `applyApplicationTraffic` 聚合后（`groupApplications` 结果）对每个 app 做 EMA 平滑：`smoothed = raw * alpha + smoothed * (1 - alpha)`，推荐 `alpha = 0.4`（1s 采样下约 2.5s 收敛；低电量 5s 采样仍可用，收敛变慢可接受，或按采样间隔调整 alpha）。
   - 宽限期（时间制，避免低电量 5s 采样下按样本数计算失真）：`lastActiveDate` 在 raw 速率 ≥ 退出阈值时刷新；显示值在 `now - lastActiveDate > 3s` 后置 0。展示层过滤使用 **平滑值**。
   - 滞后阈值：进入列表：平滑值 ≥ 2 KB/s；移出列表：平滑值 < 1 B/s 且宽限期已过（宽限期内在列表中显示为 0 B/s 置灰，不参与重排）。
2. `ApplicationTrafficState.applications` 中的 `downloadBytesPerSecond` / `uploadBytesPerSecond` 字段改为**显示值（平滑后）**，另加 `rawDownloadBytesPerSecond` / `rawUploadBytesPerSecond`（或独立 `raw: Bool` 标记不必要——保留 raw 字段供归因与测试用）。
   - 归因覆盖率（`attributionSummary`，`ApplicationTrafficPresentation.swift:152-178`）与「应用级汇总」用 **raw 值**计算，避免平滑造成覆盖率失真。
3. `ApplicationTrafficPresentation`：
   - `hasVisibleRealtimeTraffic` 改读平滑值；`makeModel` 的过滤逻辑适配滞后规则（进入 ≥2 KB/s、退出 <1 B/s，宽限期已由 Monitor 处理成「0 但仍在列表」的置灰行，Presentation 需识别「宽限期内」标记）。
   - 具体实现：`ApplicationTrafficRate` 增加 `var isExpiring: Bool`（宽限期内、速率已置 0），Presentation 不过滤 `isExpiring` 行，`ApplicationTrafficRow` 对其置灰。
4. UI：置灰样式复用 P1-1 的 `isDimmed`。

**改动文件**：`NetworkMonitor.swift`、`InterfaceStats.swift`、`ApplicationTrafficPresentation.swift`、`ApplicationTrafficPanel.swift`。

**参数建议（可作为常量便于测试注入）**

| 参数 | 建议值 | 说明 |
|---|---|---|
| EMA alpha | 0.4（1s 采样） | 低电量可降为 0.25 |
| 进入阈值 | 2 KB/s（平滑值） | 防止瞬时噪声行 |
| 退出阈值 | 1 B/s | 与现逻辑一致 |
| 宽限期 | 3 秒（时间制） | 低电量 5s 采样下约 1 个采样周期 |

**测试点（新增/修改）**

- 新增：EMA 平滑数值收敛（注入 `now()` 控制时间）；
- 新增：raw 归零后宽限期内行保留且 `isExpiring == true`，宽限期过后移除；
- 新增：2 KB/s 以下平滑值不入列表；宽限期内回落 0 不出列表；
- 修改：`testRealtimeTrafficModeHidesAppsWithoutCurrentTraffic`（`PreferencesAndPresentationTests.swift:3384`）适配平滑/宽限语义；
- 修改：`testApplicationListSearchSortAndHideSystemProcesses`（2403 行）、`testApplicationTrafficPresentationModelBuildsVisibleAppsAndSummary`（3296 行）适配新字段与滞后规则。

**验收标准**：观察 30s，间歇性活动的进程不闪烁进出；列表顺序每秒变化 ≤1 次重排；归因覆盖率与未平滑前一致。

---

### P1-4 冷启动反馈与首值加速

**目标**：打开窗口后 ≤1.5s 出现首个真实速率；加载态文案与过渡不再产生「出了 bug」的观感。

**方案**

1. 首值加速：`resumeApplicationTrafficSampling()` 中，首个基线样本落地后（`applyApplicationTraffic` 走「无 previousDate」分支且是 resume 后的第一次）立即再触发一次 `refreshApplicationTraffic()`（间隔实际 ≥0.2s，`NetworkMonitor.swift:463` 已有 `max(interval, 0.2)` 钳制；短窗口首值会偏噪，可接受）。实现：增加 `private var needsImmediateFollowUpSample = false`，基线分支落地后置 true 并直接调用一次刷新；常规定时器不受影响。
2. 加载过渡：
   - 保留「正在读取应用流量」文案，配 `ProgressView().controlSize(.small)`（替代静态 icon `arrow.triangle.2.circlepath`，`ApplicationTrafficPanel.swift:97`）；
   - 列表区加最小高度占位（如 `.frame(minHeight: 96)`，仅加载态），避免出现数据时面板高度跳动；
   - 空态文案微调为「首次采样约需 2 秒，请稍候…」。
3. 与 P1-1 联动：stale 旧数据存在时优先显示置灰旧数据，加载态只出现在**首次安装/无旧数据**时。

**改动文件**：`NetworkMonitor.swift`、`ApplicationTrafficPanel.swift`。

**测试点（新增）**

- 新增：resume 后基线样本落地自动触发跟随采样，第二个样本出非零速率（mock reader 返回递增计数）；
- 新增：非 resume 场景（正常定时）不触发额外采样。

**验收标准**：干净环境下（清空 UserDefaults）打开窗口，≤1.5s 内出现首个非零速率；无旧数据时加载态平滑过渡，无高度跳变。

---

## 4. 中优先级优化项详细方案

### P2-5 搜索清除按钮 + 系统进程快捷开关

- `AppTrafficControls`（`ApplicationTrafficPanel.swift:256-267`）改为 HStack：TextField + 「系统进程」Toggle（直接绑定 `preferences.hidesSystemProcesses`，文案「系统进程」，`help` 双语）；`searchText` 非空时 TextField 右侧叠加清除按钮（`xmark.circle.fill`，点击清空）。
- 偏好项本身已持久化（`AppPreferences.swift:189`，key `app.hidesSystemProcesses`），无需改存储。
- 注意 `AppTrafficControls` 当前无条件显示，保持该行为（搜索框始终可见是现有设计）。
- 测试：无新单测（纯 UI）；手测双语切换。

### P2-6 排序切换

- 新增 `enum ApplicationTrafficSortKind: CaseIterable { case total, download, upload }`（`ApplicationTrafficPresentation.swift`），带 `title(language:)` 双语（「总量/下载/上传」）。
- `sorted(_:by:)` 增加 sort 参数；`makeModel` 透传；面板 `@State private var sortKind: ApplicationTrafficSortKind = .total`，`AppTrafficControls` 增加 `Menu`（`Picker`）。
- 排序键：total=down+up、download、upload，同值回退名称升序（复用 `orderedDescending`）。
- 测试：新增三种排序模式单测；修改 `makeModel` 相关测试传入默认值。

### P2-7 18 行截断提示

- `ApplicationTrafficPresentationModel` 增加 `var totalMatches: Int`、`var isTruncated: Bool`（`visibleApplications.count < filteredAndDisplayed.count`）。
- 面板在列表底部（`visibleApplications` 非空且 `isTruncated`）显示一行小字：「仅显示前 18 个 · 搜索可找到更多」（双语）。
- 测试：新增 >18 条数据时 `isTruncated == true`、`totalMatches` 正确；≤18 时 false。

### P2-8 归因卡片可读性

- 主行精简为一句人话：「应用合计约为接口总流量的 87%」，状态色不变（covered/partial/idle 的 tone 保留）。
- 次要信息（接口速率、应用速率、代理候选、采样次数）移入 `help` tooltip 或「i」按钮 `popover`（macOS SwiftUI `.popover` 小窗），点击查看详情。
- `AppTrafficAttributionCard` 的 `detail`/`message` 字段拆分：`headline`（一句话）+ `details`（tooltip 内容），`title` 改为 `headline`。
- 测试：修改 `testApplicationAttributionSummaryShowsCoverageAndLikelyProxy`（3325 行）等只测模型、不测视图的用例不受影响；新增文案双语检查（可选）。

### P2-9 无障碍

- `AppBadge` 加 `.accessibilityHidden(true)`；整行 `.accessibilityElement(children: .combine)`，保证朗读一次「名称 + 角色 + 下行 xx + 上行 xx」。
- `AttributionRoleBadge` 保留可读（角色信息有语义价值）。
- 测试：`testApplicationTrafficRowsUseStaticBadgesWhileScrolling`（`PreferencesAndPresentationTests.swift:3741`，源码级检查）如做静态源码断言需同步更新。

---

## 5. 低优先级（P3，可选迭代）

| 编号 | 内容 | 方案要点 |
|---|---|---|
| P3-1 | 行点击操作 | 单击行 `NSRunningApplication(processIdentifier:).activate()` 打开应用；右键菜单「在活动监视器中显示」需要写脚本/不支持时降级为复制 PID |
| P3-2 | 数值变化动画 | `Text(...).contentTransition(.numericText())` + `.animation(.easeOut(duration: 0.3), value: application.downloadBytesPerSecond)`，注意仅列表内，不引入全局动画 |
| P3-3 | 相对时间 | 头部「更新 12:03」改为 `RelativeDateTimeFormatter`（「刚刚 / 1 分钟前」），悬停显示绝对时间（`.help`） |
| P3-4 | 低电量提示 | `powerSaveMode` 时头部 chip「省电采样中（5s）」，复用现有 `NetworkMonitor` 状态发布 |

## 6. 数据模型与 API 变更汇总

| 位置 | 变更 |
|---|---|
| `InterfaceStats.swift` | `ApplicationTrafficState` + `isStale: Bool`；`ApplicationTrafficRate` + `rawDownloadBytesPerSecond`、`rawUploadBytesPerSecond`、`isExpiring: Bool`（`download/uploadBytesPerSecond` 变为平滑显示值） |
| `ApplicationTrafficReader.swift` | `StreamingNettopReader` + `lastErrorMessage`；`readApplications()` 错误返回；`handleProcessTermination` 耗尽后 `isRunning = false` |
| `NetworkMonitor.swift` | + `displayRates` 平滑状态；+ `needsImmediateFollowUpSample`；+ `retryApplicationTrafficReading()`；pause 基线重置 + stale 标记 |
| `ApplicationTrafficPresentation.swift` | + `ApplicationTrafficSortKind`；`sorted(_:by:)`、`makeModel` 加参数与 `totalMatches`/`isTruncated`；可见性过滤改平滑值 + `isExpiring` 例外 |
| `ApplicationTrafficPanel.swift` | + 清除按钮、系统进程 Toggle、排序 Menu、截断提示、stale/expiring 置灰、归因卡片重构、无障碍、加载 ProgressView、`retry` 指向新方法 |
| i18n | 新增双语字符串约 10 条（「重新采样中」「系统进程」「仅显示前 18 个」「首次采样约需 2 秒」等），全部走 `appPreferences.text(...)` |

## 7. 迭代里程碑

### M1 — 数据连续性与可诊断性（P1-1 + P1-2）

- 交付物：stale 置灰展示、基线重置、错误卡片可达、重试可用。
- 验证：`swift test`；`./Scripts/build-app.sh`；手动场景（见 §8）。

### M2 — 稳定性与感知延迟（P1-3 + P1-4）

- 交付物：EMA 平滑、宽限期、滞后阈值、首值加速、加载过渡。
- 验证：`swift test`；30s 连续观察抖动；冷启动计时。

### M3 — 控件与可读性（P2-5 ~ P2-9）

- 交付物：搜索清除、系统进程开关、排序、截断提示、归因卡片、无障碍。
- 验证：`swift test`；中英文界面走查；VoiceOver 走查。

### M4 — 打磨（P3-*）

- 交付物：行操作、数值动画、相对时间、低电量提示。
- 验证：手测 + 回归。

每阶段合入前跑 `swift test`；涉及 `.app` 组装的行为再跑 `./Scripts/build-app.sh` 与 `./Scripts/verify-release-app.sh build/NetBar.app`。

## 8. 测试计划

### 8.1 单元测试（新增）

| 用例 | 归属 |
|---|---|
| pause 后基线重置、stale 标记、旧列表保留、新样本后 stale 清除 | `SystemResourceTests.swift` |
| 空样本不覆盖旧 applications | 同上 |
| spawn 失败返回 errorMessage；重启耗尽后 isRunning=false 且可再 start；成功解析清除错误 | 同上 |
| resume 后跟随采样出首个速率 | 同上 |
| EMA 收敛、宽限期（时间制）、进入/退出阈值滞后 | 同上 |
| 三种排序模式；截断标记（>18 / ≤18） | `PreferencesAndPresentationTests.swift` |
| 归因覆盖率使用 raw 值不受平滑影响 | 同上 |

### 8.2 现有测试影响面（需同步修改）

- `PreferencesAndPresentationTests.swift`：`testApplicationListSearchSortAndHideSystemProcesses`(2403)、`testApplicationRowMetricsShowRealtimeTraffic`(3254)、`testApplicationSummaryMetricsShowRealtimeTraffic`(3271)、`testApplicationTrafficPresentationModelBuildsVisibleAppsAndSummary`(3296)、`testApplicationAttributionSummaryShowsCoverageAndLikelyProxy`(3325)、`testApplicationAttributionSummaryClassifiesRows`(3343)、`testRealtimeTrafficModeHidesAppsWithoutCurrentTraffic`(3384)、`testApplicationSummaryUsesVisibleApplications`(3411)、`testApplicationTrafficRowsUseStaticBadgesWhileScrolling`(3741)。
- `SystemResourceTests.swift`：`testNetworkMonitorRefreshesApplicationTraffic`(484)、`testRefreshApplicationTrafficFirstSampleTransitionsOutOfRefreshing`(618)、`testRefreshApplicationTrafficErrorTransitionsOutOfRefreshing`(645)、`testPausedApplicationTrafficIgnoresInFlightResult`(695)、`testStreamingNettopReaderUsesTerminalBackedOutputForImmediateCSV`(926)。

### 8.3 手动验证清单（用户侧）

1. 关闭窗口 >30s → 重开：无空态闪现，旧数据置灰后平滑换新；
2. `killall script` → 错误卡片出现 → 恢复环境 → 重试成功；
3. 观察 30s：无行闪烁、排序稳定；低电量模式同样稳定（5s 采样）；
4. 冷启动（清 UserDefaults）首值 ≤1.5s；
5. 搜索 + 清除 + 系统进程开关 + 三种排序 + 截断提示（构造 >18 个有流量应用）；
6. 中英文切换走查新增文案；VoiceOver 走查行朗读不重复。

## 9. 风险与回滚策略

| 风险 | 影响 | 缓解 |
|---|---|---|
| nettop 输出/系统差异（已知坑点） | 解析失败 → 平滑层收到 0 | raw 值保留在诊断字段；错误上报走 P1-2；解析层不改动，只在其上叠加显示层 |
| 平滑值影响归因/汇总准确性 | 覆盖率偏差 | 归因与「应用级汇总」坚持用 raw；测试锁定 |
| 首值加速的短窗口噪声 | 首个速率跳变 | 可接受（后续样本迅速收敛）；若观感差，改为 0.5s 后跟随采样 |
| 模型字段扩展破坏既有测试 | 回归 | M1 起逐阶段更新受影响测试（§8.2 清单），每阶段全量 `swift test` |
| 宽限期按样本数设计在低电量下失真 | 行滞留 15s | 设计为时间制（3s），已规避 |
| 状态在 `@MainActor` 的并发约束 | 竞态 | 所有新状态只在 `NetworkMonitor` 主 actor 方法内读写；reader 内部状态继续由 `NSLock` 保护 |

回滚：每个优化项为独立提交（P1-1、P1-2、P1-3…各自一个 commit），可单独 revert；合并前全部基于 M1→M4 顺序。

## 10. 开放问题（实施前确认）

1. EMA alpha 取值：0.4（约 2.5s 收敛）是否合适？是否需要随采样间隔自适应？
2. 进入阈值 2 KB/s：过低会保留噪声行，过高会漏掉小流量应用，是否需要做成偏好设置？
3. 宽限期 3s：是否需要跟随低电量模式延长？
4. 排序偏好是否需要持久化（UserDefaults）？默认总量降序。
5. P2-8 的「i」按钮 popover 与现有 `LivingSignalDesignSystem` 卡片风格如何统一。
