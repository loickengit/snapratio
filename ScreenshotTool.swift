// ScreenshotTool - 菜单栏截图工具
// 构建: bash build.sh
// 快捷键: Cmd+Shift+S

import Cocoa
import Carbon.HIToolbox
import Foundation

let RATIO_W: CGFloat = 3
let RATIO_H: CGFloat = 4

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
        var w: CGFloat, h: CGFloat
        if aw * RATIO_H > ah * RATIO_W {
            w = aw; h = w * RATIO_H / RATIO_W
        } else {
            h = ah; w = h * RATIO_W / RATIO_H
        }
        let x = dx >= 0 ? start.x : start.x - w
        let y = dy >= 0 ? start.y : start.y - h
        return NSRect(x: x, y: y, width: w, height: h)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0, alpha: 0.45).setFill()
        NSBezierPath.fill(bounds)

        guard let rect = selectionRect() else {
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 16, weight: .medium)
            ]
            let text = "拖拽选择区域（3:4 比例）  |  ESC 取消"
            let size = text.size(withAttributes: attrs)
            text.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: 20),
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder",
                                   accessibilityDescription: "Screenshot")
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "截图 (⌘⇧S)", action: #selector(showOverlay), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem?.menu = menu

        // 注册全局快捷键 Cmd+Shift+S（Carbon，无需 Accessibility 权限）
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

    func dismissOverlay() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
        if let m = escMonitor { NSEvent.removeMonitor(m); escMonitor = nil }
    }

    @objc func showOverlay() {
        // 清理上次残留窗口
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

        // 监听 ESC 键（screenSaverWindowLevel 不走普通 keyDown，需要用事件监听器）
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.dismissOverlay(); return nil }
            return event
        }
    }
}

// MARK: - 入口

let app = NSApplication.shared
app.setActivationPolicy(.accessory)     // 不在 Dock 显示
let delegate = AppDelegate()
app.delegate = delegate
app.run()
