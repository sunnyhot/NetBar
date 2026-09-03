# 菜单栏偏好设置精简 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 精简偏好设置「菜单栏」Tab——修复结构问题、裁剪低价值设置项（行距、轮换角色池）、解耦文字/角色颜色、移除整个菜单栏背景渲染子系统，并把 4 个折叠区合并为 2 个（「显示与布局」「角色与动画」）。

**Architecture:** 分 7 个独立可测试的任务推进，每个任务结束时 `swift test` 全绿并单独提交。前 4 个任务只动偏好设置 UI 和少量模型字段；Task 5 集中移除背景渲染路径（`StatusBarRenderer` / `StatusBarStyle` / 渲染签名 / 缓存键 / 相关测试）；Task 6 在裁剪完成后把 4 个折叠区合并为 2 个——此时「动画与轮换」只剩 5 个控件，合并成本最低；Task 7 收尾文档与打包验证。测试沿用本仓库已确立的「源码扫描测试」模式（读取 Swift 源文件断言结构，参考 `testAnimatedCharacterCatalogDoesNotRunItsOwnTimer`）。

**Tech Stack:** Swift 5（SPM swift-tools-version 6.0）| AppKit + SwiftUI | macOS 13+ | 无第三方依赖

## Global Constraints

- 新增/修改用户可见字符串必须走 `appPreferences.text("中文", "English")` 双语（AGENTS.md 约定 3）。
- 修改状态栏渲染必须跑 `swift test`（AGENTS.md 约定，每个 Task 的验证步骤已包含）。
- 构建 `.app` 只用 `./Scripts/build-app.sh`，不手动拼包（AGENTS.md 约定）。
- 本地默认保留 SwiftPM linker-signed/ad-hoc 签名形态，不做公证签名。
- 每个 Task 结束仓库必须可编译、测试全绿；提交信息用 `refactor(...)`/`docs:` 前缀。
- 被删除的 UserDefaults key（`statusBar.lineSpacing`、`statusBar.catRotationPool`、`statusBar.showsBackground`、`statusBar.backgroundOpacity`、`statusBar.backgroundColor.*`）残留旧值不做迁移——代码不再读取即视为已删除（与 v0.43.0 历史精简的处理方式一致）。
- 不要从受限父进程直接执行 `build/NetBar.app/Contents/MacOS/NetBar`（AGENTS.md 坑点 9）；需要人工验证 UI 时让用户自己 `open build/NetBar.app`。

## 背景调研结论（已核实，实施时可直接依赖）

1. `StatusBarDisplayRenderer.presentation(...)` 恒返回 `.retinaImage`（`StatusBarRenderer.swift:188-189`），`nativeTitle` 分支是不可达死代码；`attributedTitle(...)` 仅被预览视图中的死分支和清空标题的调用引用。**移除安全。**
2. 流量脉冲高亮（`StatusBarPulseRenderPolicy`）只在 `settings.showsBackground == true` 时绘制（`StatusBarRenderer.swift:319-336`）。**背景一删，脉冲策略即为死代码，可整体删除。**
3. 渲染器对「系统文字颜色 + 自定义角色颜色」的组合已正确处理：`useTemplate = usesSystemTextColor && !showsBackground && !catHasCustomColor`，非模板路径下文字用 `effectiveTextColor`（labelColor）、角色用自定义色。偏好设置里 6 处「选角色颜色时自动关闭系统文字颜色」的联动和橙色警告横幅**全是多余的，可安全删除**。
4. `drawSparkles(...)`（`StatusBarRenderer.swift:912`）属于动态颜色模式的角色特效，与背景无关，**保留**。
5. 测试用背景做像素测量的原理：`foregroundPixelBounds` 只统计 `alpha > 0.5` 的像素；背景删除后位图透明、文字像素仍在，**把 `settings.showsBackground/backgroundOpacity/backgroundColor` 三行设置删掉即可，测量逻辑不用改**。
6. `RunCatAnimation` 无任何现存测试覆盖轮换；`catRotationPool` 在测试中 0 处引用。**删除无测试负担。**

---

### Task 1: 修复「角色」「动画与轮换」区块的重复标题与卡片嵌套

**Files:**
- Modify: `Sources/NetBar/Preferences/MenuBarCharacterPreferencesView.swift:134-135`
- Modify: `Sources/NetBar/Preferences/MenuBarAnimationPreferencesView.swift:21-22`
- Modify: `Sources/NetBar/Preferences/MenuBarSubcomponents.swift:5-20, 372-373`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

**Interfaces:**
- Consumes: 现有 `CollapsiblePreferenceSection`（`PreferencesComponents.swift:6`）、`PreferenceSection`（`PreferencesComponents.swift:56`）。
- Produces: `MenuBarCharacterSection.body` / `MenuBarAnimationSection.body` 直接输出内容（不再自包 `PreferenceSection`）；`MenuBarPreferenceGroup` 枚举被删除；`AnimatedPreviewSection` 改用内联标题字符串。

**背景:** `MenuBarPreferencesView` 用 `CollapsiblePreferenceSection(title: "角色")` 包裹 `MenuBarCharacterSection`，而后者 body 又自包一层 `PreferenceSection(title: 同名)`——标题渲染两遍、卡片套卡片。「显示内容」「宽度与布局」两个兄弟区块无此问题，风格不一致。

- [ ] **Step 1: 写失败的源码扫描测试**

在 `Tests/NetBarTests/PreferencesAndPresentationTests.swift` 的 `testAnimatedCharacterCatalogDoesNotRunItsOwnTimer`（第 371 行）之后新增：

```swift
    func testMenuBarSectionsDoNotNestPreferenceSectionInsideCollapsibleSection() throws {
        let characterSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Preferences", "MenuBarCharacterPreferencesView.swift"]
        )
        let animationSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Preferences", "MenuBarAnimationPreferencesView.swift"]
        )
        let subcomponentsSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Preferences", "MenuBarSubcomponents.swift"]
        )

        XCTAssertFalse(characterSource.contains("PreferenceSection(title: MenuBarPreferenceGroup"))
        XCTAssertFalse(animationSource.contains("PreferenceSection(title: MenuBarPreferenceGroup"))
        XCTAssertFalse(subcomponentsSource.contains("enum MenuBarPreferenceGroup"))
    }
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter testMenuBarSectionsDoNotNestPreferenceSectionInsideCollapsibleSection`
Expected: FAIL（三个断言全部命中现有代码）

- [ ] **Step 3: 去掉 `MenuBarCharacterSection` 的内层 `PreferenceSection` 包装**

`Sources/NetBar/Preferences/MenuBarCharacterPreferencesView.swift:134-135`，把：

```swift
    var body: some View {
        PreferenceSection(title: MenuBarPreferenceGroup.character.title(language: appPreferences.resolvedLanguage)) {
            Toggle(appPreferences.text("启用角色", "Enable Character"), isOn: $settings.showsCat)
```

改为（同时删除函数末尾对应的闭合括号，整体少一层缩进）：

```swift
    var body: some View {
        Toggle(appPreferences.text("启用角色", "Enable Character"), isOn: $settings.showsCat)
```

body 内其余内容（`if settings.showsCat {...} else {...}`）原样保留，只是去掉一层嵌套缩进。

- [ ] **Step 4: 去掉 `MenuBarAnimationSection` 的内层 `PreferenceSection` 包装**

`Sources/NetBar/Preferences/MenuBarAnimationPreferencesView.swift:21-22`，把：

```swift
    var body: some View {
        PreferenceSection(title: MenuBarPreferenceGroup.animation.title(language: appPreferences.resolvedLanguage)) {
            if settings.showsCat {
```

改为（同样删除末尾多余闭合括号）：

```swift
    var body: some View {
        if settings.showsCat {
```

- [ ] **Step 5: 删除 `MenuBarPreferenceGroup` 枚举并内联预览标题**

`Sources/NetBar/Preferences/MenuBarSubcomponents.swift`：

删除 5-20 行整个枚举：

```swift
enum MenuBarPreferenceGroup {
    case preview
    case character
    case animation

    func title(language: AppLanguage) -> String {
        switch self {
        case .preview:
            return language.text("实时预览", "Live Preview")
        case .character:
            return language.text("角色", "Character")
        case .animation:
            return language.text("动画与轮换", "Animation & Rotation")
        }
    }
}
```

