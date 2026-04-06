// ScreenshotTool - 菜单栏截图工具
// 构建: bash build.sh
// 快捷键: Cmd+Shift+S

import Cocoa
import Carbon.HIToolbox
import Foundation

// MARK: - 比例预设

struct RatioPreset {
    let name: String
    let w: CGFloat   // 0 = 自由选择
    let h: CGFloat
}

let ratioPresets: [RatioPreset] = [
    RatioPreset(name: "3:4",    w: 3,  h: 4),
    RatioPreset(name: "4:3",    w: 4,  h: 3),
    RatioPreset(name: "1:1",    w: 1,  h: 1),
    RatioPreset(name: "16:9",   w: 16, h: 9),
    RatioPreset(name: "9:16",   w: 9,  h: 16),
    RatioPreset(name: "自由选择", w: 0,  h: 0),
]

let kRatioKey = "selectedRatioIndex"

func currentRatio() -> RatioPreset {
    let idx = UserDefaults.standard.integer(forKey: kRatioKey)
    guard idx >= 0 && idx < ratioPresets.count else { return ratioPresets[0] }
    return ratioPresets[idx]
}

// MARK: - 全局快捷键回调（必须是全局函数，不能是闭包）

func hotKeyHandler(
    _: EventHandlerCallRef?,
    _ theEvent: EventRef?,
    _: UnsafeMutableRawPointer?
) -> OSStatus {
    DispatchQueue.main.async {
        (NSApp.delegate as? AppDelegate)?.showOverlay()
    }
    return noErr
}

// MARK: - 选区视图

class SelectionView: NSView {
    var startPoint: NSPoint?
    var currentPoint: NSPoint?
    var onSelect: ((NSRect) -> Void)?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
        if let rect = selectionRect(), rect.width > 10, rect.height > 10 {
            onSelect?(rect)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            (NSApp.delegate as? AppDelegate)?.dismissOverlay()
        }
    }

    func selectionRect() -> NSRect? {
        guard let start = startPoint, let current = currentPoint else { return nil }
        let dx = current.x - start.x
        let dy = current.y - start.y
        let aw = abs(dx), ah = abs(dy)
        let ratio = currentRatio()
        var w: CGFloat, h: CGFloat
        if ratio.w == 0 {
            // 自由选择
            w = aw; h = ah
        } else if aw * ratio.h > ah * ratio.w {
            w = aw; h = w * ratio.h / ratio.w
        } else {
            h = ah; w = h * ratio.w / ratio.h
        }
        let x = dx >= 0 ? start.x : start.x - w
        let y = dy >= 0 ? start.y : start.y - h
        return NSRect(x: x, y: y, width: w, height: h)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0, alpha: 0.45).setFill()
        NSBezierPath.fill(bounds)

        let ratio = currentRatio()
        let hint = "拖拽选择区域（\(ratio.name)）  |  ESC 取消"

        guard let rect = selectionRect() else {
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 16, weight: .medium)
            ]
            let size = hint.size(withAttributes: attrs)
            hint.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: 20),
                      withAttributes: attrs)
            return
        }

        NSGraphicsContext.current?.cgContext.clear(rect)

        NSColor.systemRed.setStroke()
        let border = NSBezierPath(rect: rect)
        border.lineWidth = 2
        border.stroke()

        let label = " \(Int(rect.width)) × \(Int(rect.height)) "
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.boldSystemFont(ofSize: 13),
            .backgroundColor: NSColor(white: 0, alpha: 0.6)
        ]
        let labelSize = label.size(withAttributes: attrs)
        label.draw(at: NSPoint(x: rect.midX - labelSize.width / 2,
                               y: rect.midY - labelSize.height / 2),
                   withAttributes: attrs)
    }
}

// MARK: - 设置窗口

class SettingsWindowController: NSWindowController {
    var popup: NSPopUpButton!

    convenience init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "截图设置"
        win.center()
        self.init(window: win)

