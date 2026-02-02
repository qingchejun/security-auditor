#!/bin/bash

# 带来源检查的审计脚本
# 先检查来源信任级别，再决定审计策略

set -uo pipefail  # 不使用 -e，因为需要处理非零退出码

SKILL_PATH="${1:-.}"
SCRIPT_DIR="$(dirname "$0")"
CHECK_SOURCE_SCRIPT="$SCRIPT_DIR/check-source.sh"
AUDIT_SCRIPT="$SCRIPT_DIR/audit.sh"
LOG_SCRIPT="$SCRIPT_DIR/log-audit.sh"

# 提取skill名称
SKILL_NAME=$(basename "$SKILL_PATH")

# 颜色
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "════════════════════════════════════════════════════════════"
echo "🛡️  OpenClaw 安全审计系统 v2.0"
echo "════════════════════════════════════════════════════════════"
echo ""

# 步骤1：检查来源
bash "$CHECK_SOURCE_SCRIPT" "$SKILL_PATH"
SOURCE_TRUST_LEVEL=$?

echo ""
echo "────────────────────────────────────────────────────────────"
echo ""

# 步骤2：根据信任级别决定审计策略
case $SOURCE_TRUST_LEVEL in
    0)
        # 官方来源，跳过审计
        echo -e "${GREEN}✅ 官方来源，安全可信，跳过审计${NC}"
        echo ""
        echo "ℹ️  即使跳过审计，也会记录安装日志用于审计追踪"

        # 记录日志
        bash "$LOG_SCRIPT" "$SKILL_NAME" "$SKILL_PATH" "SAFE" "官方来源,跳过审计" "official" 2>/dev/null || true

        exit 0
        ;;

    1)
        # 白名单依赖，仅检查CRITICAL
        echo -e "${BLUE}🔍 白名单依赖，执行轻度审计（仅CRITICAL）${NC}"
        echo ""

        # 运行完整审计，但只关注CRITICAL
        bash "$AUDIT_SCRIPT" "$SKILL_PATH"
        AUDIT_RESULT=$?

        if [ $AUDIT_RESULT -eq 1 ]; then
            # 发现CRITICAL问题
            bash "$LOG_SCRIPT" "$SKILL_NAME" "$SKILL_PATH" "CRITICAL" "白名单依赖但发现严重问题" "whitelist" 2>/dev/null || true
            exit 1
        else
            # 没有CRITICAL问题，即使有其他警告也允许安装
            echo ""
            echo "────────────────────────────────────────────────────────────"
            echo -e "${GREEN}✅ 轻度审计通过（白名单依赖）${NC}"
            echo "   未发现严重安全问题，其他警告已记录"

            # 记录日志
            RISK_LEVEL="LOW"
            if [ $AUDIT_RESULT -eq 2 ]; then
                RISK_LEVEL="HIGH"
            elif [ $AUDIT_RESULT -eq 3 ]; then
                RISK_LEVEL="MEDIUM"
            fi
            bash "$LOG_SCRIPT" "$SKILL_NAME" "$SKILL_PATH" "$RISK_LEVEL" "白名单依赖,轻度审计通过" "whitelist" 2>/dev/null || true

            exit 0
        fi
        ;;

    2)
        # 未知来源，完整审计
        echo -e "${YELLOW}🔍 未知来源，执行完整安全审计${NC}"
        echo ""

        # 运行完整审计
        bash "$AUDIT_SCRIPT" "$SKILL_PATH"
        AUDIT_RESULT=$?

        # 记录日志
        RISK_LEVEL="UNKNOWN"
        case $AUDIT_RESULT in
            1) RISK_LEVEL="CRITICAL" ;;
            2) RISK_LEVEL="HIGH" ;;
            3) RISK_LEVEL="MEDIUM" ;;
            0) RISK_LEVEL="LOW" ;;
        esac
        bash "$LOG_SCRIPT" "$SKILL_NAME" "$SKILL_PATH" "$RISK_LEVEL" "未知来源,完整审计" "community" 2>/dev/null || true

        exit $AUDIT_RESULT
        ;;

    *)
        echo -e "${RED}❌ 来源检查失败${NC}"
        exit 1
        ;;
esac