372-373 行 `AnimatedPreviewSection.body` 中，把：

```swift
        PreferenceSection(title: MenuBarPreferenceGroup.preview.title(language: appPreferences.resolvedLanguage)) {
```

改为：

```swift
        PreferenceSection(title: appPreferences.text("实时预览", "Live Preview")) {
```

（预览区不在折叠区块内，保留其 `PreferenceSection` 包装。）

- [ ] **Step 6: 运行测试确认通过**

Run: `swift test --filter testMenuBarSectionsDoNotNestPreferenceSectionInsideCollapsibleSection`
Expected: PASS

- [ ] **Step 7: 跑全量测试**

Run: `swift test`
Expected: 全部通过，0 failures

- [ ] **Step 8: 提交**

```bash
git add Sources/NetBar/Preferences/MenuBarCharacterPreferencesView.swift Sources/NetBar/Preferences/MenuBarAnimationPreferencesView.swift Sources/NetBar/Preferences/MenuBarSubcomponents.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "refactor(prefs): 修复菜单栏角色/动画区块重复标题与嵌套卡片"
```

---

### Task 2: 分组重排——角色外观移入「角色」区、对齐仅在手动宽度显示、删开发者文案

**Files:**
- Modify: `Sources/NetBar/Preferences/MenuBarAnimationPreferencesView.swift:24-67`
- Modify: `Sources/NetBar/Preferences/MenuBarCharacterPreferencesView.swift:160-164`
- Modify: `Sources/NetBar/Preferences/MenuBarLayoutPreferencesView.swift:50-56`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

**Interfaces:**
- Consumes: Task 1 产出的无内层包装的 `MenuBarAnimationSection` / `MenuBarCharacterSection` 结构；现有 `MenuBarSubsectionHeader`、`SliderPreference`。
- Produces: `catPosition`/`catFacing`/`catScale` 三个控件从动画区移至角色区（`MenuBarCharacterSection` 末尾「位置与大小」小节）；「对齐」Picker 仅在 `!usesAutomaticWidth` 时渲染。

**背景:** 「角色位置/角色朝向/角色大小」是角色外观属性而非动画属性；「对齐」在自动宽度（默认）下无效果；两段说明文案（Retina bitmap 渲染说明、速度倍率科普）是开发者视角内容。

- [ ] **Step 1: 写失败的源码扫描测试**

在 Task 1 的测试后新增：

```swift
    func testMenuBarSectionsRegroupCharacterAppearanceControls() throws {
        let animationSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Preferences", "MenuBarAnimationPreferencesView.swift"]
        )
        let characterSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Preferences", "MenuBarCharacterPreferencesView.swift"]
        )
        let layoutSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Preferences", "MenuBarLayoutPreferencesView.swift"]
        )

        // 位置/朝向/大小属于角色外观,移入角色区
        XCTAssertFalse(animationSource.contains("catPosition"))
        XCTAssertFalse(animationSource.contains("catFacing"))
        XCTAssertFalse(animationSource.contains("catScale"))
        XCTAssertTrue(characterSource.contains("catPosition"))
        XCTAssertTrue(characterSource.contains("catFacing"))
        XCTAssertTrue(characterSource.contains("catScale"))

        // 删除开发者视角文案
        XCTAssertFalse(animationSource.contains("速度倍率影响动画快慢"))

        // 对齐仅在手动宽度下显示(文件中共出现两次 if !settings.usesAutomaticWidth:
        // 手动宽度滑杆 + 对齐 Picker)
        XCTAssertEqual(layoutSource.components(separatedBy: "if !settings.usesAutomaticWidth").count - 1, 2)
    }
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter testMenuBarSectionsRegroupCharacterAppearanceControls`
Expected: FAIL

- [ ] **Step 3: 精简动画区——删位置/朝向/大小与倍率文案**

`Sources/NetBar/Preferences/MenuBarAnimationPreferencesView.swift` 的 `body`（Task 1 后已无 `PreferenceSection` 包装），`if settings.showsCat {` 分支的开头由：

```swift
            Picker(appPreferences.text("角色位置", "Character Position"), selection: $settings.catPosition) {
                ForEach(StatusBarCharacterPosition.allCases) { position in
                    Text(position.title(language: appPreferences.resolvedLanguage)).tag(position)
                }
            }
            .pickerStyle(.segmented)

            Picker(appPreferences.text("角色朝向", "Character Facing"), selection: $settings.catFacing) {
                ForEach(StatusBarCharacterFacing.allCases) { facing in
                    Text(facing.title(language: appPreferences.resolvedLanguage)).tag(facing)
                }
            }
            .pickerStyle(.segmented)

            SliderPreference(
                title: appPreferences.text("角色大小", "Character Size"),
                value: $settings.catScale,
                range: 0.7...1.3,
                displayValue: "\(Int((settings.catScale * 100).rounded()))%"
            )

            SliderPreference(
                title: appPreferences.text("动画速度", "Animation Speed"),
```

改为直接以动画速度滑杆开头：

```swift
            SliderPreference(
                title: appPreferences.text("动画速度", "Animation Speed"),
```

并删除速度来源 Picker 之后的整段说明文案（保留其后的 `Divider()`）：

```swift
                Text(appPreferences.text(
                    "速度倍率影响动画快慢：1.0x 为默认，2.0x 为两倍速，0.5x 为半速。",
                    "Speed multiplier affects animation rate: 1.0x is default, 2.0x is double speed, 0.5x is half speed."
                ))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
```

（轮换角色池网格本任务不动，Task 4 处理。）

- [ ] **Step 4: 角色区新增「位置与大小」小节**

`Sources/NetBar/Preferences/MenuBarCharacterPreferencesView.swift` 的 `body` 中，找到颜色控制块：

```swift
                let selectedChar = selectedCharacterAsset()
                if selectedChar.supportsColorControls {
                    Divider()
                    characterColorControls
                }
```

在其**前面**插入：

```swift
                Divider()

                MenuBarSubsectionHeader(
                    systemImage: "arrow.left.and.right.square",
                    title: appPreferences.text("位置与大小", "Position & Size")
                )

                Picker(appPreferences.text("角色位置", "Character Position"), selection: $settings.catPosition) {
                    ForEach(StatusBarCharacterPosition.allCases) { position in
                        Text(position.title(language: appPreferences.resolvedLanguage)).tag(position)
                    }
                }
                .pickerStyle(.segmented)

                Picker(appPreferences.text("角色朝向", "Character Facing"), selection: $settings.catFacing) {
                    ForEach(StatusBarCharacterFacing.allCases) { facing in
                        Text(facing.title(language: appPreferences.resolvedLanguage)).tag(facing)
                    }
                }
                .pickerStyle(.segmented)

                SliderPreference(
                    title: appPreferences.text("角色大小", "Character Size"),
                    value: $settings.catScale,
                    range: 0.7...1.3,
                    displayValue: "\(Int((settings.catScale * 100).rounded()))%"
                )
```

- [ ] **Step 5: 「对齐」仅在手动宽度下显示**

`Sources/NetBar/Preferences/MenuBarLayoutPreferencesView.swift:50-56`，把：

```swift
        Picker(appPreferences.text("对齐", "Alignment"), selection: $settings.alignment) {
            ForEach(StatusBarAlignment.allCases) { alignment in
                Text(alignment.title(language: appPreferences.resolvedLanguage)).tag(alignment)
            }
        }
        .pickerStyle(.segmented)
```

改为：

```swift
        if !settings.usesAutomaticWidth {
            Picker(appPreferences.text("对齐", "Alignment"), selection: $settings.alignment) {
                ForEach(StatusBarAlignment.allCases) { alignment in
                    Text(alignment.title(language: appPreferences.resolvedLanguage)).tag(alignment)
                }
            }
            .pickerStyle(.segmented)
        }
```

- [ ] **Step 6: 运行测试确认通过**

Run: `swift test --filter testMenuBarSectionsRegroupCharacterAppearanceControls`
Expected: PASS

- [ ] **Step 7: 跑全量测试**

Run: `swift test`
Expected: 全部通过，0 failures

- [ ] **Step 8: 提交**

