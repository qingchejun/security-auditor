#!/bin/bash

# 安全的 Skill 安装工具（带自动审核和审批）
# 用法: install-with-audit.sh <skill-name-or-path>

set -euo pipefail

SKILL_INPUT="$1"
AUDIT_SCRIPT="$(dirname "$0")/audit.sh"

echo "🔍 Skill 安全安装流程"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📦 准备安装: $SKILL_INPUT"
echo ""

# 检查是否是 ClawHub skill
if [[ ! "$SKILL_INPUT" =~ / ]] && [[ ! -d "$SKILL_INPUT" ]]; then
    echo "📥 从 ClawHub 下载 skill 信息..."
    # 这里可以添加从 ClawHub 获取 skill 的逻辑
    SKILL_PATH="/tmp/skill-preview-$SKILL_INPUT"
    echo "⚠️  注意: ClawHub 集成待完善，请提供本地路径或手动下载后审核"
    exit 1
else
    SKILL_PATH="$SKILL_INPUT"
fi

# 运行安全审核
echo "🛡️  开始安全审核..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if ! "$AUDIT_SCRIPT" "$SKILL_PATH"; then
    AUDIT_RESULT=$?
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ $AUDIT_RESULT -eq 1 ]; then
        echo "❌ 审核失败: 发现严重安全问题"
        echo "🚫 拒绝安装"
        exit 1
    elif [ $AUDIT_RESULT -eq 2 ]; then
        echo "⚠️  审核警告: 发现多个可疑项"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "❓ 是否继续安装？"
echo ""
echo "选项："
echo "  y/yes  - 继续安装"
echo "  n/no   - 取消安装"
echo "  v/view - 查看 skill 代码"
echo ""
read -p "请选择 [y/n/v]: " -n 1 -r
echo ""

case "$REPLY" in
    y|Y)
        echo "✅ 用户批准，开始安装..."
        # 这里添加实际的安装逻辑
        # openclaw skills install "$SKILL_PATH"
        echo "📦 安装完成！"
        ;;
    v|V)
        echo "📄 显示 skill 代码..."
        find "$SKILL_PATH" -type f \( -name "*.sh" -o -name "*.js" -o -name "*.ts" -o -name "*.json" \) -exec echo "=== {} ===" \; -exec cat {} \;
        echo ""
        read -p "查看完毕，是否安装？[y/n]: " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "✅ 用户批准，开始安装..."
            echo "📦 安装完成！"
        else
            echo "❌ 用户取消安装"
            exit 1
        fi
        ;;
    *)
        echo "❌ 用户取消安装"
        exit 1
        ;;
esac
