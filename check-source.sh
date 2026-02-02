#!/bin/bash

# 来源信任级别检测脚本
# 返回值：
# 0 = 可信来源，跳过审计
# 1 = 官方推荐，仅检查CRITICAL
# 2 = 未知来源，完整审计

set -euo pipefail

SKILL_PATH="${1:-.}"
SCRIPT_DIR="$(dirname "$0")"
WHITELIST_FILE="$SCRIPT_DIR/whitelist.json"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# 检查是否是OpenClaw官方来源
check_openclaw_official() {
    # 检查是否有.git目录
    if [ -d "$SKILL_PATH/.git" ]; then
        REMOTE_URL=$(cd "$SKILL_PATH" && git remote get-url origin 2>/dev/null || echo "")

        if echo "$REMOTE_URL" | grep -qE "openclaw\.ai|github\.com/(anthropics|openclaw)/"; then
            echo -e "${GREEN}✓ OpenClaw官方来源${NC}"
            return 0
        fi
    fi

    return 1
}

# 检查包是否在白名单中
is_package_whitelisted() {
    local pkg="$1"

    # 检查是否在黑名单中
    if grep -q "\"$pkg\"" "$WHITELIST_FILE" 2>/dev/null; then
        if cat "$WHITELIST_FILE" | grep -A 20 "\"blacklist\"" | grep -q "\"$pkg\""; then
            echo -e "${RED}⚠️  发现黑名单包: $pkg${NC}"
            return 2
        fi
    fi

    # 检查是否是可信scope
    if echo "$pkg" | grep -qE "^@(types|babel|vue|nuxt|angular|react|microsoft|google-cloud|aws-sdk|anthropic|openai|stripe|vercel|supabase|prisma|nestjs|tensorflow)/"; then
        return 0
    fi

    # 检查基础包名（去掉@scope前缀）
    local base_pkg=$(echo "$pkg" | sed 's|^@[^/]*/||')

    # 检查是否在可信包列表中
    if grep -q "\"$base_pkg\"" "$WHITELIST_FILE" 2>/dev/null; then
        return 0
    fi

    return 1
}

# 检查package.json中的依赖是否全部在白名单中
check_npm_dependencies() {
    if [ ! -f "$SKILL_PATH/package.json" ]; then
        return 1
    fi

    # 使用Node.js准确提取依赖列表
    local all_deps=$(node -e "
        const pkg = require('$SKILL_PATH/package.json');
        const deps = [
            ...Object.keys(pkg.dependencies || {}),
            ...Object.keys(pkg.devDependencies || {})
        ];
        console.log(deps.join('\n'));
    " 2>/dev/null || true)

    if [ -z "$all_deps" ]; then
        return 1
    fi

    # 检查每个依赖
    local untrusted_found=false
    local untrusted_list=""

    for dep in $all_deps; do
        if ! is_package_whitelisted "$dep"; then
            untrusted_found=true
            untrusted_list="$untrusted_list\n  • $dep"
        fi
    done

    if [ "$untrusted_found" = false ]; then
        echo -e "${GREEN}✓ 所有NPM依赖都在白名单中${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  发现非白名单依赖:${NC}"
        echo -e "$untrusted_list"
        return 1
    fi
}

# 主逻辑
main() {
    echo "🔍 检查来源信任级别..."
    echo ""

    # 1. 检查是否是OpenClaw官方
    if check_openclaw_official; then
        echo -e "${BLUE}📋 信任级别: 官方来源${NC}"
        echo "   ➜ 跳过安全审计"
        return 0
    fi

    # 2. 检查NPM依赖
    if check_npm_dependencies; then
        echo -e "${BLUE}📋 信任级别: 全部使用白名单依赖${NC}"
        echo "   ➜ 仅检查CRITICAL级别风险"
        return 1
    fi

    # 3. 未知来源
    echo -e "${YELLOW}📋 信任级别: 未知来源${NC}"
    echo "   ➜ 需要完整安全审计"
    return 2
}

main
exit $?