```bash
git add Sources/NetBar/Preferences/MenuBarAnimationPreferencesView.swift Sources/NetBar/Preferences/MenuBarCharacterPreferencesView.swift Sources/NetBar/Preferences/MenuBarLayoutPreferencesView.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "refactor(prefs): 角色外观控件移入角色区,对齐仅手动宽度显示,删开发者文案"
```

---

### Task 3: 裁剪「行距」偏好——渲染器固定为原默认值 -2.0

**Files:**
- Modify: `Sources/NetBar/StatusBarStyle.swift`（删 lineSpacing 全套）
- Modify: `Sources/NetBar/StatusBarRenderer.swift:20,218,651,753-761`
- Modify: `Sources/NetBar/StatusBarRenderCache.swift:112-119`
- Modify: `Sources/NetBar/Preferences/MenuBarLayoutPreferencesView.swift:27-32`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift:264-284`

**Interfaces:**
- Consumes: 无（独立于 Task 1/2）。
- Produces: `StatusBarSettings` 不再有 `lineSpacing`/`clampedLineSpacing`；`StatusBarRenderSignature` 与 `StatusBarTextLayoutCacheKey` 不再有 `lineSpacing` 字段；渲染器新增私有常量 `StatusBarDisplayRenderer.statusBarLineSpacingAdjustment: CGFloat = -2.0`。

**背景:** 行距是 -5…8 的像素级微调，典型无人使用；默认 -2.0 对所有字号适用。删除后渲染结果与默认状态完全一致。测试仅 1 处引用（缓存键构造）。

- [ ] **Step 1: 写失败测试（旧 key 被忽略 + 缓存键缩形）**

在 `Tests/NetBarTests/PreferencesAndPresentationTests.swift` 新增：

```swift
    func testLegacyLineSpacingPreferenceIsIgnoredBySignature() {
        let legacyDefaults = isolatedDefaults()
        legacyDefaults.set(6.0, forKey: "statusBar.lineSpacing")
        let legacySettings = StatusBarSettings(defaults: legacyDefaults)
        let plainSettings = StatusBarSettings(defaults: isolatedDefaults())
        let snapshot = sampleSnapshot(download: 42_000, upload: 9_500)

        let legacySignature = StatusBarDisplayRenderer.signature(
            snapshot: snapshot,
            settings: legacySettings,
            appearanceName: "NSAppearanceNameAqua",
            reduceMotion: true
        )
        let plainSignature = StatusBarDisplayRenderer.signature(
            snapshot: snapshot,
            settings: plainSettings,
            appearanceName: "NSAppearanceNameAqua",
            reduceMotion: true
        )

        XCTAssertEqual(legacySignature, plainSignature)
    }
```

（`reduceMotion: true` 使签名里的时间桶恒为 0，两次调用可比较。）

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter testLegacyLineSpacingPreferenceIsIgnoredBySignature`
Expected: 编译失败或 FAIL——本任务做完前该测试可能通过（因为设置还没删），真正的失败信号是 Step 3 删掉 `lineSpacing` 后**全量编译报错**，本测试用例保障的是回归（若有人把 key 加回来，旧值会改变签名导致失败）。先跑一次记录基线即可。

- [ ] **Step 3: 从 `StatusBarSettings` 删除 lineSpacing**

`Sources/NetBar/StatusBarStyle.swift`，删除以下各行（行号为当前文件快照，实际以内容定位）：

- 第 9 行属性：`@Published var lineSpacing: Double { didSet { save() } }`
- 第 41 行 init：`lineSpacing = defaults.object(forKey: Keys.lineSpacing) as? Double ?? Defaults.lineSpacing`
- 第 75-77 行计算属性：

```swift
    var clampedLineSpacing: CGFloat {
        CGFloat(lineSpacing.clamped(to: -5...8))
    }
```

- 第 100 行 reset：`lineSpacing = Defaults.lineSpacing`
- 第 130 行 save：`defaults.set(lineSpacing, forKey: Keys.lineSpacing)`
- 第 180 行 Defaults：`static let lineSpacing = -2.0`
- 第 210 行 Keys：`static let lineSpacing = "statusBar.lineSpacing"`

- [ ] **Step 4: 渲染器改用内部常量**

`Sources/NetBar/StatusBarRenderer.swift`：

1. 删除签名结构体第 20 行 `let lineSpacing: Double`，及 `signature(...)` 构造中第 218 行 `lineSpacing: settings.lineSpacing,`。
2. `layout(...)` 中缓存键构造（第 651 行附近）删除 `lineSpacing: settings.lineSpacing,` 一行。
3. 在 `characterSpacing(settings:)`（约 574 行）旁新增常量：

```swift
    /// 两行上下行布局的固定行高修正。原为用户偏好 statusBar.lineSpacing
    /// (默认 -2.0),精简设置面后固定为原默认值。
    private static let statusBarLineSpacingAdjustment: CGFloat = -2.0
```

4. `attributedText(...)` 内（约 761 行）把：

```swift
        return max(naturalLineHeight + settings.clampedLineSpacing, 8)
```

改为：

```swift
        return max(naturalLineHeight + Self.statusBarLineSpacingAdjustment, 8)
```

- [ ] **Step 5: 缓存键与偏好 UI 删除 lineSpacing**

1. `Sources/NetBar/StatusBarRenderCache.swift:116` 删除 `let lineSpacing: Double`。
2. `Sources/NetBar/Preferences/MenuBarLayoutPreferencesView.swift:27-32` 删除行距滑杆：

```swift
        SliderPreference(
            title: appPreferences.text("行距", "Line spacing"),
            value: $settings.lineSpacing,
            range: -5...8,
            displayValue: String(format: "%.1f", settings.lineSpacing)
        )
```

- [ ] **Step 6: 更新受影响的既有测试**

`Tests/NetBarTests/PreferencesAndPresentationTests.swift` 的 `testStatusBarTextLayoutCacheReusesMatchingInputs`（约 267-274 行），缓存键构造删除一行：

```swift
        let key = StatusBarTextLayoutCacheKey(
            lines: ["down", "up"],
            fontSize: settings.fontSize,
            isBold: settings.isBold,
            lineSpacing: settings.lineSpacing,
            alignment: settings.alignment,
            showsBackground: settings.showsBackground
        )
```

改为：

```swift
        let key = StatusBarTextLayoutCacheKey(
            lines: ["down", "up"],
            fontSize: settings.fontSize,
            isBold: settings.isBold,
            alignment: settings.alignment,
            showsBackground: settings.showsBackground
        )
```

- [ ] **Step 7: 跑全量测试**

Run: `swift test`
Expected: 编译通过，全部测试通过（含 Step 1 新增测试与 Task 1/2 的源码扫描测试），0 failures

- [ ] **Step 8: 提交**

```bash
git add Sources/NetBar/StatusBarStyle.swift Sources/NetBar/StatusBarRenderer.swift Sources/NetBar/StatusBarRenderCache.swift Sources/NetBar/Preferences/MenuBarLayoutPreferencesView.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "refactor(menubar): 移除行距偏好,渲染器固定为原默认值 -2.0"
```

---

### Task 4: 裁剪「轮换角色池」+ 轮换改洗牌循环 + 颜色预设精简 + 文字/角色颜色解耦

**Files:**
- Modify: `Sources/NetBar/StatusBarStyle.swift`（删 catRotationPool）
- Modify: `Sources/NetBar/StatusBarController.swift:11-28, 354-361`
- Modify: `Sources/NetBar/RunCatAnimation.swift:203-206, 363-365, 369-404`
- Modify: `Sources/NetBar/Preferences/MenuBarAnimationPreferencesView.swift:7-19, 83-115`
- Modify: `Sources/NetBar/Preferences/MenuBarCharacterPreferencesView.swift:11-17, 60, 204, 295-335`
- Modify: `Sources/NetBar/Preferences/MenuBarSubcomponents.swift:59-63`
- Modify: `Sources/NetBar/Preferences/PreferencesComponents.swift:112-116`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

**Interfaces:**
- Consumes: Task 2 后的动画区结构（轮换池网格是 `if settings.catRotationEnabled` 块内最后一段）。
- Produces: `RunCatAnimation.configureRotation(enabled:intervalMinutes:)`（**签名去掉 pool 参数**）；`RunCatAnimation.rotateCharacterForTesting()`（测试钩子，模式同 `advanceFrameForTesting()`）；轮换改为**洗牌循环**语义——队列耗尽时重建打乱的全量队列，每个角色每轮恰好出现一次；`StatusBarCatAnimationConfiguration` 去掉 `catRotationPool` 字段；`StatusBarSettings` 不再有 `catRotationPool`。

