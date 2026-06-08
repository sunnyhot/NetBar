# NetBar

NetBar 是一个本地 macOS 菜单栏网络流量监控 App。

它会读取 macOS 的网络接口计数器，按 1 秒间隔计算实时速率。它不会抓包，不读取网络内容，也不需要管理员权限。

## 功能

- 菜单栏实时显示总下载 / 上传速度
- 双击 App 会打开详情窗口
- 点击菜单栏实时速率后查看总览、最近 90 秒趋势和接口明细
- 菜单栏支持透明两行样式，并可在设置页自定义字号、自动/手动宽度、行距、颜色、顺序、对齐和背景
- 详情窗口显示应用级流量，按实时下载 / 上传速度排序
- 智能提醒：高流量、应用突增、断流/恢复和代理/VPN 归因差异
- 今日与最近 7 天本地估算统计
- 实时 Top 应用和今日累计 Top 应用
- 首次引导开启 macOS 通知权限，所有提醒都可在偏好设置中关闭
- 菜单栏内置预设，支持极简、总流量、应用关注和宠物模式
- 显示每个接口的实时上下行速度、累计收发流量、收发包数
- 自动识别主网络接口、Wi-Fi、VPN、Bridge 等常见接口
- 普通窗口 App 模式运行，同时保留菜单栏实时状态

## 构建

```bash
./Scripts/build-app.sh
```

构建产物会生成在：

```text
build/NetBar.app
```

## 运行

```bash
open build/NetBar.app
```

## 打包 Release

```bash
./Scripts/package-release.sh
```

产物会生成在：

```text
dist/NetBar.app.zip
dist/NetBar.app.zip.sha256
```

开发时也可以直接运行可执行目标：

```bash
swift run NetBar
```

## macOS 提示"已损坏"的解决方法

从 GitHub Release 下载的 App 未经过 Apple 公证（notarization），macOS Gatekeeper 会阻止打开并提示「"NetBar" is damaged and can't be opened」。

**解决方法**：在终端执行以下命令，移除隔离属性：

```bash
xattr -cr /Applications/NetBar.app
```

> 如果放在其他位置，把路径替换为实际的 `NetBar.app` 路径。

或者：右键点击 App → 选择「打开」→ 在弹出的对话框中再次点击「打开」。

## 说明

macOS 的网卡计数器通常是从系统启动或接口启动以来累计的字节数。NetBar 展示的实时上下行速度来自相邻两次采样的差值；累计收发流量是接口计数器当前值，不等同于 App 启动后的流量。

应用级流量来自 macOS 自带的 `nettop`。这类数据按进程统计，某些代理、VPN 或系统网络扩展可能会把真实流量归到代理进程下。

历史统计是基于本地采样的估算值，用于趋势判断，不等同于运营商或系统账单数据。
