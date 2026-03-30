# MiniPasteboard

一个最小可用的 macOS 原生状态栏剪贴板工具。

## 已实现功能

- 常驻在 macOS 菜单栏
- 监听剪贴板文本变化
- 保存历史记录到本地 `UserDefaults`
- 点击菜单栏图标展示下拉菜单
- 点击历史项后重新复制到剪贴板
- 连续复制相同文本时自动去重

## 项目结构

- `Package.swift`：Swift Package 配置
- `Sources/main.swift`：应用入口
- `Sources/ClipboardMonitor.swift`：剪贴板监听
- `Sources/ClipboardHistoryStore.swift`：历史记录持久化
- `Sources/StatusBarController.swift`：状态栏和下拉菜单

## 运行方式

当前仓库是一个原生 `AppKit` 的 Swift Package。

1. 使用完整 Xcode 打开这个目录
2. 让 Xcode 生成并运行可执行目标 `MiniPasteboard`
3. 运行后会在 macOS 菜单栏看到一个剪贴板图标

如果本机只安装了 Command Line Tools，`swift build` 可能会因为缺少完整 macOS SDK 平台信息而失败。

## 构建发布包

如果你已经安装了完整 Xcode，但系统默认还没切过去，可以直接这样构建：

```bash
cd /Users/liuqihao/Downloads/mini-pasteboard
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/build_app.sh
```

生成结果：

- `dist/MiniPasteboard.app`
- `dist/MiniPasteboard-v0.0-macos.zip`