**背景:** 轮换池是动画区里重复摆一份 35 角色复选框网格的边缘功能（测试 0 覆盖）。同时修复一个现存体验问题：`rotateToNextCharacter()` 用均匀随机抽取（只排除当前角色），35 个角色下短期内会反复出现少数角色、漏掉其余——按默认 5 分钟间隔，第一个小时平均只能见到约 18 个不同角色（期望 distinct = 35·(1−(34/35)ⁿ)，n=12），用户感知为「只有几个角色在轮换」。颜色区 9 个预设 + 「选角色颜色自动关系统文字颜色」联动 + 警告横幅是 UX 债——渲染器对「系统文字颜色 + 自定义角色颜色」组合早已正确处理（见计划头「背景调研结论」第 3 条），联动可整体删除。

- [ ] **Step 1: 写失败测试**

在 `Tests/NetBarTests/PreferencesAndPresentationTests.swift` 新增三个测试（前两个是源码扫描，第三个是**真正的行为测试**——轮换逻辑此前零覆盖）：

```swift
    func testRotationPoolPreferenceIsRemoved() throws {
        let sources: [[String]] = [
            ["Sources", "NetBar", "StatusBarStyle.swift"],
            ["Sources", "NetBar", "StatusBarController.swift"],
            ["Sources", "NetBar", "RunCatAnimation.swift"],
            ["Sources", "NetBar", "Preferences", "MenuBarAnimationPreferencesView.swift"]
        ]
        for pathComponents in sources {
            let source = try sourceFileContent(pathComponents: pathComponents)
            XCTAssertFalse(source.contains("catRotationPool"), "\(pathComponents.last ?? "") still references catRotationPool")
            XCTAssertFalse(source.contains("rotationPool"), "\(pathComponents.last ?? "") still references rotationPool")
        }
    }

    func testCharacterColorChoicesDoNotOverrideSystemTextColor() throws {
        let settings = StatusBarSettings(defaults: isolatedDefaults())

        settings.catColor = PersistedColor(red: 0.02, green: 0.18, blue: 1.0, alpha: 1)
        settings.catColorMode = CatColorMode.solid.rawValue
        XCTAssertTrue(settings.usesSystemTextColor)

        // 角色区不再包含任何自动关闭系统文字颜色的联动代码
        let characterSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Preferences", "MenuBarCharacterPreferencesView.swift"]
        )
        XCTAssertFalse(characterSource.contains("usesSystemTextColor"))
        XCTAssertEqual(characterSource.components(separatedBy: "PresetColorButton(").count - 1, 5)
    }

    func testCharacterRotationCoversAllCharactersPerCycle() {
        var rotatedIDs: [String] = []
        let animation = RunCatAnimation(
            character: CharacterAsset(builtIn: RunCatCharacter.defaultCat),
            onFrameChange: { _ in }
        )
        animation.onCharacterChange = { rotatedIDs.append($0.id) }
        animation.configureRotation(enabled: true, intervalMinutes: 1)

        let total = RunCatCharacter.allCharacters.count
        for _ in 0..<total {
            animation.rotateCharacterForTesting()
        }

        XCTAssertEqual(rotatedIDs.count, total)
        // 首轮洗牌循环:除初始角色外,每个角色恰好出现一次、不遗漏
        let firstCycle = rotatedIDs.prefix(total - 1)
        XCTAssertEqual(Set(firstCycle).count, total - 1)
        XCTAssertFalse(firstCycle.contains(RunCatCharacter.defaultCat.id))
        // 任意相邻两次轮换不重复
        XCTAssertTrue(
            zip(rotatedIDs, rotatedIDs.dropFirst()).allSatisfy { $0 != $1 }
        )
    }
```

（构造方式对齐现有 `testRunCatAnimationUsesCustomFrameCount`：`RunCatAnimation` 是 `@MainActor` 类，XCTest 方法在主线程执行，直接构造即可；不调用 `setActive`，不产生真实定时器。）

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter "testRotationPoolPreferenceIsRemoved|testCharacterColorChoicesDoNotOverrideSystemTextColor|testCharacterRotationCoversAllCharactersPerCycle"`
Expected: FAIL（rotationPool 满屏存在；characterSource 含 usesSystemTextColor 与 9 个 PresetColorButton；`rotateCharacterForTesting` 不存在导致编译失败——编译失败即失败信号）

- [ ] **Step 3: 删除 `StatusBarSettings.catRotationPool`**

`Sources/NetBar/StatusBarStyle.swift` 删除：
- 第 30 行属性：`@Published var catRotationPool: String { didSet { save() } }  // comma-separated character IDs`
- 第 62 行 init：`catRotationPool = defaults.string(forKey: Keys.catRotationPool) ?? Defaults.catRotationPool`
- 第 121 行 reset：`catRotationPool = Defaults.catRotationPool`
- 第 151 行 save：`defaults.set(catRotationPool, forKey: Keys.catRotationPool)`
- 第 201 行 Defaults：`static let catRotationPool = ""  // empty = all characters`
- 第 231 行 Keys：`static let catRotationPool = "statusBar.catRotationPool"`

- [ ] **Step 4: `StatusBarController` 去掉池子 plumbing**

`Sources/NetBar/StatusBarController.swift`：

1. `StatusBarCatAnimationConfiguration`（11-28 行）删除字段与 init 赋值各一行：

```swift
    let catRotationPool: String
```

```swift
        self.catRotationPool = settings.catRotationPool
```

2. `setupCatAnimation()` 中（354-361 行）把：

```swift
            // Configure rotation
            let poolIds = settings.catRotationPool.split(separator: ",").map(String.init)
            let pool = poolIds.isEmpty ? [] : poolIds.compactMap { id in RunCatCharacter.allCharacters.first { $0.id == id } }
            catAnimation?.configureRotation(
                enabled: settings.catRotationEnabled && !character.isCustom,
                intervalMinutes: settings.catRotationIntervalMinutes,
                pool: pool
            )
```

改为：

```swift
            // Configure rotation
            catAnimation?.configureRotation(
                enabled: settings.catRotationEnabled && !character.isCustom,
                intervalMinutes: settings.catRotationIntervalMinutes
            )
```

- [ ] **Step 5: `RunCatAnimation` 轮换改为洗牌循环**

`Sources/NetBar/RunCatAnimation.swift`：

1. 删除第 206 行属性：`var rotationPool: [RunCatCharacter] = []  // empty = all characters`，在同一位置（Rotation settings 注释块内）改为：

```swift
    // Shuffle-cycle queue: rebuilt (excluding current) when drained, so every
    // character appears exactly once per cycle instead of uniform random
    // sampling that repeats some characters and starves others.
    private var rotationQueue: [RunCatCharacter] = []
```

2. `configureRotation`（386-393 行）改为：

```swift
    func configureRotation(enabled: Bool, intervalMinutes: Double) {
        rotationEnabled = enabled
        rotationIntervalMinutes = intervalMinutes
        if isActive {
            scheduleRotationTimer()
        }
    }
```

3. `scheduleRotationTimer`（369-384 行）开头把：

```swift
        guard rotationEnabled else { return }
        let pool = rotationPool.isEmpty ? RunCatCharacter.allCharacters : rotationPool
        guard pool.count > 1 else { return }  // No rotation needed with only 1 character
```

改为：

```swift
        guard rotationEnabled else { return }
        guard RunCatCharacter.allCharacters.count > 1 else { return }  // No rotation needed with only 1 character
```

4. `rotateToNextCharacter`（395-404 行）改为：

```swift
    private func rotateToNextCharacter() {
        let allCharacters = RunCatCharacter.allCharacters
        guard allCharacters.count > 1 else { return }

        if rotationQueue.isEmpty {
            rotationQueue = allCharacters.filter { $0.id != character.id }.shuffled()
        }

        // A manual character switch can leave the current character in the
        // queue; drop it so one rotation never redisplays the same character.
        rotationQueue.removeAll { $0.id == character.id }
        guard let next = rotationQueue.first else {
            rotationQueue = []
            return
        }
        rotationQueue.removeFirst()

        character = AnimatedCharacter(character: next)
        currentFrame = 0
        onCharacterChange?(next)
    }
```

