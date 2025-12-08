#!/bin/bash

# ============================================
# FileFly macOS 签名和公证脚本
# ============================================
# 功能：构建、签名、创建DMG、公证、导出
# 作者：自动生成
# 日期：2025-12-08
# ============================================

set -e  # 遇到错误立即退出

# ============================================
# 配置区（重要：请根据实际情况修改）
# ============================================

# 应用信息
APP_NAME="FileFly"
VERSION="1.0.0"
BUILD_NUMBER="1"

# 证书信息（已配置好的证书）
DEVELOPER_ID="Developer ID Application: mingqing wu (A8JJ28CX2A)"
TEAM_ID="A8JJ28CX2A"

# Apple ID 信息（用于公证）
APPLE_ID="your@email.com"  # ⚠️ 修改为实际的 Apple ID 邮箱
KEYCHAIN_PROFILE="filefly-notary"  # 凭证配置文件名称

# 路径配置
APP_PATH="build/macos/Build/Products/Release/${APP_NAME}.app"
OUTPUT_DIR="release_output"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DMG_NAME="${APP_NAME}_v${VERSION}_${TIMESTAMP}.dmg"
FINAL_DMG="${OUTPUT_DIR}/${DMG_NAME}"

# ============================================
# 颜色输出
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 输出函数
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  $1${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
}

# ============================================
# 检查前置条件
# ============================================
check_prerequisites() {
    log_step "检查前置条件"
    
    # 检查 Flutter
    if ! command -v flutter &> /dev/null; then
        log_error "未找到 Flutter，请先安装 Flutter"
        exit 1
    fi
    log_success "Flutter: $(flutter --version | head -n 1)"
    
    # 检查 create-dmg
    if ! command -v create-dmg &> /dev/null; then
        log_warning "未找到 create-dmg，正在安装..."
        brew install create-dmg
    fi
    log_success "create-dmg 已安装"
    
    # 检查证书
    if ! security find-identity -v -p codesigning | grep -q "${TEAM_ID}"; then
        log_error "未找到证书: ${DEVELOPER_ID}"
        log_info "请运行: security find-identity -v -p codesigning"
        exit 1
    fi
    log_success "证书已找到: ${DEVELOPER_ID}"
    
    # 检查钥匙串凭证（仅警告，不强制）
    if ! xcrun notarytool history --keychain-profile "${KEYCHAIN_PROFILE}" &> /dev/null; then
        log_warning "未找到钥匙串凭证: ${KEYCHAIN_PROFILE}"
        log_warning "如需公证，请先运行以下命令存储凭证："
        echo ""
        echo "  xcrun notarytool store-credentials \"${KEYCHAIN_PROFILE}\" \\"
        echo "    --apple-id \"${APPLE_ID}\" \\"
        echo "    --team-id \"${TEAM_ID}\" \\"
        echo "    --password \"xxxx-xxxx-xxxx-xxxx\""
        echo ""
        read -p "是否继续（将跳过公证步骤）？[y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        SKIP_NOTARIZATION=true
    else
        log_success "钥匙串凭证已配置"
        SKIP_NOTARIZATION=false
    fi
}

# ============================================
# 清理和准备
# ============================================
clean_and_prepare() {
    log_step "清理和准备环境"
    
    # 清理旧的构建
    log_info "清理旧的构建文件..."
    flutter clean
    
    # 创建输出目录
    mkdir -p "${OUTPUT_DIR}"
    
    # 获取依赖
    log_info "获取依赖..."
    flutter pub get
    
    log_success "准备完成"
}

# ============================================
# 构建应用
# ============================================
build_app() {
    log_step "构建 macOS 应用"
    
    log_info "开始构建（这可能需要几分钟）..."
    flutter build macos --release \
        --build-name="${VERSION}" \
        --build-number="${BUILD_NUMBER}"
    
    if [ ! -d "${APP_PATH}" ]; then
        log_error "构建失败：未找到 ${APP_PATH}"
        exit 1
    fi
    
    log_success "应用构建完成: ${APP_PATH}"
}

