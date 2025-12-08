# FileFly macOS 打包签名公证指南

## 📋 概述

本指南介绍如何使用 `sign_and_notarize_filefly.sh` 脚本在配置好证书的 Mac 上构建、签名和公证 FileFly 应用。

---

## 🔧 前置准备

### 在目标 Mac 上（有证书的电脑）

#### 1. 确认证书已配置
```bash
# 运行证书检查脚本
bash ./check-codesign.sh

# 或手动检查
security find-identity -v -p codesigning
```

应该能看到：
```
Developer ID Application: mingqing wu (A8JJ28CX2A)
```

#### 2. 安装必要工具

```bash
# 安装 Homebrew（如果未安装）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装 create-dmg
brew install create-dmg

# 确认 Flutter 已安装
flutter doctor
```

#### 3. 配置公证凭证（首次需要）

**步骤 A：生成 App-Specific Password**

1. 访问：https://appleid.apple.com/account/manage
2. 使用 `mingqing wu` 的 Apple ID 登录
3. 在"安全"部分找到"App 专用密码"
4. 点击生成密码
5. 标签填写：`FileFly Notarization`
6. 记录生成的密码（格式：`xxxx-xxxx-xxxx-xxxx`）

**步骤 B：存储凭证到钥匙串**

```bash
xcrun notarytool store-credentials "filefly-notary" \
  --apple-id "mingqing.wu@example.com" \
  --team-id "A8JJ28CX2A" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

**重要提示：**
- `mingqing.wu@example.com` 替换为实际的 Apple ID 邮箱
- `xxxx-xxxx-xxxx-xxxx` 替换为刚才生成的 App-Specific Password
- `filefly-notary` 是凭证名称，已经在脚本中配置好

验证凭证：
```bash
xcrun notarytool history --keychain-profile "filefly-notary"
```

---

## 📦 打包流程

### 方法 1：一键打包（推荐）

#### 步骤 1：传输项目到目标 Mac

```bash
# 在当前电脑上打包项目（不包含 build 目录）
cd /Users/lj/file_send/file_trans/file_trans_local
tar --exclude='build' --exclude='ios/Pods' --exclude='macos/Pods' \
    -czf filefly_source.tar.gz .

# 通过 AirDrop、U盘或其他方式传输到目标 Mac
```

#### 步骤 2：在目标 Mac 上解压

```bash
# 解压到目标位置
mkdir -p ~/FileFly_Build
cd ~/FileFly_Build
tar -xzf /path/to/filefly_source.tar.gz

# 确认文件完整
ls -la
```

#### 步骤 3：修改配置（首次需要）

```bash
# 编辑脚本，修改 Apple ID
nano sign_and_notarize_filefly.sh

# 找到这一行并修改：
# APPLE_ID="your@email.com"  
# 改为实际的 Apple ID，例如：
# APPLE_ID="mingqing.wu@example.com"

# 保存：Ctrl+O, 回车, Ctrl+X
```

#### 步骤 4：运行脚本

```bash
# 进入项目目录
cd ~/FileFly_Build

# 运行脚本
./sign_and_notarize_filefly.sh
```

#### 步骤 5：等待完成

脚本会自动执行以下步骤：
1. ✅ 检查前置条件（证书、工具等）
2. 🧹 清理旧的构建文件
3. 📦 构建 Release 版本
4. ✍️  对应用进行代码签名
5. 💿 创建 DMG 安装包
6. ✍️  对 DMG 进行签名
7. 📤 提交公证（需要 5-15 分钟）
8. 📎 装订公证票据
9. ✅ 验证最终产物
10. 📋 生成构建报告

**预计总耗时：15-30 分钟**

---

## 📂 输出文件

构建完成后，在 `release_output` 目录下找到：

```
release_output/
├── FileFly_v1.0.0_20251208_121530.dmg    # 最终的安装包
├── build_report_20251208_121530.txt      # 构建报告
└── notarization_log.json                 # 公证日志（如有）
```

---

## 🧪 测试安装包

```bash
# 打开 DMG
open release_output/FileFly_v*.dmg

# 将应用拖到应用程序文件夹
# 双击运行，测试功能
```

### 验证签名和公证

```bash
# 验证代码签名
codesign -dv release_output/FileFly_v*.dmg

# 验证公证
spctl -a -t open --context context:primary-signature -v release_output/FileFly_v*.dmg

# 预期输出：
# accepted
# source=Notarized Developer ID
```

---

## 🔄 仅重新打包（不清理）

如果只是小改动，不想完全清理：

```bash
# 编辑脚本，注释掉 clean 步骤
nano sign_and_notarize_filefly.sh

# 找到 clean_and_prepare 函数中的：
# flutter clean
# 改为：
# # flutter clean

# 然后运行
./sign_and_notarize_filefly.sh
```

---

## 🚫 不需要公证（仅用于测试）

如果只是自己测试，可以跳过公证：

```bash
# 当脚本检测到未配置公证凭证时，会提示：
# 是否继续（将跳过公证步骤）？[y/N]