5. 在 `advanceFrameForTesting()`（约 363 行）旁新增测试钩子，模式一致：

```swift
    func rotateCharacterForTesting() {
        rotateToNextCharacter()
    }
```

语义说明：首轮队列 = 全部角色（排除当前）打乱；每次轮换弹出队首；队列耗尽后重建。保证每个角色每轮恰好出现一次、相邻两次不重复；循环边界（上一轮最后角色 == 当前角色）天然被「重建时排除当前角色」覆盖。

- [ ] **Step 6: 删除动画区轮换池 UI**

`Sources/NetBar/Preferences/MenuBarAnimationPreferencesView.swift`：

1. 删除 7-19 行的 `rotationPoolSet` 计算属性与 `toggleRotationPoolCharacter(_:)` 函数。
2. `if settings.catRotationEnabled {` 块内，轮换间隔滑杆之后删除整段池子网格（83-115 行，完整内容如下）：

```swift
                    let pool = rotationPoolSet
                    VStack(alignment: .leading, spacing: 6) {
                        MenuBarSubsectionHeader(
                            systemImage: "shuffle",
                            title: appPreferences.text("轮换角色池（空=全部）", "Rotation Pool (empty=all)")
                        )

                        ForEach(RunCatCharacter.Category.allCases, id: \.rawValue) { category in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(category.rawValue)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                let charsInCategory = RunCatCharacter.allCharacters.filter { $0.category == category }
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 86))], spacing: 3) {
                                    ForEach(charsInCategory) { character in
                                        Button(action: {
                                            toggleRotationPoolCharacter(character.id)
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: pool.contains(character.id) ? "checkmark.square" : "square")
                                                    .font(.system(size: 9))
                                                Text(character.displayName)
                                                    .font(.system(size: 11))
                                                    .lineLimit(1)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
```

保留块内只剩「轮换间隔」滑杆。

- [ ] **Step 7: 角色区——删联动、精简预设、删警告横幅**

`Sources/NetBar/Preferences/MenuBarCharacterPreferencesView.swift`：

1. `applyCatColor`（11-17 行）改为：

```swift
    private func applyCatColor(_ color: Color) {
        settings.catColor = PersistedColor(color: color)
    }
```

2. `importCustomCharacter()` 的 Task 闭包里（约 60 行）删除一行：`settings.usesSystemTextColor = false`
3. 自定义角色网格的 Button action（约 204 行）删除一行：`settings.usesSystemTextColor = false`
4. 预设色块（295-305 行）删 4 留 5——删除 orange/yellow/cyan/purple 四行，保留：

```swift
                        PresetColorButton(color: .white, label: characterColorLabel("白色", "White"), settings: settings)
                        PresetColorButton(color: .black, label: characterColorLabel("黑色", "Black"), settings: settings)
                        PresetColorButton(color: .red, label: characterColorLabel("红色", "Red"), settings: settings)
                        PresetColorButton(color: .green, label: characterColorLabel("绿色", "Green"), settings: settings)
                        PresetColorButton(color: .blue, label: characterColorLabel("蓝色", "Blue"), settings: settings)
```

5. `characterColorControls` 末尾删除整段橙色警告（323-335 行，完整内容如下）：

```swift
            if settings.usesSystemTextColor && (settings.catColorMode != CatColorMode.solid.rawValue || settings.catColor != PersistedColor.white) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 10))
                    Text(appPreferences.text(
                        "系统文字颜色会覆盖角色颜色，已自动切换为自定义颜色",
                        "System text color overrides character color, auto-switched to custom color"
                    ))
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                }
            }
```

- [ ] **Step 8: 其余两处联动删除**

1. `Sources/NetBar/Preferences/MenuBarSubcomponents.swift` `CharacterColorModePicker`（59-63 行）删除 `.onChange` 修饰符整段：

```swift
            .onChange(of: settings.catColorMode) { newMode in
                if newMode != CatColorMode.solid.rawValue && settings.usesSystemTextColor {
                    settings.usesSystemTextColor = false
                }
            }
```

2. `Sources/NetBar/Preferences/PreferencesComponents.swift` `PresetColorButton` 的 action（112-116 行）改为：

```swift
        Button {
            settings.catColor = PersistedColor(color: color)
        } label: {
```

- [ ] **Step 9: 运行新测试与全量测试**

Run: `swift test --filter "testRotationPoolPreferenceIsRemoved|testCharacterColorChoicesDoNotOverrideSystemTextColor|testCharacterRotationCoversAllCharactersPerCycle"`
Expected: PASS（轮换行为测试验证：35 次轮换 = 首轮 34 个互不重复且不含初始角色 + 循环边界 1 次，且任意相邻两次不同）

Run: `swift test`
Expected: 全部通过，0 failures

- [ ] **Step 10: 提交**

```bash
git add Sources/NetBar/StatusBarStyle.swift Sources/NetBar/StatusBarController.swift Sources/NetBar/RunCatAnimation.swift Sources/NetBar/Preferences/MenuBarAnimationPreferencesView.swift Sources/NetBar/Preferences/MenuBarCharacterPreferencesView.swift Sources/NetBar/Preferences/MenuBarSubcomponents.swift Sources/NetBar/Preferences/PreferencesComponents.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "refactor(menubar): 移除轮换角色池,颜色预设精简为5个,解耦文字/角色颜色"
```

---

### Task 5: 移除菜单栏背景渲染子系统

