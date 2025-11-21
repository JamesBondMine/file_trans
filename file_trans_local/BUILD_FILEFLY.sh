#!/bin/bash

echo "🚀 开始打包 FileFly..."
echo ""

# 清理旧构建
echo "🧹 清理旧构建..."
flutter clean
flutter pub get
echo ""

# 打包 Android
echo "📱 打包 Android APK..."
flutter build apk --release
echo ""

# 打包 macOS
echo "💻 打包 macOS APP..."
flutter build macos --release
echo ""

# 创建 DMG
echo "📀 创建 macOS DMG..."
mkdir -p dmg_temp
cp -r build/macos/Build/Products/Release/FileFly.app dmg_temp/
ln -s /Applications dmg_temp/Applications
hdiutil create -volname "FileFly" -srcfolder dmg_temp -ov -format UDZO FileFly.dmg
rm -rf dmg_temp
echo ""

# 显示结果
echo "✅ 打包完成！"
echo ""
echo "📦 打包文件："
echo "  Android APK: build/app/outputs/flutter-apk/app-release.apk"
ls -lh build/app/outputs/flutter-apk/app-release.apk
echo ""
echo "  macOS APP: build/macos/Build/Products/Release/FileFly.app"
echo ""
echo "  macOS DMG: FileFly.dmg"
ls -lh FileFly.dmg
echo ""

# 打开文件位置
open build/app/outputs/flutter-apk/
open .

echo "🎉 全部完成！"