        let label = NSTextField(labelWithString: "截图比例")
        label.frame = NSRect(x: 30, y: 100, width: 80, height: 20)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)

        popup = NSPopUpButton(frame: NSRect(x: 120, y: 96, width: 210, height: 28))
        for preset in ratioPresets {
            popup.addItem(withTitle: preset.name)
        }
        popup.selectItem(at: UserDefaults.standard.integer(forKey: kRatioKey))
        popup.target = self
        popup.action = #selector(ratioChanged(_:))

        let separator = NSBox(frame: NSRect(x: 20, y: 72, width: 320, height: 1))
        separator.boxType = .separator

        let tip = NSTextField(labelWithString: "选择后立即生效并自动保存，重启 app 也会记住。")
        tip.frame = NSRect(x: 30, y: 38, width: 300, height: 28)
        tip.font = NSFont.systemFont(ofSize: 12)
        tip.textColor = .secondaryLabelColor
        tip.maximumNumberOfLines = 2

        win.contentView?.addSubview(label)
        win.contentView?.addSubview(popup)
        win.contentView?.addSubview(separator)
        win.contentView?.addSubview(tip)

        // Cmd+W 关闭窗口
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak win] event in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
                win?.close()
                return nil
            }
            return event
        }
    }

    @objc func ratioChanged(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(sender.indexOfSelectedItem, forKey: kRatioKey)
    }
}

// MARK: - 截图 + 存文件 + 写剪贴板

func desktopPath() -> String {
    let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!.path
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd_HHmmss"
    return "\(desktop)/screenshot_\(formatter.string(from: Date())).png"
}

func captureAndCopy(globalX: Int, globalY: Int, w: Int, h: Int) {
    let region = "\(globalX),\(globalY),\(w),\(h)"
    let outPath = desktopPath()

    let capture = Process()
    capture.launchPath = "/usr/sbin/screencapture"
    capture.arguments = ["-R", region, outPath]
    capture.launch()
    capture.waitUntilExit()

    guard capture.terminationStatus == 0 else { return }

    let script = "set the clipboard to (read (POSIX file \"\(outPath)\") as «class PNGf»)"
    let osa = Process()
    osa.launchPath = "/usr/bin/osascript"
    osa.arguments = ["-e", script]
    osa.launch()
    osa.waitUntilExit()

    print("截图完成：\(w)×\(h) → \(outPath)")
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var hotKeyRef: EventHotKeyRef?
    var overlayWindows: [NSWindow] = []
    var escMonitor: Any?
    var settingsController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 默认比例：3:4（仅首次启动时）
        UserDefaults.standard.register(defaults: [kRatioKey: 0])

        // 菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder",
                                   accessibilityDescription: "Screenshot")
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "截图 (⌘⇧S)", action: #selector(showOverlay), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "设置比例…", action: #selector(showSettings), keyEquivalent: ",")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem?.menu = menu

        // 注册全局快捷键 Cmd+Shift+S
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyHandler,
            1,
            &eventSpec,
            nil,
            nil
        )

        var hkID = EventHotKeyID(signature: 0x53484F54 /* SHOT */, id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_S),
            UInt32(cmdKey | shiftKey),
            hkID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    @objc func showSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController()
        }
        settingsController?.window?.center()
        settingsController?.window?.level = .floating
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismissOverlay() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
        if let m = escMonitor { NSEvent.removeMonitor(m); escMonitor = nil }
    }

    @objc func showOverlay() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()

        for screen in NSScreen.screens {
            let displayID = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? CGDirectDisplayID ?? CGMainDisplayID()
            let quartzBounds = CGDisplayBounds(displayID)

            let win = NSWindow(
                contentRect: NSRect(origin: .zero, size: screen.frame.size),
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            win.backgroundColor = .clear
            win.isOpaque = false
            win.hasShadow = false
            win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
            win.ignoresMouseEvents = false
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            win.setFrame(screen.frame, display: false)

            let view = SelectionView(frame: win.contentView!.bounds)
            view.autoresizingMask = [.width, .height]
            view.onSelect = { [weak self] rect in
                self?.overlayWindows.forEach { $0.orderOut(nil) }
                self?.overlayWindows.removeAll()
                let gx = Int(quartzBounds.origin.x + rect.minX)
                let gy = Int(quartzBounds.origin.y + rect.minY)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    captureAndCopy(globalX: gx, globalY: gy,
                                   w: Int(rect.width), h: Int(rect.height))
                }
            }

            win.contentView = view
            win.makeKeyAndOrderFront(nil)
            win.makeFirstResponder(view)
            overlayWindows.append(win)
        }

        NSApp.activate(ignoringOtherApps: true)

        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.dismissOverlay(); return nil }
            return event
        }
    }
}

// MARK: - 入口

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