**Files:**
- Modify: `Sources/NetBar/StatusBarStyle.swift`（删 3 个背景字段）
- Modify: `Sources/NetBar/StatusBarRenderer.swift:4-13, 20-43, 45-72, 188-192, 224-233, 248-251, 316-336, 362, 578-580, 605, 646, 653`
- Modify: `Sources/NetBar/StatusBarRenderCache.swift:118`
- Modify: `Sources/NetBar/Preferences/MenuBarDisplayPreferencesView.swift`（整文件重写为纯文字样式）
- Modify: `Sources/NetBar/Preferences/MenuBarSubcomponents.swift`（预览死分支 + 摘要徽章）
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`（6 处删改）

**Interfaces:**
- Consumes: Task 3 后的 `StatusBarRenderSignature`（已无 lineSpacing）、`StatusBarTextLayoutCacheKey`（已无 lineSpacing，仍含 showsBackground）。
- Produces: `StatusBarSettings` 不再有 `showsBackground`/`backgroundOpacity`/`backgroundColor`；`StatusBarPresentation` 不再有 `kind` 字段、`StatusBarPresentationKind` 枚举删除；`StatusBarPulseRenderPolicy` 枚举删除；`StatusBarRenderSignature` 不再有 `showsBackground`/`backgroundOpacity`/`backgroundColor`/`statusPulseTimeBucket`；`StatusBarTextLayoutCacheKey` 不再有 `showsBackground`；`StatusBarDisplayRenderer.attributedTitle` 删除；渲染器新增 `private static let horizontalTextPadding: CGFloat = 2` 取代 `horizontalPadding(settings:)`；`useTemplate = settings.usesSystemTextColor && !catHasCustomColor`。

**背景:** 背景默认关闭，为它维护了 bitmap 填充、流量脉冲高亮、模板模式例外条件和 3px 内边距。删除后状态栏恒走「透明位图」路径，默认外观不变。这是最大的一步，必须最后做、单独提交，方便回滚。

- [ ] **Step 1: 删除 `StatusBarSettings` 的 3 个背景字段**

`Sources/NetBar/StatusBarStyle.swift` 删除（属性/init/reset/save/Defaults/Keys 各处，行号以内容定位）：

- 属性：`showsBackground`、`backgroundOpacity`、`backgroundColor`（第 15、16、19 行；保留中间的 `usesSystemTextColor`、`textColor`）
- init：`showsBackground = ...`、`backgroundOpacity = ...`、`backgroundColor = Self.color(prefix: Keys.backgroundColor, ...)`（第 47、48、51 行）
- reset：`showsBackground = Defaults.showsBackground`、`backgroundOpacity = Defaults.backgroundOpacity`、`backgroundColor = Defaults.backgroundColor`（第 106、107、110 行）
- save：`defaults.set(showsBackground, ...)`、`defaults.set(backgroundOpacity, ...)`、`save(backgroundColor, prefix: Keys.backgroundColor)`（第 136、137、140 行）
- Defaults：`static let showsBackground = false`、`static let backgroundOpacity = 0.0`、`static let backgroundColor = PersistedColor.olive`（第 186、187、190 行）
- Keys：`statusBar.showsBackground`、`statusBar.backgroundOpacity`、`statusBar.backgroundColor`（第 215、216、220 行）

注意：`Self.color(prefix:...)`/`save(_:prefix:)` 私有帮助方法仍被 `textColor`/`catColor` 使用，**保留**；`PersistedColor.olive` 静态属性仍被测试用作测量参照色，**保留**。

- [ ] **Step 2: 渲染签名与呈现结构瘦身**

`Sources/NetBar/StatusBarRenderer.swift`：

1. 删除 4-7 行枚举：

```swift
@MainActor
enum StatusBarPresentationKind: Equatable {
    case nativeTitle
    case retinaImage
}
```

2. `StatusBarPresentation`（9-13 行）改为：

```swift
struct StatusBarPresentation: Equatable {
    let width: CGFloat
    let lines: [String]
}
```

3. `StatusBarRenderSignature`（15-43 行，Task 3 后已无 lineSpacing）再删除 4 个字段：`let showsBackground: Bool`、`let backgroundOpacity: Double`、`let backgroundColor: PersistedColor`、`let statusPulseTimeBucket: Int`。最终结构：

```swift
struct StatusBarRenderSignature: Equatable {
    let presentation: StatusBarPresentation
    let fontSize: Double
    let itemWidth: Double
    let usesAutomaticWidth: Bool
    let trafficDisplayMode: StatusBarTrafficDisplayMode
    let order: StatusBarOrder
    let alignment: StatusBarAlignment
    let showsArrows: Bool
    let isBold: Bool
    let usesSystemTextColor: Bool
    let textColor: PersistedColor
    let appearanceName: String
    let catFrameIndex: Int?
    let catCharacter: String
    let catScale: Double
    let catPosition: StatusBarCharacterPosition
    let catFacing: StatusBarCharacterFacing
    let catColor: PersistedColor
    let catColorMode: String
    let catColorTimeBucket: Int  // For dynamic modes: time quantized to ~250ms buckets
    let catHeadSwing: Bool
    let customCharacterRevision: Int
}
```

4. `signature(...)` 构造调用删除对应 4 行：`showsBackground: settings.showsBackground,`、`backgroundOpacity: settings.backgroundOpacity,`、`backgroundColor: settings.backgroundColor,`、`statusPulseTimeBucket: StatusBarPulseRenderPolicy.timeBucket(...)` 整段（含换行参数）。

   （顺带说明：脉冲删除后 `signature(...)` 的 `renderTime`/`reduceMotion` 两个形参不再被读取，保留无害；若顺手删除形参，需同步清理 `StatusBarPreviewRenderCache.render` 调用处传的 `renderTime: reduceMotion:` 两个实参。）

- [ ] **Step 3: 删除 `StatusBarPulseRenderPolicy` 与背景绘制**

`Sources/NetBar/StatusBarRenderer.swift`：

1. 删除 45-72 行整个 `StatusBarPulseRenderPolicy` 枚举。
2. `presentation(...)`（约 188-192 行）改为：

```swift
        return StatusBarPresentation(
            width: layout.width,
            lines: layout.lines
        )
```

3. 删除 248-251 行 `attributedTitle(snapshot:settings:)` 整个函数（唯一调用方是下一步删除的预览死分支）。
4. `image(...)` 主实现中，保留透明底清屏（`NSColor.clear.setFill()` 两行），**删除**紧随其后的背景与脉冲整块（319-336 行）：

```swift
        if settings.showsBackground {
            settings.backgroundColor.nsColor
                .withAlphaComponent(CGFloat(settings.backgroundOpacity.clamped(to: 0...1)))
                .setFill()
            NSRect(origin: .zero, size: size).fill()
            let pulseAlpha = StatusBarPulseRenderPolicy.pulseAlpha(
                snapshot: snapshot,
                reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                renderTime: renderTime
            )
            if pulseAlpha > 0 {
                let pulseColor = snapshot.uploadBytesPerSecond > snapshot.downloadBytesPerSecond
                    ? NSColor.systemOrange
                    : NSColor.systemTeal
                pulseColor.withAlphaComponent(pulseAlpha).setFill()
                NSRect(origin: .zero, size: size).fill()
            }
        }
```

5. 模板模式条件（约 362 行）改为：

```swift
        let useTemplate = settings.usesSystemTextColor && !catHasCustomColor
```

（注释「When cat has custom colors...」保留，仍准确。）

- [ ] **Step 4: 内边距常量化与缓存键收尾**

`Sources/NetBar/StatusBarRenderer.swift`：

1. `horizontalPadding(settings:)`（578-580 行）替换为常量（放在 `characterSpacing` 旁）：

```swift
    /// 状态项内容与两侧边缘的水平内距(背景模式曾用 3,背景移除后统一为 2)。
    private static let horizontalTextPadding: CGFloat = 2
```

2. 替换两处调用：`layout(...)` 内 `let horizontalPadding = horizontalPadding(settings: settings)` 与 `stableMinimumWidth(...)` 内 `let horizontalPadding = horizontalPadding(settings: settings)`，均改为 `let horizontalPadding = horizontalTextPadding`。（`Layout` 结构的 `horizontalPadding` 字段与 `image()` 中对 `layout.horizontalPadding` 的使用不动。）
3. `layout(...)` 中 `StatusBarTextLayoutCacheKey` 构造删除 `showsBackground: settings.showsBackground` 一行。

`Sources/NetBar/StatusBarRenderCache.swift:118` 删除 `let showsBackground: Bool`。

- [ ] **Step 5: 偏好 UI——「显示内容」只剩文字样式**

`Sources/NetBar/Preferences/MenuBarDisplayPreferencesView.swift` **整文件替换**为：

```swift
import SwiftUI

struct MenuBarDisplaySectionContent: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences

    private var textColorBinding: Binding<Color> {
        Binding(
            get: { settings.textColor.swiftUIColor },
            set: { settings.textColor = PersistedColor(color: $0) }
        )
    }

    var body: some View {
        MenuBarSubsectionHeader(
            systemImage: "textformat.size",
            title: appPreferences.text("文字样式", "Text Style")
        )

        SliderPreference(
            title: appPreferences.text("字号", "Font size"),
            value: $settings.fontSize,
            range: 8...18,
            displayValue: "\(Int(settings.fontSize.rounded()))"
        )

        HStack {
            Toggle(appPreferences.text("系统文字颜色", "System text color"), isOn: $settings.usesSystemTextColor)
            Toggle(appPreferences.text("加粗", "Bold"), isOn: $settings.isBold)
            Toggle(appPreferences.text("显示箭头", "Show arrows"), isOn: $settings.showsArrows)
        }

        if !settings.usesSystemTextColor {
            ColorPicker(appPreferences.text("文字颜色", "Text color"), selection: textColorBinding, supportsOpacity: true)
        }
    }
}
```

（`transparentBackgroundBinding`、`backgroundColorBinding`、`@Environment(\.accessibilityReduceMotion)` 随整段背景 UI 一并消失。）

- [ ] **Step 6: 预览死分支与摘要徽章**

`Sources/NetBar/Preferences/MenuBarSubcomponents.swift`：

1. `StatusBarPreview.body` 中删除 `nativeTitle` 分支与 `textAlignment` 辅助属性。渲染部分改为：

```swift
            let presentation = renderOutput.presentation

            Image(nsImage: renderOutput.image)
                .frame(
                    width: presentation.width,
                    height: max(NSStatusBar.system.thickness, 24)
                )
```

并删除文件末尾的：

```swift
    private var textAlignment: TextAlignment {
        switch settings.alignment {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        }
    }
```

2. `MenuBarSettingsSummary.body` 删除背景徽章（258-262 行）：

```swift
            NetBarBadge(
                text: settings.showsBackground ? appPreferences.text("背景开启", "Background on") : appPreferences.text("透明背景", "Transparent"),
                tone: settings.showsBackground ? .success : .neutral
            )
