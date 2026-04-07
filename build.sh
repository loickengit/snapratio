#!/bin/bash
set -e

APP_NAME="SnapRatio"
BUNDLE="${APP_NAME}.app"
DEVELOPER_ID="Developer ID Application: Seve AI Inc (4N23U9XS9S)"
NOTARIZE_PROFILE="seve-notarize-profile"

echo "🔨 编译中..."
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"

swiftc SnapRatio.swift \
    -o "$BUNDLE/Contents/MacOS/$APP_NAME" \
    -framework Cocoa \
    -framework Carbon

mkdir -p "$BUNDLE/Contents/Resources"
cp icons/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"

cat > "$BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SnapRatio</string>
    <key>CFBundleIdentifier</key>
    <string>com.snapratio.app</string>
    <key>CFBundleName</key>
    <string>SnapRatio</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>SnapRatio needs screen recording permission to capture screen content.</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# 开发时用自签名证书（快），发布时用 --release 参数走完整流程
if [ "$1" = "--release" ]; then
    echo "🔐 正式签名中..."
    codesign --force --deep --sign "$DEVELOPER_ID" \
        --options runtime \
        --entitlements entitlements.plist \
        "$BUNDLE"

    echo "📦 打包 zip..."
    ZIP="${APP_NAME}-v${VERSION:-1.0}.zip"
    ditto -c -k --keepParent "$BUNDLE" "$ZIP"

    echo "🚀 公证中（需要几分钟）..."
    xcrun notarytool submit "$ZIP" \
        --keychain-profile "$NOTARIZE_PROFILE" \
        --wait

    echo "✅ 公证完成，staple 中..."
    xcrun stapler staple "$BUNDLE"

    echo "📦 重新打包（含 staple）..."
    rm "$ZIP"
    ditto -c -k --keepParent "$BUNDLE" "$ZIP"

    echo "✅ 发布构建完成：$ZIP"
else
    # 日常开发：自签名，快
    codesign --force --deep --sign "SnapRatioDev" "$BUNDLE"
    echo "✅ 构建完成：$BUNDLE（开发版）"
fi

echo ""
echo "使用方式："
echo "  make run               # 开发构建"
echo "  bash build.sh --release  # 正式发布（签名+公证）"
echo ""
echo "快捷键：Cmd+Shift+S"
