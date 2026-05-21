# NetBar

NetBar 是一个本地 macOS 菜单栏网络流量监控 App。

它会读取 macOS 的网络接口计数器，按 1 秒间隔计算实时速率。它不会抓包，不读取网络内容，也不需要管理员权限。

## 功能

- 菜单栏实时显示总下载 / 上传速度
- 双击 App 会打开详情窗口
- 点击菜单栏实时速率后查看总览、最近 90 秒趋势和接口明细
- 菜单栏支持透明两行样式，并可在设置页自定义字号、自动/手动宽度、行距、颜色、顺序、对齐和背景
- 详情窗口显示应用级流量，按实时下载 / 上传速度排序
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

## 打包 Release（本地验证）

```bash
./Scripts/package-release.sh
```

产物会生成在：

```text
dist/NetBar.app.zip
dist/NetBar.app.zip.sha256
```

## 发布流程

正式发布由 GitHub Actions 自动完成，配置在 `.github/workflows/release.yml`。推送 `v*` tag 后，Actions 会根据 tag 写入 App 版本号、打包 `NetBar.app.zip`，并创建 GitHub Release。

NetBar 的自动更新读取 GitHub Releases/latest 和 Release 资产，不使用 `latest.json`。Release 里必须包含固定资产名 `NetBar.app.zip`，这个名字来自 `Resources/Info.plist` 的 `NBUpdateAssetName`。

1. 确认要发布的代码已经提交，并同步到最新 `main`。

```bash
git status --short --branch
git pull --rebase origin main
swift test
./Scripts/package-release.sh
```

2. 选择新版本号并推送 tag。tag 必须以 `v` 开头；Actions 会把 `v0.32.4` 转成 App 版本号 `0.32.4`，写入 `CFBundleShortVersionString`，并用 Actions run number 写入 `CFBundleVersion`。

```bash
VERSION=0.32.4
TAG="v$VERSION"
git tag -a "$TAG" -m "$TAG"
git push origin main "$TAG"
```

3. 等待 GitHub Actions 完成 `Build & Release` workflow。

```bash
git ls-remote origin main "refs/tags/$TAG"
```

打开仓库的 Actions 页面查看构建状态。workflow 成功后应完成这些动作：

- 将 tag 版本写入 `Resources/Info.plist`
- 构建并验证 `dist/NetBar.app.zip`
- 上传 `NetBar.app.zip` 和 `NetBar.app.zip.sha256`
- 创建 GitHub Release：`https://github.com/sunnyhot/NetBar/releases/tag/$TAG`

4. 验证 Release 和更新入口。

```bash
curl -I -L "https://github.com/sunnyhot/NetBar/releases/download/$TAG/NetBar.app.zip"
curl -Ls -o /dev/null -w '%{url_effective}\n' "https://github.com/sunnyhot/NetBar/releases/latest"
```

确认 zip 地址返回 `200` 并带有合理的 `content-length`，`releases/latest` 最终跳转到新 tag。如果当前 App 已经是同版本，检查更新会正常显示没有更新。

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