# ============================================
# 代码签名
# ============================================
sign_app() {
    log_step "对应用进行代码签名"
    
    log_info "使用证书: ${DEVELOPER_ID}"
    
    # 检查 entitlements 文件
    ENTITLEMENTS_FILE="macos/Runner/Release.entitlements"
    if [ ! -f "${ENTITLEMENTS_FILE}" ]; then
        log_warning "未找到 ${ENTITLEMENTS_FILE}，使用默认配置"
        ENTITLEMENTS_OPTION=""
    else
        ENTITLEMENTS_OPTION="--entitlements ${ENTITLEMENTS_FILE}"
        log_info "使用权限文件: ${ENTITLEMENTS_FILE}"
    fi
    
    # 执行签名
    codesign --deep --force --verify --verbose \
        --sign "${DEVELOPER_ID}" \
        --options runtime \
        ${ENTITLEMENTS_OPTION} \
        "${APP_PATH}"
    
    # 验证签名
    log_info "验证签名..."
    codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
    
    # 显示签名信息
    log_info "签名信息："
    codesign -dv "${APP_PATH}" 2>&1 | grep -E "Authority|TeamIdentifier|Identifier"
    
    log_success "应用签名完成"
}

# ============================================
# 创建 DMG
# ============================================
create_dmg_file() {
    log_step "创建 DMG 安装包"
    
    log_info "创建 DMG: ${DMG_NAME}"
    
    # 临时 DMG 路径
    TEMP_DMG="${OUTPUT_DIR}/temp_${DMG_NAME}"
    
    # 删除旧的临时文件
    rm -f "${TEMP_DMG}"
    
    # 创建 DMG
    create-dmg \
        --volname "${APP_NAME}" \
        --volicon "assets/logo.png" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 175 120 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 425 120 \
        --no-internet-enable \
        "${TEMP_DMG}" \
        "${APP_PATH}" 2>&1 || true
    
    # create-dmg 可能返回非零退出码但实际成功，所以检查文件是否存在
    if [ ! -f "${TEMP_DMG}" ]; then
        log_error "DMG 创建失败"
        exit 1
    fi
    
    log_success "DMG 创建完成"
}

# ============================================
# 对 DMG 签名
# ============================================
sign_dmg() {
    log_step "对 DMG 进行签名"
    
    TEMP_DMG="${OUTPUT_DIR}/temp_${DMG_NAME}"
    
    log_info "签名 DMG..."
    codesign --sign "${DEVELOPER_ID}" \
        --force \
        --verify \
        --verbose \
        "${TEMP_DMG}"
    
    # 验证 DMG 签名
    log_info "验证 DMG 签名..."
    codesign --verify --verbose=2 "${TEMP_DMG}"
    
    log_success "DMG 签名完成"
}

# ============================================
# 公证 DMG
# ============================================
notarize_dmg() {
    if [ "${SKIP_NOTARIZATION}" = true ]; then
        log_warning "跳过公证步骤"
        # 直接重命名为最终文件
        TEMP_DMG="${OUTPUT_DIR}/temp_${DMG_NAME}"
        mv "${TEMP_DMG}" "${FINAL_DMG}"
        return
    fi
    
    log_step "提交公证"
    
    TEMP_DMG="${OUTPUT_DIR}/temp_${DMG_NAME}"
    
    log_info "提交 DMG 到 Apple 进行公证..."
    log_warning "这个过程可能需要 5-15 分钟，请耐心等待..."
    
    # 提交公证
    SUBMISSION_OUTPUT=$(xcrun notarytool submit "${TEMP_DMG}" \
        --keychain-profile "${KEYCHAIN_PROFILE}" \
        --wait 2>&1)
    
    echo "${SUBMISSION_OUTPUT}"
    
    # 检查公证结果
    if echo "${SUBMISSION_OUTPUT}" | grep -q "status: Accepted"; then
        log_success "公证成功！"
    else
        log_error "公证失败"
        
        # 尝试提取 submission ID
        SUBMISSION_ID=$(echo "${SUBMISSION_OUTPUT}" | grep "id:" | head -1 | awk '{print $2}')
        if [ -n "${SUBMISSION_ID}" ]; then
            log_info "获取详细日志..."
            xcrun notarytool log "${SUBMISSION_ID}" \
                --keychain-profile "${KEYCHAIN_PROFILE}" \
                "${OUTPUT_DIR}/notarization_log.json"
            log_info "日志已保存到: ${OUTPUT_DIR}/notarization_log.json"
        fi
        
        exit 1
    fi
}

