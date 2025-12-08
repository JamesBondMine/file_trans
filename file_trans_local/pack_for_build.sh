#!/bin/bash

# ============================================
# FileFly 项目打包脚本
# 用于将项目打包传输到构建机器
# ============================================

set -e

echo ""
echo "╔════════════════════════════════════════╗"
echo "║   FileFly 项目打包工具                ║"
echo "╚════════════════════════════════════════╝"
echo ""

# 输出文件名
OUTPUT_FILE="filefly_source_$(date +%Y%m%d_%H%M%S).tar.gz"

echo "📦 正在打包项目..."
echo ""

# 显示将要排除的内容
echo "排除以下内容："
echo "  - build/ 目录"
echo "  - ios/Pods/ 目录"
echo "  - macos/Pods/ 目录"
echo "  - .dart_tool/ 目录"
echo "  - *.dmg 文件"
echo "  - node_modules/ 目录"
echo ""

# 打包，排除不必要的文件
tar --exclude='build' \
    --exclude='ios/Pods' \
    --exclude='macos/Pods' \
    --exclude='.dart_tool' \
    --exclude='*.dmg' \
    --exclude='node_modules' \
    --exclude='.git' \
    --exclude='release_output' \
    -czf "${OUTPUT_FILE}" \
    --exclude="${OUTPUT_FILE}" \
    .

# 显示结果
echo ""
echo "✅ 打包完成！"
echo ""
echo "文件信息："
ls -lh "${OUTPUT_FILE}"
echo ""

# 显示文件大小（更友好的格式）
SIZE=$(du -h "${OUTPUT_FILE}" | cut -f1)
echo "📦 压缩包大小: ${SIZE}"
echo "📄 文件名称: ${OUTPUT_FILE}"
echo "📍 文件位置: $(pwd)/${OUTPUT_FILE}"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📤 下一步操作："
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. 传输文件到构建 Mac："
echo "   - AirDrop"
echo "   - U盘"
echo "   - scp ${OUTPUT_FILE} user@build-mac:~/"
echo ""
echo "2. 在构建 Mac 上解压："
echo "   mkdir ~/FileFly_Build"
echo "   cd ~/FileFly_Build"
echo "   tar -xzf ~/${OUTPUT_FILE}"
echo ""
echo "3. 修改配置并运行："
echo "   nano sign_and_notarize_filefly.sh"
echo "   # 修改 APPLE_ID 为实际邮箱"
echo "   ./sign_and_notarize_filefly.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 列出包含的重要文件
echo "📋 打包内容包括："
echo "  ✓ sign_and_notarize_filefly.sh  (签名脚本)"
echo "  ✓ MACOS_BUILD_GUIDE.md          (详细指南)"
echo "  ✓ QUICK_BUILD.md                (快速参考)"
echo "  ✓ lib/                          (源代码)"
echo "  ✓ macos/                        (macOS 配置)"
echo "  ✓ pubspec.yaml                  (项目配置)"
echo "  ✓ assets/                       (资源文件)"
echo ""

echo "🎉 准备就绪！可以传输到构建机器了。"
echo ""

