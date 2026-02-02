#!/bin/bash

# 审计日志记录脚本
# 记录skill安装的安全审计信息

set -uo pipefail

# 参数
SKILL_NAME="${1:-unknown}"
SKILL_PATH="${2:-.}"
RISK_LEVEL="${3:-UNKNOWN}"
WARNINGS="${4:-}"
TRUST_LEVEL="${5:-unknown}"

# 日志目录
LOG_DIR="$HOME/.openclaw/security"
LOG_FILE="$LOG_DIR/audit-log.json"

# 确保日志目录存在
mkdir -p "$LOG_DIR"

# 如果日志文件不存在，创建初始结构
if [ ! -f "$LOG_FILE" ]; then
    cat > "$LOG_FILE" <<'EOF'
{
  "version": "1.0.0",
  "installations": [],
  "summary": {
    "totalInstallations": 0,
    "criticalBlocked": 0,
    "highAsked": 0,
    "mediumAutoInstalled": 0,
    "lowAutoInstalled": 0
  }
}
EOF
fi

# 生成日志条目
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SOURCE_TYPE="unknown"

# 判断来源类型
case "$TRUST_LEVEL" in
    "official")
        SOURCE_TYPE="official"
        ;;
    "whitelist")
        SOURCE_TYPE="whitelist"
        ;;
    *)
        SOURCE_TYPE="community"
        ;;
esac

# 创建临时文件
TEMP_ENTRY=$(mktemp)
cat > "$TEMP_ENTRY" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "skillName": "$SKILL_NAME",
  "skillPath": "$SKILL_PATH",
  "riskLevel": "$RISK_LEVEL",
  "trustLevel": "$TRUST_LEVEL",
  "sourceType": "$SOURCE_TYPE",
  "warnings": $(echo "$WARNINGS" | sed 's/"/\\"/g' | awk '{printf "["; for(i=1;i<=NF;i++) printf "\"%s\"%s", $i, (i<NF?",":""); printf "]"}'),
  "autoInstalled": true,
  "userNotified": false
}
EOF

# 使用Node.js更新JSON（因为bash处理JSON很麻烦）
node -e "
const fs = require('fs');
const logFile = '$LOG_FILE';
const newEntry = $(cat $TEMP_ENTRY);

let data = JSON.parse(fs.readFileSync(logFile, 'utf8'));
data.installations.push(newEntry);
data.summary.totalInstallations++;

// 更新汇总统计
switch('$RISK_LEVEL') {
    case 'CRITICAL':
        data.summary.criticalBlocked++;
        break;
    case 'HIGH':
        data.summary.highAsked++;
        break;
    case 'MEDIUM':
        data.summary.mediumAutoInstalled++;
        break;
    case 'LOW':
        data.summary.lowAutoInstalled++;
        break;
}

fs.writeFileSync(logFile, JSON.stringify(data, null, 2));
console.log('✓ 审计日志已记录: $SKILL_NAME ($RISK_LEVEL)');
" 2>/dev/null || echo "⚠️ 日志记录失败（需要Node.js）"

# 清理临时文件
rm -f "$TEMP_ENTRY"

exit 0
