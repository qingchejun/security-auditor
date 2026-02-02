#!/bin/bash
# 安装脚本 - 将 security-auditor 安装到 OpenClaw skills 目录

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.openclaw/skills/security-auditor"

echo "🔧 OpenClaw Security Auditor 安装脚本"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 检查 OpenClaw 是否安装
if [ ! -d "${HOME}/.openclaw" ]; then
    echo "❌ 错误: 未检测到 OpenClaw 安装"
    echo "   请先安装 OpenClaw: https://openclaw.ai"
    exit 1
fi

# 备份旧版本
if [ -d "$TARGET_DIR" ]; then
    BACKUP_DIR="${HOME}/.openclaw/skills/security-auditor-backup-$(date +%Y%m%d-%H%M%S)"
    echo "📦 备份旧版本到: $BACKUP_DIR"
    mv "$TARGET_DIR" "$BACKUP_DIR"
fi

# 复制文件
echo "📂 安装到: $TARGET_DIR"
mkdir -p "$TARGET_DIR"
cp -r "$SCRIPT_DIR"/* "$TARGET_DIR/"

# 设置权限
echo "🔐 设置执行权限..."
chmod +x "$TARGET_DIR"/*.sh

# 验证安装
echo "✅ 验证安装..."
if openclaw skills check | grep -q "security-auditor"; then
    echo ""
    echo "🎉 安装成功！"
    echo ""
    echo "使用方法:"
    echo "  openclaw security audit-smart <path>     # 智能审计"
    echo "  openclaw security audit <path>           # 完整审计"
    echo "  openclaw security check-source <path>    # 检查来源"
    echo "  openclaw security log                    # 查看日志"
else
    echo "⚠️  安装完成，但未能验证 Skill 注册"
    echo "   请运行: openclaw skills check"
fi
