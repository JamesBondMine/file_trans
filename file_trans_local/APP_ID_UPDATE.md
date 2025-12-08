# App ID 更新记录

## 📋 更新信息

**新的 App ID/Bundle Identifier:** `com.zhuqingting.im`

**更新日期:** 2025-12-08

---

## ✅ 已更新的文件

### 1. macOS 配置

**文件:** `macos/Runner/Configs/AppInfo.xcconfig`
```
PRODUCT_NAME = FileFly
PRODUCT_BUNDLE_IDENTIFIER = com.zhuqingting.im
PRODUCT_COPYRIGHT = Copyright © 2025 zhuqingting. All rights reserved.
```

**文件:** `macos/Runner.xcodeproj/project.pbxproj`
- 主应用: `com.zhuqingting.im`
- 测试应用: `com.zhuqingting.im.RunnerTests`

---

### 2. iOS 配置

**文件:** `ios/Runner.xcodeproj/project.pbxproj`
- 主应用: `com.zhuqingting.im`
- 测试应用: `com.zhuqingting.im.RunnerTests`

---

### 3. Android 配置

**文件:** `android/app/build.gradle.kts`
```kotlin
android {
    namespace = "com.zhuqingting.im"
    
    defaultConfig {
        applicationId = "com.zhuqingting.im"
    }
}
```

**文件结构更新:**
- 旧路径: `android/app/src/main/kotlin/com/example/file_trans_local/MainActivity.kt`
- 新路径: `android/app/src/main/kotlin/com/zhuqingting/im/MainActivity.kt`

**文件:** `android/app/src/main/kotlin/com/zhuqingting/im/MainActivity.kt`
```kotlin
package com.zhuqingting.im

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
```

---

## 🔍 验证配置

### macOS 验证

```bash
# 查看配置
cat macos/Runner/Configs/AppInfo.xcconfig | grep PRODUCT_BUNDLE_IDENTIFIER
# 输出：PRODUCT_BUNDLE_IDENTIFIER = com.zhuqingting.im

# 构建后验证
flutter build macos --release
codesign -dv build/macos/Build/Products/Release/FileFly.app 2>&1 | grep Identifier
# 应该显示：Identifier=com.zhuqingting.im
```

### Android 验证

```bash
# 查看配置
cat android/app/build.gradle.kts | grep applicationId
# 输出：applicationId = "com.zhuqingting.im"

# 构建后验证
flutter build apk --release
aapt dump badging build/app/outputs/apk/release/app-release.apk | grep package
# 应该显示：package: name='com.zhuqingting.im'
```

### iOS 验证

```bash
# 查看配置
grep -A 1 "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj | head -2
# 应该显示：PRODUCT_BUNDLE_IDENTIFIER = com.zhuqingting.im;
```

---

## ⚠️ 重要说明

### 1. 证书配置

由于更改了 Bundle Identifier，需要确保证书配置正确：

**对于 macOS:**
- 您使用的证书是: `Developer ID Application: mingqing wu (A8JJ28CX2A)`
- Developer ID 证书可以用于任何 Bundle Identifier（无需额外配置）✅

**对于 iOS（如果需要发布）:**
- 需要在 Apple Developer 网站创建新的 App ID: `com.zhuqingting.im`
- 需要创建对应的 Provisioning Profile

**对于 Android:**
- 无需证书，直接使用即可 ✅

---

### 2. 数据迁移

如果用户已经安装了旧版本（使用旧的 Bundle ID），更新时：
- **macOS/iOS:** 系统会将新版本视为新应用，不会自动迁移数据
- **Android:** 系统会将新版本视为新应用，不会自动迁移数据

**建议:**
- 如果是首次正式发布，无需担心
- 如果已有用户，需要考虑数据迁移方案

---

### 3. 公证配置

macOS 公证时不受 Bundle ID 影响，但需要确保：
- Info.plist 中的 CFBundleIdentifier 正确（已通过 PRODUCT_BUNDLE_IDENTIFIER 变量自动设置）✅
- 权限配置文件正确（已优化）✅

---

## 📱 各平台应用显示名称

| 平台 | Bundle ID | 应用名称 |
|------|-----------|----------|
| macOS | com.zhuqingting.im | FileFly |
| iOS | com.zhuqingting.im | FileFly |
| Android | com.zhuqingting.im | FileFly |

应用名称通过以下文件控制：
- **macOS:** `macos/Runner/Info.plist` → `CFBundleName`
- **iOS:** `ios/Runner/Info.plist` → `CFBundleName`
- **Android:** `android/app/src/main/AndroidManifest.xml` → `android:label`

---

## 🔄 如何撤销更改

如果需要恢复为旧的 Bundle ID：

```bash
# macOS
sed -i '' 's/com.zhuqingting.im/com.example.fileTransLocal/g' macos/Runner/Configs/AppInfo.xcconfig

# Android
sed -i '' 's/com.zhuqingting.im/com.example.file_trans_local/g' android/app/build.gradle.kts

# iOS
# 手动编辑 ios/Runner.xcodeproj/project.pbxproj

# 然后重新构建
flutter clean
flutter pub get
```

---

## ✅ 下一步操作

1. **测试构建:**
   ```bash
   flutter clean
   flutter pub get
   
   # 测试各平台构建
   flutter build macos --release
   flutter build apk --release
   flutter build ios --release  # 如果需要
   ```

2. **验证 App ID:**
   - 使用上面的验证命令确认配置正确

3. **打包和签名:**
   - 使用 `sign_and_notarize_filefly.sh` 进行 macOS 打包
   - 脚本会自动使用新的 Bundle ID

4. **分发前测试:**
   - 在测试设备上完整安装和运行
   - 确认所有功能正常

---

## 🎉 总结

✅ **macOS** - Bundle ID 已更新为 `com.zhuqingting.im`  
✅ **iOS** - Bundle ID 已更新为 `com.zhuqingting.im`  
✅ **Android** - Application ID 已更新为 `com.zhuqingting.im`  
✅ **文件结构** - Android 包名路径已更新  
✅ **应用名称** - 统一为 `FileFly`  

所有平台配置已完成，可以开始打包！🚀