# ============================================
# 装订票据
# ============================================
staple_dmg() {
    if [ "${SKIP_NOTARIZATION}" = true ]; then
        log_warning "未公证，跳过装订步骤"
        return
    fi
    
    log_step "装订公证票据"
    
    TEMP_DMG="${OUTPUT_DIR}/temp_${DMG_NAME}"
    
    log_info "装订票据到 DMG..."
    xcrun stapler staple "${TEMP_DMG}"
    
    # 验证装订
    log_info "验证装订..."
    xcrun stapler validate "${TEMP_DMG}"
    
    # 重命名为最终文件
    mv "${TEMP_DMG}" "${FINAL_DMG}"
    
    log_success "票据装订完成"
}

# ============================================
# 验证最终产物
# ============================================
verify_final() {
    log_step "验证最终产物"
    
    log_info "文件信息："
    ls -lh "${FINAL_DMG}"
    
    log_info "签名验证："
    codesign -dv --verbose=4 "${FINAL_DMG}" 2>&1 | head -20
    
    if [ "${SKIP_NOTARIZATION}" = false ]; then
        log_info "Gatekeeper 验证："
        spctl -a -t open --context context:primary-signature -v "${FINAL_DMG}" 2>&1 || true
    fi
    
    log_success "验证完成"
}

# ============================================
# 生成总结报告
# ============================================
generate_report() {
    log_step "生成报告"
    
    REPORT_FILE="${OUTPUT_DIR}/build_report_${TIMESTAMP}.txt"
    
    cat > "${REPORT_FILE}" << EOF
========================================
FileFly macOS 构建报告
========================================

构建时间: $(date)
版本号: ${VERSION}
构建号: ${BUILD_NUMBER}

证书信息:
  名称: ${DEVELOPER_ID}
  Team ID: ${TEAM_ID}

输出文件:
  DMG: ${FINAL_DMG}
  大小: $(ls -lh "${FINAL_DMG}" | awk '{print $5}')

签名状态:
$(codesign -dv "${FINAL_DMG}" 2>&1)

公证状态:
$(if [ "${SKIP_NOTARIZATION}" = true ]; then echo "  未公证"; else echo "  已公证并装订"; fi)

========================================
分发说明
========================================

1. 测试安装：
   打开 ${FINAL_DMG}，将 ${APP_NAME}.app 拖到应用程序文件夹

2. 分发方式：
   - 直接分发 DMG 文件
   - 或上传到网站供用户下载

3. 用户安装：
   用户双击 DMG，拖拽安装即可

$(if [ "${SKIP_NOTARIZATION}" = true ]; then
echo "⚠️  注意：此版本未经公证"
echo "   - 用户首次打开可能看到安全警告"
echo "   - 需要在系统偏好设置 → 安全性与隐私中允许"
echo "   - 建议完成公证后再正式分发"
fi)

========================================
EOF
    
    cat "${REPORT_FILE}"
    log_success "报告已保存到: ${REPORT_FILE}"
}

# ============================================
# 主流程
# ============================================
main() {
    clear
    
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   FileFly macOS 签名和公证工具        ║"
    echo "║   版本: ${VERSION}                          ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    
    # 执行各个步骤
    check_prerequisites
    clean_and_prepare
    build_app
    sign_app
    create_dmg_file
    sign_dmg
    notarize_dmg
    staple_dmg
    verify_final
    generate_report
    
    # 完成
    log_step "🎉 全部完成！"
    
    echo ""
    log_success "最终文件: ${FINAL_DMG}"
    echo ""
    log_info "下一步操作："
    echo "  1. 测试安装: open ${FINAL_DMG}"
    echo "  2. 查看报告: cat ${OUTPUT_DIR}/build_report_${TIMESTAMP}.txt"
    if [ "${SKIP_NOTARIZATION}" = true ]; then
        echo ""
        log_warning "建议："
        echo "  - 配置公证凭证后重新运行以获得完整签名的版本"
        echo "  - 公证后的应用在所有 Mac 上无需额外授权即可运行"
    fi
    echo ""
}

# ============================================
# 错误处理
# ============================================
trap 'log_error "脚本执行失败，请检查错误信息"; exit 1' ERR

# 运行主流程
main

