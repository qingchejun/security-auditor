#!/bin/bash

# Skill Security Auditor v2.0
# 审核 OpenClaw skills 的安全性（带风险评估和建议）

set -euo pipefail

SKILL_PATH="${1:-.}"
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 扫描范围（仅代码/配置文件）
SCAN_FILES=()
while IFS= read -r f; do
  SCAN_FILES+=("$f")
done < <(find "$SKILL_PATH" -type f \( \
  -name "*.sh" -o -name "*.bash" -o -name "*.zsh" -o \
  -name "*.js" -o -name "*.ts" -o -name "*.py" -o \
  -name "*.json" -o -name "*.yaml" -o -name "*.yml" \
\) \
  ! -path "*/.git/*" \
  ! -path "*/node_modules/*" \
  ! -path "*/dist/*" \
  ! -path "*/build/*" \
  ! -path "*/venv/*" \
  ! -path "*/.venv/*" \
  ! -path "*/.next/*" \
  ! -path "*/.cache/*" 2>/dev/null || true)

NO_SCAN=0
if [ ${#SCAN_FILES[@]} -eq 0 ]; then
  echo -e "${YELLOW}⚠️  未找到可扫描文件（仅扫描代码/配置文件）${NC}"
  NO_SCAN=1
fi

echo "🔍 开始审核 skill: $SKILL_PATH"
echo ""

if [ "$NO_SCAN" -eq 1 ]; then
  echo -e "${GREEN}✅ 无可扫描源码文件，判定为低风险${NC}"
  exit 0
fi

# 检查项目计数和详细信息
WARNINGS=0
CRITICAL=0
declare -a WARNING_DETAILS=()
declare -a RISK_LEVELS=()

# 1. 检查危险的文件系统操作
echo "📁 检查危险的文件系统操作..."
# 排除文档、注释、grep模式本身、变量赋值中的字符串
DANGEROUS_FS=$(grep -hE "rm -rf|rm -fr|> /dev/|chmod 777|chmod -R 777|mkfs|dd if=|fdisk|parted|format" ${SCAN_FILES[@]} 2>/dev/null | \
    grep -vE "^[[:space:]]*(#|//|/\*|\*)" | \
    grep -v "grep.*-rE" | \
    grep -v "WARNING_DETAILS" | \
    grep -v "RISK_LEVELS" || true)

if [ -n "$DANGEROUS_FS" ]; then
    echo -e "${RED}❌ CRITICAL: 发现危险的文件系统操作${NC}"
    echo "$DANGEROUS_FS" | head -3
    ((CRITICAL++))
    WARNING_DETAILS+=("【严重】危险的文件系统操作（rm -rf, chmod 777, 磁盘格式化等）")
    RISK_LEVELS+=("CRITICAL")
else
    echo -e "${GREEN}✅ 通过${NC}"
fi
echo ""

# 2. 检查网络请求
echo "🌐 检查网络请求..."
HTTP_FOUND=false
HTTPS_FOUND=false
EXTERNAL_URLS=$(grep -hE "https?://" ${SCAN_FILES[@]} 2>/dev/null | grep -oE "https?://[^\"' ]+" | sort -u || true)

if [ -n "$EXTERNAL_URLS" ]; then
    # 检查是否有非 HTTPS 请求
    if echo "$EXTERNAL_URLS" | grep -q "^http://"; then
        HTTP_FOUND=true
        HTTP_URLS=$(echo "$EXTERNAL_URLS" | grep "^http://" || true)
        echo -e "${YELLOW}⚠️  发现非 HTTPS 请求:${NC}"
        echo "$HTTP_URLS"

        # 检查是否是已知的安全服务
        if echo "$HTTP_URLS" | grep -q "wttr.in\|ip-api.com\|freegeoip.app"; then
            echo -e "${BLUE}ℹ️  这些是常见的公开 API，通常用于天气/地理位置查询${NC}"
            WARNING_DETAILS+=("【低风险】使用非 HTTPS 的公开 API（wttr.in 等），数据可能被窃听，但不涉及敏感信息")
            RISK_LEVELS+=("LOW")
        else
            WARNING_DETAILS+=("【中风险】使用非 HTTPS 请求，数据传输不加密，可能被窃听或篡改")
            RISK_LEVELS+=("MEDIUM")
        fi
        ((WARNINGS++))
    fi

    # 列出所有外部 URL
    echo -e "${BLUE}ℹ️  外部服务依赖:${NC}"
    echo "$EXTERNAL_URLS"

    # 评估外部依赖风险
    URL_COUNT=$(echo "$EXTERNAL_URLS" | wc -l)
    if [ "$URL_COUNT" -gt 5 ]; then
        WARNING_DETAILS+=("【中风险】依赖较多外部服务（${URL_COUNT} 个），增加供应链风险")
        RISK_LEVELS+=("MEDIUM")
    else
        WARNING_DETAILS+=("【低风险】使用外部 API（${URL_COUNT} 个），依赖第三方服务可用性")
        RISK_LEVELS+=("LOW")
    fi
    ((WARNINGS++))
else
    echo -e "${GREEN}✅ 无外部网络请求${NC}"
fi
echo ""

# 3. 检查命令执行
echo "⚡ 检查命令执行..."
DANGEROUS_EXEC=$(grep -hE "\beval\b|\bexec\b|system\(" ${SCAN_FILES[@]} 2>/dev/null || true)
SAFE_EXEC=$(grep -hE "spawn|child_process|execFile" ${SCAN_FILES[@]} 2>/dev/null || true)

if [ -n "$DANGEROUS_EXEC" ]; then
    echo -e "${RED}⚠️  发现危险的命令执行:${NC}"
    echo "$DANGEROUS_EXEC" | head -3
    WARNING_DETAILS+=("【高风险】使用 eval/exec 等危险函数，可能执行任意代码")
    RISK_LEVELS+=("HIGH")
    ((WARNINGS++))
elif [ -n "$SAFE_EXEC" ]; then
    echo -e "${YELLOW}ℹ️  发现子进程调用${NC}"
    WARNING_DETAILS+=("【低风险】使用子进程执行命令（spawn/execFile），属于正常操作")
    RISK_LEVELS+=("LOW")
    ((WARNINGS++))
else
    echo -e "${GREEN}✅ 通过${NC}"
fi
echo ""

# 4. 检查敏感数据访问
echo "🔐 检查敏感数据访问..."
SENSITIVE=$(grep -hE "\b(password|token|secret|api_key|apiKey|credentials|private_key)\b" ${SCAN_FILES[@]} 2>/dev/null | head -5 || true)
if [ -n "$SENSITIVE" ]; then
    echo -e "${YELLOW}⚠️  发现敏感数据关键词:${NC}"
    echo "$SENSITIVE"

    # 检查是否只是配置或文档
    if echo "$SENSITIVE" | grep -q "README\|example\|config\|\.md"; then
        echo -e "${BLUE}ℹ️  主要在文档/配置示例中${NC}"
        WARNING_DETAILS+=("【低风险】文档中提及敏感数据（配置示例），非实际使用")
        RISK_LEVELS+=("LOW")
    else
        WARNING_DETAILS+=("【中风险】代码中处理敏感数据，需确保安全存储和传输")
        RISK_LEVELS+=("MEDIUM")
    fi
    ((WARNINGS++))
else
    echo -e "${GREEN}✅ 通过${NC}"
fi
echo ""

# 5. 检查敏感文件泄露（凭证、密钥等）
echo "🔒 检查敏感文件泄露风险..."
# 排除文档和注释
SENSITIVE_FILES_LEAK=$(grep -hE "curl.*\.(env|npmrc|ssh|aws|credentials|gitconfig|git-credentials|netrc|gnupg|docker|kube)|wget.*\.(env|npmrc|ssh|aws|credentials)|tar.*\.(ssh|aws|openclaw|gnupg)|zip.*\.(ssh|aws|openclaw)" ${SCAN_FILES[@]} 2>/dev/null | \
    grep -vE "^[[:space:]]*(#|//|/\*|\*)" | \
    grep -v "grep.*-rE" || true)

# 检查OpenClaw目录访问
OPENCLAW_ACCESS=$(grep -hE "\.openclaw|openclaw\.json|gateway.*auth|exec-approvals" ${SCAN_FILES[@]} 2>/dev/null | \
    grep -vE "^[[:space:]]*(#|//|/\*|\*)" | \
    grep -v "grep.*-rE" | \
    grep -v "example" | \
    grep -v "comment" || true)

# 检查浏览器数据访问
BROWSER_DATA=$(grep -hE "Library/Application Support/(Google Chrome|Safari|Firefox)|Cookies|Login Data|Keychains" ${SCAN_FILES[@]} 2>/dev/null | \
    grep -vE "^[[:space:]]*(#|//|/\*|\*)" | \
    grep -v "grep.*-rE" | \
    grep -v "WARNING_DETAILS" || true)

# 检查命令历史访问
HISTORY_ACCESS=$(grep -hE "\.bash_history|\.zsh_history|\.node_repl_history|\.python_history" ${SCAN_FILES[@]} 2>/dev/null | \
    grep -vE "^[[:space:]]*(#|//|/\*|\*)" | \
    grep -v "grep.*-rE" || true)

# 检查macOS钥匙串访问
KEYCHAIN_ACCESS=$(grep -hE "security (find|dump).*keychain|security add-trusted-cert" ${SCAN_FILES[@]} 2>/dev/null | \
    grep -vE "^[[:space:]]*(#|//|/\*|\*)" | \
    grep -v "grep.*-rE" || true)

SENSITIVE_FILE_FOUND=false

if [ -n "$SENSITIVE_FILES_LEAK" ]; then
    echo -e "${RED}❌ CRITICAL: 发现凭证文件上传行为${NC}"
    echo "$SENSITIVE_FILES_LEAK" | head -5
    ((CRITICAL++))
    WARNING_DETAILS+=("【严重】尝试上传凭证文件（.env, .ssh, .aws, .npmrc等）")
    RISK_LEVELS+=("CRITICAL")
    SENSITIVE_FILE_FOUND=true
fi

if [ -n "$OPENCLAW_ACCESS" ]; then
    echo -e "${RED}❌ CRITICAL: 发现访问OpenClaw敏感数据${NC}"
    echo "$OPENCLAW_ACCESS" | head -3
    ((CRITICAL++))
    WARNING_DETAILS+=("【严重】访问OpenClaw配置和会话数据（可能窃取botToken）")
    RISK_LEVELS+=("CRITICAL")
    SENSITIVE_FILE_FOUND=true
fi

if [ -n "$BROWSER_DATA" ]; then
    echo -e "${RED}❌ CRITICAL: 发现访问浏览器数据${NC}"
    echo "$BROWSER_DATA" | head -3
    ((CRITICAL++))
    WARNING_DETAILS+=("【严重】访问浏览器Cookies/密码数据")
    RISK_LEVELS+=("CRITICAL")
    SENSITIVE_FILE_FOUND=true
fi

if [ -n "$HISTORY_ACCESS" ]; then
    echo -e "${RED}❌ CRITICAL: 发现访问命令历史${NC}"
    echo "$HISTORY_ACCESS" | head -3
    ((CRITICAL++))
    WARNING_DETAILS+=("【严重】读取命令历史（可能包含密码和敏感命令）")
    RISK_LEVELS+=("CRITICAL")
    SENSITIVE_FILE_FOUND=true
fi

if [ -n "$KEYCHAIN_ACCESS" ]; then
    echo -e "${RED}❌ CRITICAL: 发现访问macOS钥匙串${NC}"
    echo "$KEYCHAIN_ACCESS" | head -3
    ((CRITICAL++))
    WARNING_DETAILS+=("【严重】访问macOS钥匙串或安装证书")
    RISK_LEVELS+=("CRITICAL")
    SENSITIVE_FILE_FOUND=true
fi

if [ "$SENSITIVE_FILE_FOUND" = false ]; then
    echo -e "${GREEN}✅ 通过${NC}"
fi
echo ""

# 6. 检查环境变量
echo "🌍 检查环境变量使用..."
ENV_VARS=$(grep -hE "\$[A-Z_]+|process\.env|os\.getenv" ${SCAN_FILES[@]} 2>/dev/null | head -5 || true)
if [ -n "$ENV_VARS" ]; then
    echo -e "${BLUE}ℹ️  访问环境变量:${NC}"
    echo "$ENV_VARS"
    WARNING_DETAILS+=("【低风险】读取环境变量（如 HOME/PATH），属于正常操作")
    RISK_LEVELS+=("LOW")
    ((WARNINGS++))
fi
echo ""

# 7. 检查 package.json 脚本（安装场景高风险）
echo "📜 检查 package.json 脚本风险..."
if [ -f "$SKILL_PATH/package.json" ]; then
    SCRIPTS=$(node -e "const pkg=require('$SKILL_PATH/package.json'); Object.entries(pkg.scripts||{}).forEach(([k,v])=>console.log(k+'='+v));" 2>/dev/null || true)
    if [ -n "$SCRIPTS" ]; then
        RISKY_SCRIPTS=$(echo "$SCRIPTS" | grep -E "(preinstall|postinstall|install)=.*(curl .*\| *bash|wget .*\| *sh|node -e|python -c|bash -c)" || true)
        if [ -n "$RISKY_SCRIPTS" ]; then
            echo -e "${YELLOW}⚠️  发现安装脚本中的高风险命令:${NC}"
            echo "$RISKY_SCRIPTS" | head -3
            WARNING_DETAILS+=("【高风险】package.json 安装脚本中包含可疑执行（curl|bash、node -e、python -c 等）")
            RISK_LEVELS+=("HIGH")
            ((WARNINGS++))
        else
            echo -e "${GREEN}✅ 未发现高风险安装脚本${NC}"
        fi
    else
        echo -e "${GREEN}✅ 未定义 scripts${NC}"
    fi
else
    echo -e "${GREEN}✅ 无 package.json${NC}"
fi
echo ""

# 8. 检查危险管道执行
DANGEROUS_PIPE=$(grep -hE "(curl|wget).*(\|\s*(bash|sh))" ${SCAN_FILES[@]} 2>/dev/null | \
    grep -vE "^[[:space:]]*(#|//|/\*|\*)" || true)
if [ -n "$DANGEROUS_PIPE" ]; then
    echo -e "${YELLOW}⚠️  发现危险管道执行:${NC}"
    echo "$DANGEROUS_PIPE" | head -3
    WARNING_DETAILS+=("【高风险】发现 curl|bash 或 wget|sh 管道执行")
    RISK_LEVELS+=("HIGH")
    ((WARNINGS++))
else
    echo -e "${GREEN}✅ 未发现危险管道执行${NC}"
fi
echo ""

# 9. 检查一行执行（node -e / python -c / bash -c）
ONE_LINERS=$(grep -hE "\b(node -e|python -c|bash -c)\b" ${SCAN_FILES[@]} 2>/dev/null | \
    grep -vE "^[[:space:]]*(#|//|/\*|\*)" || true)
if [ -n "$ONE_LINERS" ]; then
    echo -e "${YELLOW}⚠️  发现一行执行:${NC}"
    echo "$ONE_LINERS" | head -3
    WARNING_DETAILS+=("【中风险】发现一行执行（node -e / python -c / bash -c）")
    RISK_LEVELS+=("MEDIUM")
    ((WARNINGS++))
else
    echo -e "${GREEN}✅ 未发现一行执行${NC}"
fi
echo ""

# 10. 检查 package.json 依赖
echo "📦 检查依赖项..."
if [ -f "$SKILL_PATH/package.json" ]; then
    DEPS_COUNT=$(cat "$SKILL_PATH/package.json" | grep -c "\".*\":" || echo "0")
    echo "发现 package.json，依赖项:"
    cat "$SKILL_PATH/package.json" | grep -A 20 "dependencies\|devDependencies" || true

    if [ "$DEPS_COUNT" -gt 10 ]; then
        WARNING_DETAILS+=("【中风险】依赖较多第三方包（${DEPS_COUNT}+），增加供应链风险")
        RISK_LEVELS+=("MEDIUM")
    else
        WARNING_DETAILS+=("【低风险】使用少量第三方依赖，建议检查包的信誉")
        RISK_LEVELS+=("LOW")
    fi
    ((WARNINGS++))
else
    echo -e "${GREEN}✅ 无 Node.js 依赖${NC}"
fi
echo ""

# 11. 检查持久化机制
echo "⏰ 检查持久化机制..."
PERSISTENCE=$(grep -hE "crontab|launchctl load|LaunchAgent|LaunchDaemon|/etc/periodic|login.*hook|\.bashrc|\.zshrc|\.profile" ${SCAN_FILES[@]} 2>/dev/null | \
    grep -vE "^[[:space:]]*(#|//|/\*|\*)" | \
    grep -v "grep.*-rE" | \
    grep -v "example" | \
    grep -v "comment" || true)

if [ -n "$PERSISTENCE" ]; then
    # 检查是否只是读取或文档说明
    if echo "$PERSISTENCE" | grep -qE "README|example|文档|说明|注释"; then
        echo -e "${BLUE}ℹ️  在文档中提及持久化${NC}"
        WARNING_DETAILS+=("【低风险】文档中提及持久化配置（如修改.bashrc）")
        RISK_LEVELS+=("LOW")
        ((WARNINGS++))
    else
        echo -e "${YELLOW}⚠️  发现持久化机制${NC}"
        echo "$PERSISTENCE" | head -3
        WARNING_DETAILS+=("【高风险】创建持久化机制（crontab, LaunchAgent等），可能长期驻留")
        RISK_LEVELS+=("HIGH")
        ((WARNINGS++))
    fi
else
    echo -e "${GREEN}✅ 通过${NC}"
fi
echo ""

# 12. 检查网络劫持和中间人攻击
echo "🌐 检查网络劫持风险..."
NETWORK_HIJACK=$(grep -hE "/etc/hosts|hosts.*127\.0\.0\.1|mitmproxy|charles.*proxy" ${SCAN_FILES[@]} 2>/dev/null | \
    grep -vE "^[[:space:]]*(#|//|/\*|\*)" | \
    grep -v "grep.*-rE" || true)

if [ -n "$NETWORK_HIJACK" ]; then
    echo -e "${RED}❌ CRITICAL: 发现网络劫持行为${NC}"
    echo "$NETWORK_HIJACK" | head -3
    ((CRITICAL++))
    WARNING_DETAILS+=("【严重】修改hosts文件或安装代理证书（中间人攻击）")
    RISK_LEVELS+=("CRITICAL")
else
    echo -e "${GREEN}✅ 通过${NC}"
fi
echo ""

# 13. 检查混淆和反检测
echo "🎭 检查代码混淆和反检测..."
OBFUSCATION=$(grep -hE "base64 -d.*bash|eval.*\$\(curl|eval.*\$\(wget|sleep [0-9]{4,}" ${SCAN_FILES[@]} 2>/dev/null | \
    grep -vE "^[[:space:]]*(#|//|/\*|\*)" | \
    grep -v "grep.*-rE" || true)

if [ -n "$OBFUSCATION" ]; then
    echo -e "${RED}❌ CRITICAL: 发现混淆或反检测代码${NC}"
    echo "$OBFUSCATION" | head -3
    ((CRITICAL++))
    WARNING_DETAILS+=("【严重】使用混淆技术或反检测（base64编码命令、长时间延迟等）")
    RISK_LEVELS+=("CRITICAL")
else
    echo -e "${GREEN}✅ 通过${NC}"
fi
echo ""

# 总结
echo "════════════════════════════════════════════════════════════"
echo "📊 审核总结"
echo "════════════════════════════════════════════════════════════"
echo ""

if [ $CRITICAL -gt 0 ]; then
    echo -e "${RED}🔴 风险等级: 严重（发现 $CRITICAL 个严重问题）${NC}"
    echo -e "${RED}   此skill可能对系统造成严重危害！${NC}"
elif [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}🟢 风险等级: 安全（无警告）${NC}"
elif [ $WARNINGS -le 2 ]; then
    # 检查风险等级分布
    HAS_HIGH=false
    HAS_MEDIUM=false
    ALL_LOW=true

    for level in "${RISK_LEVELS[@]}"; do
        if [ "$level" = "CRITICAL" ]; then
            # 不应该到这里，CRITICAL会在上面被捕获
            continue
        elif [ "$level" = "HIGH" ]; then
            HAS_HIGH=true
            ALL_LOW=false
        elif [ "$level" = "MEDIUM" ]; then
            HAS_MEDIUM=true
            ALL_LOW=false
        fi
    done

    if [ "$ALL_LOW" = true ]; then
        echo -e "${GREEN}🟢 风险等级: 低风险（${WARNINGS} 个低风险警告）${NC}"
    elif [ "$HAS_HIGH" = true ]; then
        echo -e "${YELLOW}🟠 风险等级: 高风险（${WARNINGS} 个警告，包含高风险项）${NC}"
    elif [ "$HAS_MEDIUM" = true ]; then
        echo -e "${YELLOW}🟡 风险等级: 中风险（${WARNINGS} 个警告）${NC}"
    else
        echo -e "${GREEN}🟢 风险等级: 低风险（${WARNINGS} 个低风险警告）${NC}"
    fi
else
    # 超过2个警告，检查是否有高风险
    HAS_HIGH=false
    for level in "${RISK_LEVELS[@]}"; do
        if [ "$level" = "HIGH" ]; then
            HAS_HIGH=true
            break
        fi
    done

    if [ "$HAS_HIGH" = true ]; then
        echo -e "${YELLOW}🟠 风险等级: 高风险（${WARNINGS} 个警告）${NC}"
    else
        echo -e "${YELLOW}🟡 风险等级: 中风险（${WARNINGS} 个警告）${NC}"
    fi
fi
echo ""

if [ ${#WARNING_DETAILS[@]} -gt 0 ]; then
    echo "⚠️  警告详情:"
    for i in "${!WARNING_DETAILS[@]}"; do
        num=$((i + 1))
        echo "  $num. ${WARNING_DETAILS[$i]}"
    done
    echo ""
fi

# 给出建议
echo "💡 安全建议:"
echo ""
if [ $CRITICAL -gt 0 ]; then
    echo -e "${RED}❌ 禁止安装${NC}"
    echo "   发现严重安全威胁，可能造成以下危害："
    echo "   • 窃取凭证和密钥（API token, SSH密钥等）"
    echo "   • 破坏系统文件或数据"
    echo "   • 建立持久化后门"
    echo "   • 劫持网络流量"
    echo ""
    echo "   强烈建议联系skill作者或安全团队审查。"
    exit 1
elif [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ 推荐安装${NC}"
    echo "   未发现安全问题，可以安全使用。"
elif [ $WARNINGS -le 2 ]; then
    # 检查风险等级
    HAS_HIGH=false
    HAS_MEDIUM=false
    for level in "${RISK_LEVELS[@]}"; do
        [ "$level" = "HIGH" ] && HAS_HIGH=true
        [ "$level" = "MEDIUM" ] && HAS_MEDIUM=true
    done

    if [ "$HAS_HIGH" = true ]; then
        echo -e "${YELLOW}⚠️  需要用户批准${NC}"
        echo "   发现高风险操作，需要你明确批准后才能安装："
        echo "   • 审查上述警告详情"
        echo "   • 确认这些操作是必要的"
        echo "   • 信任skill的来源和作者"
    elif [ "$HAS_MEDIUM" = true ]; then
        echo -e "${GREEN}✅ 可以安装（自动记录）${NC}"
        echo "   发现少量中风险警告，将自动安装并记录日志。"
        echo "   可以通过 'openclaw security audit-log' 查看详情。"
    else
        echo -e "${GREEN}✅ 推荐安装${NC}"
        echo "   仅有低风险警告（如读取环境变量），属于正常操作。"
    fi
else
    # 超过2个警告，检查风险分布
    HAS_HIGH=false
    HAS_MEDIUM=false
    for level in "${RISK_LEVELS[@]}"; do
        [ "$level" = "HIGH" ] && HAS_HIGH=true
        [ "$level" = "MEDIUM" ] && HAS_MEDIUM=true
    done

    if [ "$HAS_HIGH" = true ]; then
        echo -e "${YELLOW}⚠️  需要用户批准${NC}"
        echo "   发现多个高风险警告，强烈建议详细审查后再决定。"
    else
        echo -e "${GREEN}✅ 可以安装（自动记录）${NC}"
        echo "   发现多个中/低风险警告，将自动安装并记录日志。"
    fi
fi
echo ""

# 针对特定场景的额外说明
if echo "$EXTERNAL_URLS" | grep -q "wttr.in\|open-meteo"; then
    echo "ℹ️  关于天气服务:"
    echo "   • wttr.in 和 open-meteo 是常用的公开天气 API"
    echo "   • 虽然 wttr.in 使用 HTTP，但只查询公开天气数据，不涉及个人信息"
    echo "   • 如果只用于查询天气，可以放心安装"
    echo ""
fi

echo "════════════════════════════════════════════════════════════"

# 返回码
# 0 = 安全/低风险（直接安装）
# 1 = CRITICAL（禁止安装）
# 2 = HIGH风险（需要用户批准）
# 3 = MEDIUM风险（安装并记录）

if [ $CRITICAL -gt 0 ]; then
    exit 1  # 禁止安装
else
    # 检查是否有HIGH风险
    HAS_HIGH=false
    HAS_MEDIUM=false
    for level in "${RISK_LEVELS[@]}"; do
        [ "$level" = "HIGH" ] && HAS_HIGH=true
        [ "$level" = "MEDIUM" ] && HAS_MEDIUM=true
    done

    if [ "$HAS_HIGH" = true ]; then
        exit 2  # 需要用户批准
    elif [ "$HAS_MEDIUM" = true ]; then
        exit 3  # 自动安装但记录
    else
        exit 0  # 安全，直接安装
    fi
fi
