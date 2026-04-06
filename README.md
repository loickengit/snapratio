# SnapRatio

A lightweight macOS screenshot tool that locks your selection to a fixed aspect ratio — no cropping needed.

![macOS](https://img.shields.io/badge/macOS-12%2B-black) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-blue)

---

## Why

Most screenshot tools let you select any region freely. That's fine until you need consistent proportions — for note layouts, social media posts, presentations, or design work. SnapRatio locks the selection to your chosen ratio so every screenshot comes out the same shape.

## Features

- **Fixed aspect ratio selection** — drag to select, ratio is enforced automatically
- **Preset ratios** — 3:4, 4:3, 1:1, 16:9, 9:16, or free selection
- **Remembered setting** — your ratio choice persists across relaunches
- **Global hotkey** — trigger from anywhere with `⌘ Shift S`
- **Multi-display support** — works across MacBook screen and external monitors
- **Saves to Desktop** — timestamped PNG, e.g. `screenshot_20260406_143022.png`
- **Copies to clipboard** — ready to paste immediately
- **Menubar only** — no Dock icon, stays out of the way

## Install

Download the latest `.zip` from [Releases](../../releases), unzip, and move `SnapRatio.app` to `/Applications`.

On first launch, macOS will ask for **Screen Recording** permission — this is required to capture screen content.

## Build from Source

Requires Xcode Command Line Tools and a code-signing certificate named `SnapRatioDev` in Keychain.

```bash
git clone https://github.com/your-username/snapratio.git
cd snapratio
make run
```

To create the signing certificate:  
Keychain Access → Certificate Assistant → Create a Certificate → Name: `SnapRatioDev`, Type: Code Signing

## Usage

| Action | How |
|--------|-----|
| Take screenshot | `⌘ Shift S` or click menubar icon |
| Change ratio | Menubar icon → Settings… |
| Cancel selection | `ESC` |
| Quit | Menubar icon → Quit |

## License

MIT
