# SnapRatio

固定宽高比的 macOS 截图工具，告别手动裁剪。

**[English](#english) | 中文**

![macOS](https://img.shields.io/badge/macOS-12%2B-black) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-blue)

---

## 为什么需要它

截图粘贴到笔记、小红书、PPT 时，图片比例不统一导致排版混乱。SnapRatio 在你拖拽选区时自动锁定宽高比，每张截图都是一样的形状，省去裁剪步骤。

## 功能

- **固定比例选区** — 拖拽时自动约束，支持 3:4、4:3、1:1、16:9、9:16 及自由选择
- **比例记忆** — 选一次，永久保存，重启也记得
- **全局快捷键** — 任意界面按 `⌘ Shift S` 触发
- **多显示器支持** — MacBook 内屏和外接显示器均可截图
- **自动保存 + 复制** — 截图存到桌面（带时间戳），同时复制到剪贴板
- **只在菜单栏** — 不占 Dock 位置

## 安装

从 [Releases](https://github.com/loickengit/snapratio/releases/latest) 下载最新的 `.zip`，解压后将 `SnapRatio.app` 拖入 `/Applications`。

首次打开时，macOS 会提示需要**屏幕录制**权限，允许即可。

## 使用

| 操作 | 方式 |
|------|------|
| 截图 | `⌘ Shift S` 或点击菜单栏图标 |
| 切换比例 | 菜单栏图标 → 设置比例… |
| 取消选区 | `ESC` |
| 退出 | 菜单栏图标 → 退出 |

## 从源码构建

需要 Xcode Command Line Tools，以及在钥匙串中创建名为 `SnapRatioDev` 的代码签名证书。

```bash
git clone https://github.com/loickengit/snapratio.git
cd snapratio
make run
```

---

## English

A lightweight macOS screenshot tool that locks your selection to a fixed aspect ratio — no cropping needed.

### Why

Most screenshot tools let you select freely. SnapRatio constrains the selection to your chosen ratio so every screenshot comes out the same shape — ideal for notes, social media, presentations, or design work.

### Features

- **Fixed aspect ratio** — 3:4, 4:3, 1:1, 16:9, 9:16, or free selection
- **Remembered setting** — persists across relaunches
- **Global hotkey** — trigger from anywhere with `⌘ Shift S`
- **Multi-display support** — works across MacBook screen and external monitors
- **Saves to Desktop** — timestamped PNG, also copied to clipboard
- **Menubar only** — no Dock icon

### Install

Download the latest `.zip` from [Releases](https://github.com/loickengit/snapratio/releases/latest), unzip, and move `SnapRatio.app` to `/Applications`.

On first launch, grant **Screen Recording** permission when prompted.

### Usage

| Action | How |
|--------|-----|
| Take screenshot | `⌘ Shift S` or click menubar icon |
| Change ratio | Menubar icon → Settings… |
| Cancel | `ESC` |
| Quit | Menubar icon → Quit |

### Build from Source

Requires Xcode Command Line Tools and a code-signing certificate named `SnapRatioDev` in Keychain.

```bash
git clone https://github.com/loickengit/snapratio.git
cd snapratio
make run
```

## License

MIT
