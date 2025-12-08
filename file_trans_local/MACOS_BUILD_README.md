# FileFly macOS 打包工具套件

## 📦 已创建的文件

本次为您创建了完整的 macOS 打包、签名和公证工具套件：

### 🔧 核心脚本

1. **`sign_and_notarize_filefly.sh`** ⭐
   - 主打包脚本
   - 自动完成：构建 → 签名 → 创建DMG → 公证 → 导出
   - 包含详细的进度显示和错误处理

2. **`pack_for_build.sh`**
   - 项目打包脚本
   - 用于将项目打包传输到构建机器
   - 自动排除不必要的文件

### 📚 文档

3. **`MACOS_BUILD_GUIDE.md`**
   - 详细使用指南（完整版）
   - 包含故障排查、配置说明等

4. **`QUICK_BUILD.md`**
   - 快速参考卡
   - 5步完成打包的精简指南

5. **`MACOS_BUILD_README.md`**
   - 本文件，总览和流程说明

### ⚙️ 配置文件

6. **`macos/Runner/Release.entitlements`** ✅
   - 已优化的权限配置
   - 包含 Flutter 和网络传输所需的所有权限

---

## 🚀 完整使用流程

### 步骤 1：在当前电脑（开发机）上打包项目

```bash
cd /Users/lj/file_send/file_trans/file_trans_local

# 运行打包脚本
./pack_for_build.sh
```

**输出文件：** `filefly_source_YYYYMMDD_HHMMSS.tar.gz`

---

### 步骤 2：传输到构建 Mac

选择以下任一方式：

**方式 A：AirDrop**
- 右键压缩包 → 共享 → AirDrop
- 选择目标 Mac

**方式 B：U盘**
- 拷贝压缩包到 U盘
- 在构建 Mac 上读取

**方式 C：scp（如果两台 Mac 在同一网络）**
```bash
scp filefly_source_*.tar.gz user@build-mac-ip:~/
```

---

### 步骤 3：在构建 Mac 上解压

```bash
# 创建工作目录
mkdir -p ~/FileFly_Build
cd ~/FileFly_Build

# 解压项目
tar -xzf ~/filefly_source_*.tar.gz

# 确认文件完整
ls -la
```

---

### 步骤 4：首次配置（仅需一次）

#### A. 生成 App 专用密码

1. 打开浏览器访问：https://appleid.apple.com/account/manage
2. 使用 `mingqing wu` 的 Apple ID 登录
3. 找到"安全"部分 → "App 专用密码"
4. 点击"生成密码"
5. 标签填写：`FileFly Notarization`
6. **记录密码**（格式：`xxxx-xxxx-xxxx-xxxx`）

#### B. 存储公证凭证

```bash
xcrun notarytool store-credentials "filefly-notary" \
  --apple-id "mingqing.wu的邮箱" \
  --team-id "A8JJ28CX2A" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

**验证：**
```bash
xcrun notarytool history --keychain-profile "filefly-notary"
```

#### C. 修改脚本配置

```bash
nano sign_and_notarize_filefly.sh

# 找到这一行：
# APPLE_ID="your@email.com"

# 改为实际的 Apple ID，例如：
# APPLE_ID="mingqing.wu@example.com"

# 保存退出：Ctrl+O, Enter, Ctrl+X
```

---

### 步骤 5：运行打包脚本

```bash
# 在项目目录下运行
./sign_and_notarize_filefly.sh
```

**脚本会自动执行：**
1. ✅ 检查证书和工具
2. 🧹 清理旧构建
3. 📦 构建 Release 版本
4. ✍️ 代码签名
5. 💿 创建 DMG
6. ✍️ DMG 签名
7. 📤 提交公证（5-15分钟）
8. 📎 装订票据
9. ✅ 验证
10. 📋 生成报告

**预计总耗时：** 15-30 分钟

---

### 步骤 6：获取结果

```bash
# 成品位置
cd release_output

# 查看文件
ls -lh

# 文件列表：
# - FileFly_v1.0.0_YYYYMMDD_HHMMSS.dmg  （最终安装包）
# - build_report_YYYYMMDD_HHMMSS.txt    （构建报告）
```

---

### 步骤 7：测试和验证

```bash
# 测试打开 DMG
open release_output/FileFly_v*.dmg

# 验证签名
codesign -dv release_output/FileFly_v*.dmg

# 验证公证
spctl -a -t open --context context:primary-signature -v release_output/FileFly_v*.dmg
```

**预期输出：**
```
accepted
source=Notarized Developer ID
```

---

### 步骤 8：传输回开发机（可选）

```bash
# 在构建 Mac 上压缩
cd ~/FileFly_Build/release_output
zip FileFly_Release.zip FileFly_v*.dmg build_report_*.txt

