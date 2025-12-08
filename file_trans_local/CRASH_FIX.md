# 🐛 macOS 闪退问题修复

## 问题描述

**现象：** macOS 端手动输入 IP+端口连接时，应用闪退

**原因：** 代码尝试在 macOS 上调用相册保存功能，但 macOS 不支持移动端的相册 API

---

## ✅ 修复方案

### 修改 1: 文件传输服务
**文件：** `lib/services/file_transfer.dart`

**修改：** 只在 Android/iOS 上调用相册保存

```dart
// 6. 检查是否是图片或视频，如果是则保存到相册（仅 Android/iOS）
if (Platform.isAndroid || Platform.isIOS) {
  await _saveToGalleryIfNeeded(savePath, fileName);
}
```

### 修改 2: 接收端提示
**文件：** `lib/pages/receiver_page.dart`

**修改：** macOS 只显示文件路径，不显示"保存到相册"

```dart
if ((isImage || isVideo) && (Platform.isAndroid || Platform.isIOS)) {
  // Android/iOS: 图片/视频会保存到相册
  _showSuccess('✨ 文件已保存\n📁 位置: $filePath\n📱 已自动保存到相册');
} else {
  // macOS 或其他文件类型
  _showSuccess('✨ 文件已保存至:\n$filePath');
}
```

---

## 📱 各平台行为

### Android
- ✅ 图片/视频：保存到 Downloads + 相册（FileFly 相册）
- ✅ 其他文件：保存到 Downloads
- ✅ APK：保存 + 提示安装

### iOS
- ✅ 图片/视频：保存到应用目录 + 相册（FileFly 相册）
- ✅ 其他文件：保存到应用目录

### macOS
- ✅ 所有文件：保存到 Downloads 文件夹
- ✅ 不调用相册 API（避免崩溃）

---

## 🚀 重新打包

```bash
# 快速打包
flutter build macos --release
flutter build apk --release

# 或使用脚本
./BUILD_FILEFLY.sh
```

---

## 测试步骤

### macOS 端测试：
1. 打开应用
2. 切换到"接收文件"
3. 点击右上角 ✏️ 手动输入
4. 输入 IP 和端口
5. 点击"连接"
6. ✅ 应该不再闪退

### 验证文件保存：
- macOS: 文件在 `~/Downloads/` 文件夹
- Android: 文件在 `/storage/emulated/0/Download/`
- iOS: 文件在应用文档目录

---

生成时间: $(date)
