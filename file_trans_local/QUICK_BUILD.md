# FileFly macOS 打包快速参考

## 🚀 快速开始（5 步完成）

### 1️⃣ 首次配置（仅需一次）

```bash
# 在有证书的 Mac 上配置公证凭证
xcrun notarytool store-credentials "filefly-notary" \
  --apple-id "你的Apple ID邮箱" \
  --team-id "A8JJ28CX2A" \
  --password "App专用密码(xxxx-xxxx-xxxx-xxxx)"
```

**获取 App 专用密码：**
1. 访问：https://appleid.apple.com/account/manage
2. 安全 → App 专用密码 → 生成密码

---

### 2️⃣ 传输项目

```bash
# 在开发机上打包
cd /Users/lj/file_send/file_trans/file_trans_local
tar --exclude='build' --exclude='*/Pods' -czf filefly.tar.gz .

# 传输到有证书的 Mac，然后解压
mkdir ~/FileFly_Build && cd ~/FileFly_Build
tar -xzf /path/to/filefly.tar.gz
```

---

### 3️⃣ 修改 Apple ID

```bash
# 编辑脚本
nano sign_and_notarize_filefly.sh

# 找到并修改这一行：
APPLE_ID="你的Apple ID邮箱"

# 保存退出：Ctrl+O, Enter, Ctrl+X
```

---

### 4️⃣ 运行脚本

```bash
# 一键打包
./sign_and_notarize_filefly.sh
```

**预计耗时：** 15-30 分钟（包含公证等待时间）

---

### 5️⃣ 获取结果

```bash
# 成品位置
release_output/FileFly_v1.0.0_YYYYMMDD_HHMMSS.dmg

# 测试安装
open release_output/FileFly_v*.dmg
```

---

## 📋 常用命令

### 检查证书
```bash
security find-identity -v -p codesigning
```

### 手动构建（不运行脚本）
```bash
flutter build macos --release
```

### 验证签名
```bash
codesign -dv build/macos/Build/Products/Release/FileFly.app
```

### 查看公证历史
```bash
xcrun notarytool history --keychain-profile "filefly-notary"
```

---

## 🔧 故障快速修复

### 问题：找不到证书
```bash
# 打开钥匙串访问，确认证书在"登录"钥匙串中
open -a "Keychain Access"
```

### 问题：公证失败
```bash
# 查看日志
cat release_output/notarization_log.json
```

### 问题：构建失败
```bash
flutter clean
flutter pub get
flutter build macos --release --verbose
```

---

## 📂 项目文件说明

| 文件 | 用途 |
|------|------|
| `sign_and_notarize_filefly.sh` | 主打包脚本 |
| `MACOS_BUILD_GUIDE.md` | 详细使用指南 |
| `QUICK_BUILD.md` | 本文件（快速参考） |
| `macos/Runner/Release.entitlements` | 权限配置 |
| `macos/Runner/Info.plist` | 应用信息配置 |

---

## 🎯 打包检查清单

**构建前：**
- [ ] 证书有效（运行 `check-codesign.sh`）
- [ ] 公证凭证已配置
- [ ] 脚本中的 Apple ID 已修改
- [ ] create-dmg 已安装（`brew install create-dmg`）

**构建后：**
- [ ] DMG 文件生成成功
- [ ] 签名验证通过
- [ ] 公证验证通过
- [ ] 测试安装运行正常

---

## 💡 小贴士

1. **第一次运行慢**：公证需要 5-15 分钟，耐心等待
2. **网络要求**：公证需要稳定的网络连接
3. **版本号**：修改脚本中的 `VERSION` 和 `BUILD_NUMBER`
4. **仅测试**：按 `y` 跳过公证，节省时间

---

## 🆘 获取帮助

**完整文档：** 查看 `MACOS_BUILD_GUIDE.md`

**检查日志：**
- 构建报告：`release_output/build_report_*.txt`
- 公证日志：`release_output/notarization_log.json`

---

**证书信息：**
- 名称：Developer ID Application: mingqing wu (A8JJ28CX2A)
- Team ID：A8JJ28CX2A

