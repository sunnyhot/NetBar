# NetBar 宠物系统设计

## 背景

NetBar 现在已经有状态栏角色、RunCat 动画、自定义角色导入、网络速率监控、应用流量列表、偏好设置和详情窗口。宠物系统应该沿着这些已有能力生长：让角色从“会动的网络图标”变成“可爱陪伴 + 网络/效率助手”，而不是另起一个重型养成游戏。

## 目标

第一版宠物系统要同时满足两种需求：

- 可爱陪伴：角色有心情、状态、互动反馈、简短台词和轻量成长感。
- 工具助手：角色能解释网络状态、提醒休息、提示异常流量，并把 NetBar 的监控能力包装成“技能”。

第一版必须低打扰、可关闭、可静默。宠物应该让 NetBar 更有生命力，但不能影响菜单栏工具的清爽和稳定。

## 非目标

- 不做复杂养成经济系统，不引入货币、商店、抽卡或强制任务。
- 不做云同步、账号系统或联网服务。
- 不读取网络内容，不改变 NetBar 的隐私边界。
- 不在第一版做全屏桌面宠物或跨窗口自由行走，避免引入窗口层级和性能风险。

## 产品形态

宠物有两个表达层：

- 陪伴层：日常动画、心情、互动、亲密度、简短气泡。
- 助手层：提醒、技能、网络解释、异常提示。

用户看到的是同一只宠物。平时它撒娇、打盹、兴奋奔跑；需要时它切换成助手语气，告诉用户发生了什么。

示例表达：

- 陪伴表达：“我闻到下载速度变快了！”
- 工具表达：“当前下载 28 MB/s，主要来自 Arc。”
- 混合表达：“跑太快啦，Arc 正在吃掉大部分流量。”

## 核心模型

新增 `PetState`，由一个新的 `PetController` 管理并持久化到 `UserDefaults`：

```swift
struct PetState: Codable, Equatable {
    var mood: PetMood
    var energy: Int
    var affection: Int
    var personality: PetPersonality
    var activeSkillID: String?
    var lastInteractionAt: Date?
    var lastReminderAtByKind: [PetReminderKind: Date]
    var isQuietModeEnabled: Bool
}
```

枚举建议：

- `PetMood`: happy, sleepy, excited, worried, focused, annoyed
- `PetPersonality`: healing, playful, professional
- `PetInteraction`: pet, feed, encourage, focus, play
- `PetReminderKind`: drinkWater, restEyes, stretch, focusDone, highTraffic, networkOffline, appTrafficSpike

第一版可以只持久化基础状态：心情、活力、亲密度、性格、静默开关、提醒时间。不要把每次动画帧或短暂事件写入持久化。

## 状态计算

宠物状态由三类输入共同决定：

1. 网络输入：下载/上传速度、网络断开、应用流量异常。
2. 时间输入：久未互动、提醒间隔、专注计时。
3. 用户输入：点击、双击、右键技能、面板按钮。

状态规则示例：

- 网络速度高：mood = excited，动画速度提升，台词偏兴奋。
- 网络断开或长时间 0 速：mood = worried，出现轻提示。
- 用户双击宠物：触发 pet 互动，affection 增加，短动画变开心。
- 开启专注守护：mood = focused，减少普通提醒，只保留重要提醒。
- 长时间无互动：energy 下降；当 energy 低于阈值时进入 sleepy。

## 交互设计

状态栏宠物：

- 单击：打开宠物面板。后续可在偏好中选择是否仍打开网络详情。
- 双击：摸摸宠物，增加亲密度，触发短动画。
- 悬停：显示一句短气泡，不超过 3 秒。
- 右键：打开菜单，包含技能、提醒、静默模式、偏好设置。
- 连续点击：触发特殊反应，例如害羞、转圈、闪光。

宠物面板：

- 顶部：宠物头像、名字、心情、亲密度。
- 中部：今日状态，包含网络状态、提醒状态、当前技能。
- 操作区：摸摸、喂食、鼓励、陪我专注。
- 技能区：网络侦察、流量护盾、专注守护、幸运闪光。
- 设置入口：性格、提醒开关、静默模式、通知权限。

## 提醒系统

提醒分三级：

- 温柔提醒：喝水、休息眼睛、伸展。
- 实用提醒：专注结束、网络断开、流量过高。
- 重要提醒：某应用持续异常流量、上传异常高。

提醒通道：

- 默认：宠物气泡 + 宠物动画变化。
- 可选：macOS 通知。
- 静默模式：只在宠物面板显示，不弹气泡和系统通知。

提醒频率规则：

- 同类提醒有冷却时间。
- 专注模式期间只显示专注结束和重要网络异常。
- 用户关闭某类提醒后不再主动触发。

## 技能系统