```

- [ ] **Step 7: 更新受影响测试**

`Tests/NetBarTests/PreferencesAndPresentationTests.swift`：

1. `testStatusBarAlwaysUsesRetinaImage`（36-51 行）：删除第 38 行 `settings.showsBackground = false`；删除第 45 行 `XCTAssertEqual(presentation.kind, .retinaImage)`；函数改名为 `testStatusBarPresentationExposesLinesAndStableWidth`。
2. `testStatusBarBackgroundAutomaticWidthUsesCompactHorizontalPadding`（53-83 行）：改名为 `testStatusBarAutomaticWidthUsesHorizontalTextPadding`；删除 `settings.showsBackground = true` 一行；两处期望 `ceil(stableTextWidth + 6)` 改为 `ceil(stableTextWidth + 4)`（内边距 2×2）。
3. 删除整个 `testStatusBarPulseRenderPolicyDisablesBucketForIdleAndReducedMotion`（约 193-211 行）。
4. 删除整个 `testStatusBarPulseRenderPolicyQuantizesActiveTrafficAtTwoHz`（约 213-240 行）。
5. 删除整个 `testStatusBarSignatureIncludesPulseBucketOnlyForActiveTraffic`（约 242-262 行）。
6. `testStatusBarTextLayoutCacheReusesMatchingInputs`：缓存键构造删除 `showsBackground: settings.showsBackground` 一行（Task 3 已删 lineSpacing，此处再删 showsBackground）。
7. 删除整个 `testStatusBarRetinaImageWithBackground`（358-369 行）。
8. `testRetinaStatusBarImageCentersTextVertically`（383-399 行）：删除 `settings.showsBackground = true`、`settings.backgroundOpacity = 1`、`settings.backgroundColor = .olive` 三行；**注意**第 396 行当前调用是 `foregroundPixelBounds(in: image, background: settings.backgroundColor)`（不是 `.olive`），属性删除后该行必须显式改为 `background: .olive` 才能编译。测量语义不变：透明底像素被 `alphaComponent > 0.5` 过滤跳过，白字与橄榄色距离约 2.17 > 0.35，仍能通过断言。
9. `testGoldenCatUsesSelectedSolidColorInsteadOfOriginalColor`（1584-1609 行）：删除 1590-1592 三行（`showsBackground`/`backgroundOpacity`/`backgroundColor`），其余不动。
10. 自定义角色红色像素测试（约 2011-2029 行）：删除 2014-2016 三行（同上），其余不动。

- [ ] **Step 8: 编译并全量测试**

Run: `swift test`
Expected: 编译通过，全部测试通过，0 failures（如出现 `showsBackground`/`backgroundOpacity`/`statusPulseTimeBucket`/`StatusBarPulseRenderPolicy`/`attributedTitle`/`StatusBarPresentationKind` 残留引用的编译错误，按报错位置逐一清理——它们都应只出现在本 Task 列出的文件里）

- [ ] **Step 9: 提交**

```bash
git add Sources/NetBar/StatusBarStyle.swift Sources/NetBar/StatusBarRenderer.swift Sources/NetBar/StatusBarRenderCache.swift Sources/NetBar/Preferences/MenuBarDisplayPreferencesView.swift Sources/NetBar/Preferences/MenuBarSubcomponents.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "refactor(menubar): 移除菜单栏背景渲染子系统(背景色/不透明度/脉冲高亮/死代码分支)"
```

---

### Task 6: 合并折叠区块——4 个 → 2 个（显示与布局 / 角色与动画）

**Files:**
- Modify: `Sources/NetBar/Preferences/MenuBarPreferencesView.swift:18-70`
- Modify: `Sources/NetBar/Preferences/MenuBarCharacterPreferencesView.swift`（body 末尾新增动画小节）
- Modify: `Sources/NetBar/Preferences/MenuBarAnimationPreferencesView.swift`（整文件重写为 `MenuBarAnimationControls`）
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

**Interfaces:**
- Consumes: Task 1 后无内层 `PreferenceSection` 包装；Task 2 后动画区已无位置/朝向/大小与倍率文案；Task 4 后轮换池已删。
- Produces: `struct MenuBarAnimationControls: View`（不再自持 `showsCat` 门控，父级保证角色已启用）；菜单栏 Tab 最终结构 = 实时预览 + 2 个折叠区（「显示与布局」「角色与动画」）+ 恢复默认按钮。

**背景:** 裁剪后「动画与轮换」只剩 5 个控件、「宽度与布局」只剩 5 个控件，独立折叠区失去意义；「显示内容 + 宽度与布局」同属文字/布局域，「角色 + 动画」同属角色域——动画区的空态提示与角色区的启用开关本就是重复门控，合并后消失。合并放在裁剪之后做，动的是最终形态的最小代码量。

- [ ] **Step 1: 写失败的源码扫描测试**

在 `Tests/NetBarTests/PreferencesAndPresentationTests.swift` 新增：

```swift
    func testMenuBarPreferencesUseTwoCollapsibleSections() throws {
        let rootSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Preferences", "MenuBarPreferencesView.swift"]
        )
        let animationSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Preferences", "MenuBarAnimationPreferencesView.swift"]
        )

        // 4 个折叠区合并为 2 个:显示与布局 / 角色与动画
        XCTAssertEqual(rootSource.components(separatedBy: "CollapsiblePreferenceSection(").count - 1, 2)
        XCTAssertTrue(rootSource.contains("显示与布局"))
        XCTAssertTrue(rootSource.contains("角色与动画"))

        // 动画控件改为小节内容视图,门控上移到父级角色区
        XCTAssertTrue(animationSource.contains("struct MenuBarAnimationControls"))
        XCTAssertFalse(animationSource.contains("showsCat"))
    }
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter testMenuBarPreferencesUseTwoCollapsibleSections`
Expected: FAIL（当前有 4 个 `CollapsiblePreferenceSection`，动画视图名为 `MenuBarAnimationSection` 且自持 `showsCat` 门控）

- [ ] **Step 3: 重写 `MenuBarPreferencesView` 为两个折叠区**

`Sources/NetBar/Preferences/MenuBarPreferencesView.swift` 的 `body` 改为：

```swift
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AnimatedPreviewSection(
                    settings: settings,
                    appPreferences: appPreferences,
                    customCharacterStore: customCharacterStore,
                    selectedCharacterAsset: characterSection.selectedCharacterAsset()
                )

                CollapsiblePreferenceSection(
                    title: appPreferences.text("显示与布局", "Display & Layout"),
                    systemImage: "textformat.size",
                    defaultExpanded: true
                ) {
                    MenuBarDisplaySectionContent(settings: settings, appPreferences: appPreferences)

                    Divider()

                    MenuBarLayoutSectionContent(settings: settings, appPreferences: appPreferences)
                }

                CollapsiblePreferenceSection(
                    title: appPreferences.text("角色与动画", "Character & Animation"),
                    systemImage: "pawprint",
                    defaultExpanded: true
                ) {
                    characterSection
                }

                HStack {
                    Spacer()
                    Button(appPreferences.text("恢复菜单栏默认值", "Restore Menu Bar Defaults")) {
                        settings.reset()
                    }
                }
            }
            .padding(.trailing, 2)
        }
    }
```

- [ ] **Step 4: 动画视图重写为控件小节**

`Sources/NetBar/Preferences/MenuBarAnimationPreferencesView.swift` **整文件替换**为（Task 2/4 已删去位置朝向/大小、倍率文案与轮换池；外层 `if settings.showsCat` 门控与空态文案上移到父级）：

```swift
import SwiftUI