# 输入 y 继续

# 或者直接修改脚本，设置：
SKIP_NOTARIZATION=true
```

**注意：** 未公证的应用在其他 Mac 上首次打开会有安全警告。

---

## 🐛 故障排查

### 问题 1：找不到证书

**错误信息：**
```
❌ 未找到证书: Developer ID Application: mingqing wu (A8JJ28CX2A)
```

**解决方法：**
```bash
# 检查证书
security find-identity -v -p codesigning

# 如果列表为空，需要重新安装证书
# 1. 打开"钥匙串访问"应用
# 2. 在左侧选择"登录" → "我的证书"
# 3. 找到 Developer ID Application 证书
# 4. 确认证书有效且未过期
```

### 问题 2：公证失败

**错误信息：**
```
❌ 公证失败
```

**解决方法：**
```bash
# 查看公证日志
cat release_output/notarization_log.json

# 常见原因：
# 1. 证书过期 → 重新申请证书
# 2. 缺少权限配置 → 检查 Release.entitlements
# 3. 未启用 Hardened Runtime → 脚本已包含 --options runtime
# 4. 凭证错误 → 重新配置 notarytool 凭证
```

### 问题 3：构建失败

**错误信息：**
```
❌ 构建失败：未找到 build/macos/Build/Products/Release/FileFly.app
```

**解决方法：**
```bash
# 手动运行构建查看详细错误
flutter build macos --release --verbose

# 常见原因：
# 1. 依赖问题 → flutter pub get
# 2. macOS 配置问题 → 检查 macos/ 目录
# 3. 权限问题 → 检查 Info.plist 和 entitlements
```

### 问题 4：create-dmg 失败

**解决方法：**
```bash
# 重新安装 create-dmg
brew uninstall create-dmg
brew install create-dmg

# 或者手动创建 DMG
hdiutil create -volname "FileFly" \
  -srcfolder build/macos/Build/Products/Release/FileFly.app \
  -ov -format UDZO FileFly.dmg
```

### 问题 5：权限不足

**错误信息：**
```
Permission denied
```

**解决方法：**
```bash
# 确保脚本有执行权限
chmod +x sign_and_notarize_filefly.sh

# 确保有写入权限
ls -la
# 如果需要，修改权限
chmod 755 .
```

---

## 📝 自定义配置

### 修改版本号

编辑脚本中的配置：

```bash
nano sign_and_notarize_filefly.sh

# 修改这些行：
VERSION="1.0.1"         # 版本号
BUILD_NUMBER="2"        # 构建号
```

### 修改输出文件名

```bash
# 修改这一行：
DMG_NAME="${APP_NAME}_v${VERSION}_macOS.dmg"
```

### 添加自定义图标

确保项目中有 `assets/logo.png`，脚本会自动使用它作为 DMG 图标。

---

## 📤 分发应用

### 方法 1：直接分发 DMG

```bash
# 将 DMG 文件上传到：
# - 网站下载页面
# - GitHub Releases
# - 云盘分享链接

# 用户下载后直接双击安装
```

### 方法 2：创建分发包

```bash
# 创建完整的分发包
cd release_output
zip FileFly_v1.0.0_macOS.zip FileFly_v*.dmg build_report_*.txt

# 包含：
# - DMG 安装包
# - 构建报告
```

---

## 📋 检查清单

### 首次使用前：

- [ ] 确认证书已安装并有效
- [ ] 安装了 Flutter 和 create-dmg
- [ ] 生成了 App-Specific Password
- [ ] 配置了公证凭证
- [ ] 修改了脚本中的 Apple ID

### 每次构建前：

- [ ] 代码已提交到 Git
- [ ] 版本号已更新
- [ ] 测试了主要功能
- [ ] 确认网络权限配置正确

### 构建完成后：

- [ ] 验证了签名
- [ ] 验证了公证
- [ ] 测试了安装和运行
- [ ] 保存了构建报告
- [ ] 备份了 DMG 文件

---

## 🔗 相关链接

- **Apple Developer Portal:** https://developer.apple.com/account
- **App-Specific Passwords:** https://appleid.apple.com/account/manage
- **Notarization Guide:** https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- **Code Signing Guide:** https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/

---

## 💡 提示

1. **首次公证较慢**：第一次提交可能需要更长时间，后续会更快
2. **保存日志**：每次构建的报告都会保存，便于追踪问题
3. **测试环境**：建议先在测试 Mac 上验证后再正式分发
4. **证书有效期**：Developer ID 证书有效期 5 年，注意续期
5. **版本管理**：每次发布建议打上 Git tag

---

## 📞 支持

如遇到问题，请检查：
1. 构建报告：`release_output/build_report_*.txt`
2. 公证日志：`release_output/notarization_log.json`
3. Flutter 日志：重新运行时添加 `--verbose`

---

**祝打包顺利！🎉**

