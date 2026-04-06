#!/bin/bash
set -e

APP_NAME="ScreenshotTool"
BUNDLE="${APP_NAME}.app"

echo "🔨 编译中..."
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"

swiftc ScreenshotTool.swift \
    -o "$BUNDLE/Contents/MacOS/$APP_NAME" \
    -framework Cocoa \
    -framework Carbon

cat > "$BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ScreenshotTool</string>
    <key>CFBundleIdentifier</key>
    <string>com.user.screenshottool</string>
    <key>CFBundleName</key>
    <string>ScreenshotTool</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>需要屏幕录制权限来截取屏幕内容</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# 用自签名证书签名，保证编译后权限不丢失
codesign --force --deep --sign "ScreenshotToolDev" "$BUNDLE"

echo "✅ 构建完成：$BUNDLE"
echo ""
echo "使用方式："
echo "  1. open $BUNDLE          # 直接运行"
echo "  2. cp -r $BUNDLE /Applications/   # 安装到应用程序"
echo ""
echo "快捷键：Cmd+Shift+S"