/// 角色区「动画与轮换」小节内容。父级(MenuBarCharacterSection)已保证角色启用。
struct MenuBarAnimationControls: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        SliderPreference(
            title: appPreferences.text("动画速度", "Animation Speed"),
            value: $settings.catSpeedMultiplier,
            range: 0.25...4.0,
            displayValue: String(format: "%.1fx", settings.catSpeedMultiplier)
        )

        Picker(
            appPreferences.text("速度关联", "Speed Source"),
            selection: $settings.catAnimationSpeedSource
        ) {
            ForEach(AnimationSpeedSource.allCases) { source in
                Text(source.title(language: appPreferences.resolvedLanguage)).tag(source.rawValue)
            }
        }

        Divider()

        Toggle(appPreferences.text("摇头效果", "Head Swing"), isOn: $settings.catHeadSwing)

        Toggle(appPreferences.text("角色轮换", "Character Rotation"), isOn: $settings.catRotationEnabled)

        if settings.catRotationEnabled {
            SliderPreference(
                title: appPreferences.text("轮换间隔", "Rotation Interval"),
                value: $settings.catRotationIntervalMinutes,
                range: 1...60,
                displayValue: String(format: "%.0f分钟", settings.catRotationIntervalMinutes)
            )
        }
    }
}
```

- [ ] **Step 5: 角色区末尾挂载动画小节**

`Sources/NetBar/Preferences/MenuBarCharacterPreferencesView.swift` 的 `body` 中，`if settings.showsCat` 分支末尾（颜色控制块 `if selectedChar.supportsColorControls { ... }` 之后）追加：

```swift
                Divider()

                MenuBarSubsectionHeader(
                    systemImage: "hare",
                    title: appPreferences.text("动画与轮换", "Animation & Rotation")
                )

                MenuBarAnimationControls(settings: settings, appPreferences: appPreferences)
```

- [ ] **Step 6: 运行新测试与全量测试**

Run: `swift test --filter testMenuBarPreferencesUseTwoCollapsibleSections`
Expected: PASS

Run: `swift test`
Expected: 全部通过，0 failures（Task 1/2 的源码扫描测试不应受影响：`MenuBarAnimationControls` 无 `PreferenceSection` 包装、无 `catPosition`/`catScale`）

- [ ] **Step 7: 提交**

```bash
git add Sources/NetBar/Preferences/MenuBarPreferencesView.swift Sources/NetBar/Preferences/MenuBarCharacterPreferencesView.swift Sources/NetBar/Preferences/MenuBarAnimationPreferencesView.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "refactor(prefs): 菜单栏设置合并为两个折叠区(显示与布局/角色与动画)"
```

---

### Task 7: 文档同步与打包验证

**Files:**
- Modify: `CHANGELOG.md`（Unreleased 节）
- Modify: `README.md:33, 36, 125, 359`
- Modify: `PROJECT_MAP.md:126, 187, 188`

**Interfaces:**
- Consumes: Task 1-6 全部落地后的代码状态。
- Produces: 与代码一致的 CHANGELOG/README/PROJECT_MAP；本地打包验证通过。

- [ ] **Step 1: 更新 CHANGELOG**

`CHANGELOG.md` 的 `## Unreleased` 节写入：

```markdown
## Unreleased

### Cleanup — 菜单栏偏好设置精简

- **移除**菜单栏背景设置(透明背景开关、背景颜色、不透明度):默认即透明,背景位图填充与流量脉冲高亮渲染路径一并删除,移除不可达的原生标题(nativeTitle)分支与 `StatusBarPulseRenderPolicy`
- **移除**「行距」滑杆:两行布局行高固定为原默认值 -2.0,不再暴露偏好
- **移除**「轮换角色池」:角色轮换始终在全部内置角色中进行,并从均匀随机抽取改为洗牌循环——每个角色每轮恰好出现一次,不再短期内反复出现少数角色、漏掉其余
- **解耦**角色颜色与系统文字颜色:选择角色颜色不再自动关闭「系统文字颜色」,移除相关橙色提示;角色颜色预设色块 9 个精简为 5 个(白/黑/红/绿/蓝)
- 偏好设置「菜单栏」Tab 结构重组:折叠区从 4 个合并为 2 个(「显示与布局」「角色与动画」);角色位置/朝向/大小与动画控件并入「角色」区;「对齐」仅在手动宽度下显示;修复区块标题重复渲染与卡片嵌套
```

- [ ] **Step 2: 更新 README**

1. 第 33 行 `- 字号、行距、文字颜色` 改为 `- 字号、文字颜色`。
2. 第 36 行删除 `- 透明背景和紧凑样式`。
3. 第 359 行 `` `StatusBarRenderer`：CoreGraphics 渲染引擎，负责菜单栏文字、背景和角色绘制。`` 改为 `` `StatusBarRenderer`：CoreGraphics 渲染引擎，负责菜单栏文字和角色绘制。``
4. 第 125 行 `- **角色轮换**：开启后按设定间隔从你选定的角色池中随机切换，保持新鲜感。` 改为 `- **角色轮换**：开启后按设定间隔在全部内置角色中自动切换——采用洗牌循环，每个角色每轮恰好出现一次。`（轮换池已删、随机抽取已改洗牌循环，原描述失效。）
5. `PROJECT_MAP.md` 第 126 行 `` `StatusBarRenderer.swift`: 状态栏布局、文字、背景、角色和特效绘制 `` 改为 `` `StatusBarRenderer.swift`: 状态栏布局、文字、角色和特效绘制 ``。
6. `PROJECT_MAP.md` 第 187 行 `` `MenuBarDisplayPreferencesView.swift`: 速率显示、文字、颜色、背景 `` 改为 `` `MenuBarDisplayPreferencesView.swift`: 速率显示、文字与颜色 ``。
7. `PROJECT_MAP.md` 第 188 行 `` `MenuBarLayoutPreferencesView.swift`: 宽度、对齐、行距、排序等布局 `` 改为 `` `MenuBarLayoutPreferencesView.swift`: 宽度、对齐、排序等布局 ``。
8. （可选）按仓库惯例（见 `926f0df docs: ... AGENTS.md 刷新至当前规模`）刷新 `AGENTS.md` 的文件行数表：`StatusBarStyle.swift`（约 235→200 行）、`StatusBarRenderer.swift`（约 965→900 行）、`Preferences/*.swift`（约 2039 行）都会漂移；`MenuBarAnimationPreferencesView.swift` 改写为 `MenuBarAnimationControls` 后职责描述也可同步。

- [ ] **Step 3: 全量测试 + 打包验证**

Run:
```bash
swift test
./Scripts/build-app.sh
./Scripts/verify-release-app.sh build/NetBar.app
```
Expected: 测试全绿；`build/NetBar.app` 构建成功并通过可执行文件/架构/签名形态验证。

- [ ] **Step 4: 提交**

```bash
git add CHANGELOG.md README.md PROJECT_MAP.md
git commit -m "docs: 同步菜单栏设置精简到 CHANGELOG/README/PROJECT_MAP"
```

- [ ] **Step 5: 人工冒烟(可选,交用户执行)**

提醒用户在 Finder/Terminal 执行 `open build/NetBar.app`，检查：偏好设置「菜单栏」Tab 只有「显示与布局」「角色与动画」两个折叠区且标题只出现一次；角色区含位置/朝向/大小与动画控件；自动宽度下无「对齐」；无背景相关控件；菜单栏默认外观与改造前一致（透明底、系统文字颜色模板模式）。

---

## 任务依赖与顺序

```text
Task 1 (结构修复) → Task 2 (分组重排)     [纯 UI]
Task 3 (行距)                              [模型+渲染器]
Task 4 (轮换池+颜色)                       [依赖 Task 2 后的动画区形状]
Task 5 (背景子系统)                        [依赖 Task 3 后的签名/缓存键形状]
Task 6 (合并折叠区 4→2)                    [依赖 Task 2/4 裁剪后的动画区形状]
Task 7 (文档+打包)                         [依赖全部]
```

严格按 1→7 顺序执行；Task 3 理论上可与 1/2 并行，但为保证每步提交都全绿，仍按序执行。合并(Task 6)放在裁剪之后是刻意的——先裁后并，动的代码量最小，且每个中间提交都是可发布的稳定形态。

## 风险与回滚

- **最大风险在 Task 5**：删除渲染分支可能漏改引用导致编译错误——编译器会兜底，按报错逐一清理即可；独立提交保证可单独 revert。
- **用户已存自定义行距/背景/轮换池的旧偏好**：删除后静默回到默认行为，不做迁移（与 v0.43.0 处理 `recentDays` 的先例一致）。
- **模板模式变化**：`useTemplate` 去掉 `!showsBackground` 条件后，默认配置（系统文字颜色 + 默认白猫）仍走模板模式，外观不变；仅「背景开 + 系统文字颜色」组合（此前被背景强制非模板）不复存在。