# 传输回开发机（选择一种方式）
# - AirDrop
# - U盘
# - scp FileFly_Release.zip user@dev-mac:~/Downloads/
```

---

## 🔍 证书信息

您配置的证书信息：
```
证书名称: Developer ID Application: mingqing wu (A8JJ28CX2A)
Team ID: A8JJ28CX2A
证书哈希: 468FB2F0D40D691A3A6315F0A16192D9B2C26941
状态: ✅ 有效
```

---

## 📋 检查清单

### 在开发机上（当前电脑）
- [x] 创建打包脚本
- [x] 创建签名脚本
- [x] 创建文档
- [x] 优化权限配置
- [ ] 运行 `./pack_for_build.sh`
- [ ] 传输到构建 Mac

### 在构建 Mac 上（有证书的电脑）
- [ ] 解压项目
- [ ] 生成 App 专用密码
- [ ] 配置公证凭证
- [ ] 修改脚本中的 Apple ID
- [ ] 运行 `./sign_and_notarize_filefly.sh`
- [ ] 测试安装包
- [ ] 传输回开发机

---

## 🎯 关键配置点

### 1. 证书配置（已完成）✅
```bash
security find-identity -v -p codesigning
# 应该能看到：Developer ID Application: mingqing wu (A8JJ28CX2A)
```

### 2. 公证凭证（需在构建 Mac 上配置）
```bash
xcrun notarytool store-credentials "filefly-notary" \
  --apple-id "你的邮箱" \
  --team-id "A8JJ28CX2A" \
  --password "App专用密码"
```

### 3. 脚本配置（需修改）
在 `sign_and_notarize_filefly.sh` 中：
- ✏️ `APPLE_ID="your@email.com"` → 改为实际邮箱
- ✅ `DEVELOPER_ID` 已配置
- ✅ `TEAM_ID` 已配置

---

## 🆘 常见问题

### Q1: 公证失败怎么办？

**A:** 查看日志
```bash
cat release_output/notarization_log.json
```

常见原因：
- 凭证配置错误 → 重新运行 `notarytool store-credentials`
- 证书过期 → 检查证书有效期
- 权限配置问题 → 已优化，不应出现

---

### Q2: 能否跳过公证？

**A:** 可以，用于测试
- 脚本会检测到未配置凭证时询问
- 输入 `y` 继续，会跳过公证步骤
- **注意：** 未公证的应用在其他 Mac 上首次打开会有安全警告

---

### Q3: 如何修改版本号？

**A:** 编辑脚本
```bash
nano sign_and_notarize_filefly.sh

# 修改这两行：
VERSION="1.0.1"      # 版本号
BUILD_NUMBER="2"     # 构建号
```

---

### Q4: 构建失败怎么办？

**A:** 手动构建查看详细错误
```bash
flutter clean
flutter pub get
flutter build macos --release --verbose
```

---

## 📚 参考文档

- **详细指南：** `MACOS_BUILD_GUIDE.md`
- **快速参考：** `QUICK_BUILD.md`
- **Apple 开发者：** https://developer.apple.com/account

---

## 💡 提示和建议

1. **保持网络稳定**  
   公证过程需要稳定的网络连接

2. **首次较慢**  
   第一次公证可能需要更长时间

3. **保存日志**  
   每次构建都会生成报告，便于追踪问题

4. **测试后分发**  
   建议先在测试 Mac 上验证再正式分发

5. **证书有效期**  
   Developer ID 证书有效期 5 年，注意续期

6. **版本管理**  
   每次发布建议在 Git 上打 tag

---

## 📞 技术支持

如遇到问题，请检查：

1. **构建报告**  
   `release_output/build_report_*.txt`

2. **公证日志**  
   `release_output/notarization_log.json`

3. **Flutter 日志**  
   重新运行时添加 `--verbose` 参数

4. **证书状态**  
   运行 `./check-codesign.sh`（在有证书的 Mac 上）

---

## ✅ 总结

**您现在拥有：**
- ✅ 完整的自动化打包脚本
- ✅ 详细的使用文档
- ✅ 优化的权限配置
- ✅ 便捷的打包传输工具

**只需 3 个命令：**
```bash
# 1. 在开发机打包
./pack_for_build.sh

# 2. 传输到构建 Mac，解压后配置并运行
./sign_and_notarize_filefly.sh

# 3. 完成！
```

---

**祝打包顺利！🎉**

如有问题，请查看 `MACOS_BUILD_GUIDE.md` 获取更多帮助。

