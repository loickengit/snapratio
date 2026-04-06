#!/usr/bin/env swift
// 3:4 比例截图工具
// 用法: swift screenshot.swift
// 依赖: macOS 10.15+，需要屏幕录制权限

import Cocoa
import Foundation

let RATIO_W: CGFloat = 3
let RATIO_H: CGFloat = 4
func desktopPath() -> String {
    let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!.path
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd_HHmmss"
    return "\(desktop)/screenshot_\(formatter.string(from: Date())).png"
}

// MARK: - 选区视图

class SelectionView: NSView {
    var startPoint: NSPoint?
    var currentPoint: NSPoint?
    var onSelect: ((NSRect) -> Void)?

    // isFlipped=true：(0,0) 在左上角，y 向下，与 Quartz 坐标系方向一致
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
        if event.keyCode == 53 { NSApp.terminate(nil) } // ESC
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

        // 选区内清除遮罩，露出底层内容
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

// MARK: - 截图 + 写入剪贴板

func captureAndCopy(globalX: Int, globalY: Int, w: Int, h: Int) {
    let region = "\(globalX),\(globalY),\(w),\(h)"
    let outPath = desktopPath()
    print("截图区域: \(region)")

    let capture = Process()
    capture.launchPath = "/usr/sbin/screencapture"
    capture.arguments = ["-R", region, outPath]
    capture.launch()
    capture.waitUntilExit()

    guard capture.terminationStatus == 0 else {
        print("截图失败"); NSApp.terminate(nil); return
    }

    let script = "set the clipboard to (read (POSIX file \"\(outPath)\") as «class PNGf»)"
    let osa = Process()
    osa.launchPath = "/usr/bin/osascript"
    osa.arguments = ["-e", script]
    osa.launch()
    osa.waitUntilExit()

    print("截图完成：\(w)×\(h)，已复制到剪贴板，文件：\(outPath)")
    NSApp.terminate(nil)
}

// MARK: - 主程序

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindows: [NSWindow] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // 在每个屏幕上创建覆盖窗口
        for screen in NSScreen.screens {
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGMainDisplayID()
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
                // 关闭所有覆盖窗口
                self?.overlayWindows.forEach { $0.orderOut(nil) }
                let globalX = Int(quartzBounds.origin.x + rect.minX)
                let globalY = Int(quartzBounds.origin.y + rect.minY)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    captureAndCopy(globalX: globalX, globalY: globalY,
                                   w: Int(rect.width), h: Int(rect.height))
                }
            }

            win.contentView = view
            win.makeKeyAndOrderFront(nil)
            win.makeFirstResponder(view)
            overlayWindows.append(win)
        }

        NSApp.activate(ignoringOtherApps: true)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