新增 `PetSkill`，技能是“可被用户触发或条件触发的一段助手行为”：

```swift
struct PetSkill: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let cooldownSeconds: TimeInterval
    let trigger: PetSkillTrigger
    let effect: PetSkillEffect
    let animationHint: PetAnimationHint
}
```

第一版技能：

- 网络侦察：读取当前应用流量列表，找出最耗流量应用，给一句解释。
- 流量护盾：开启阈值监控，超过下载/上传阈值时提醒。
- 专注守护：25/45/60 分钟计时，期间降低打扰，到点提醒休息。
- 幸运闪光：趣味技能，触发短暂闪光/换色/开心台词。

第二版技能：

- 摸鱼警报：指定应用持续活跃时温和提醒。
- 异常嗅探：网络突然降速、断开、恢复时解释变化。
- 今日总结：概括今日网络峰值、主要流量应用和专注次数。

## 架构设计

新增文件建议：

- `PetState.swift`: 宠物状态、枚举、持久化模型。
- `PetController.swift`: 状态机、互动入口、提醒调度、技能执行。
- `PetReminderScheduler.swift`: 提醒规则和冷却判断。
- `PetSkill.swift`: 技能模型和内置技能定义。
- `PetPresentation.swift`: 把状态转换成台词、动画 hint、气泡内容。
- `PetPanelView.swift`: SwiftUI 宠物面板。

接入点：

- `StatusBarController` 持有 `PetController`，把网络快照和点击事件喂给宠物系统。
- `StatusBarDisplayRenderer` 接收宠物动画 hint，决定是否叠加闪光、气泡状态或特殊帧。
- `PreferencesWindowController` 增加“宠物”设置区，管理性格、提醒、静默模式和技能开关。
- `NetworkMonitor` 不需要知道宠物系统，继续只发布网络状态。

数据流：

```text
NetworkMonitor.snapshot
    -> StatusBarController
    -> PetController.observe(snapshot)
    -> PetState / PetEvent
    -> PetPresentation
    -> StatusBar image + PetPanelView + optional notification
```

## UI 规划

偏好设置新增“宠物”分区：

- 启用宠物系统
- 性格：治愈 / 活泼 / 专业
- 提醒：喝水、休息、伸展、网络异常、流量过高
- 技能：网络侦察、流量护盾、专注守护、幸运闪光
- 静默模式
- 系统通知开关

宠物面板保持紧凑，不做大型仪表盘。网络详情仍由现有详情窗口承担，宠物面板只显示宠物相关的轻信息和快捷动作。

## 实施阶段

### 第一阶段：宠物 MVP

- 新增 `PetState` 和 `PetController`。
- 支持性格、心情、活力、亲密度。
- 支持单击面板、双击摸摸、右键技能。
- 支持 3 个提醒：喝水、休息、流量过高。
- 支持 3 个技能：网络侦察、专注守护、幸运闪光。
- 支持静默模式。

### 第二阶段：陪伴增强

- 增加气泡台词库。
- 增加更多状态动画映射。
- 增加亲密度等级和每日互动记录。
- 增加摸鱼警报和异常嗅探。

### 第三阶段：总结与个性化

- 增加今日总结。
- 增加技能冷却和技能配置。
- 增加自定义宠物台词。
- 增加更多自定义角色与宠物状态的绑定方式。

## 测试策略

单元测试：

- `PetState` 默认值和持久化。
- 网络快照到心情的映射。
- 互动对亲密度和心情的影响。
- 提醒冷却规则。
- 技能触发和冷却规则。
- 静默模式下不产生主动通知。

集成测试：

- `StatusBarController` 点击事件能触发宠物事件。
- 高流量快照能生成流量提醒。
- 专注守护到期能生成提醒。

UI 可人工验证：

- 状态栏宠物不遮挡现有速率文本。
- 宠物面板在浅色/深色主题下可读。
- 提醒不会频繁弹出。

## 风险与取舍

- `StatusBarStyle.swift` 已经很大，宠物渲染逻辑应尽量通过 `PetPresentation` 输入，不继续把状态机塞进渲染文件。
- macOS 通知需要权限，第一版应把系统通知做成可选增强。
- 宠物气泡如果直接做浮窗会引入窗口层级复杂度，第一版可以先在宠物面板和状态栏图像内表达。
- 技能系统要保持轻量，第一版用内置技能枚举即可，后续再抽象成插件式配置。

## 验收标准

- 用户能开启宠物系统并选择性格。
- 用户能通过状态栏角色进行至少一种互动。
- 宠物会根据网络状态变化心情。
- 宠物能触发至少三类提醒。
- 用户能触发至少三个技能。
- 所有提醒和技能都能关闭或静默。
- 不影响现有网络显示、角色动画、自定义角色导入和应用流量列表。
