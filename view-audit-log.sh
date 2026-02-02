#!/bin/bash

# 审计日志查看脚本
# 查询和显示审计日志

set -uo pipefail

LOG_DIR="$HOME/.openclaw/security"
LOG_FILE="$LOG_DIR/audit-log.json"

# 颜色
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 检查日志文件是否存在
if [ ! -f "$LOG_FILE" ]; then
    echo -e "${YELLOW}📋 暂无审计日志${NC}"
    echo ""
    echo "安装skill后会自动记录审计信息"
    exit 0
fi

# 参数解析
MODE="${1:-summary}"  # summary, list, stats

case "$MODE" in
    "summary"|"")
        # 显示摘要
        echo "════════════════════════════════════════════════════════════"
        echo -e "${BLUE}📊 安全审计日志摘要${NC}"
        echo "════════════════════════════════════════════════════════════"
        echo ""

        node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('$LOG_FILE', 'utf8'));
const summary = data.summary;

console.log('总安装数：', summary.totalInstallations);
console.log('');
console.log('按风险等级分类：');
console.log('  🔴 CRITICAL（已阻止）：', summary.criticalBlocked);
console.log('  🟠 HIGH（需批准）：', summary.highAsked);
console.log('  🟡 MEDIUM（已记录）：', summary.mediumAutoInstalled);
console.log('  🟢 LOW（直接安装）：', summary.lowAutoInstalled);
console.log('');
console.log('最近安装：');
const recent = data.installations.slice(-5).reverse();
recent.forEach((entry, i) => {
    const date = new Date(entry.timestamp).toLocaleString('zh-CN');
    const riskColor = {
        'CRITICAL': '🔴',
        'HIGH': '🟠',
        'MEDIUM': '🟡',
        'LOW': '🟢'
    }[entry.riskLevel] || '⚪';
    console.log(\`  \${riskColor} \${entry.skillName} - \${entry.riskLevel} (\${date})\`);
});
" 2>/dev/null || echo "需要Node.js查看日志"
        ;;

    "list")
        # 显示详细列表
        echo "════════════════════════════════════════════════════════════"
        echo -e "${BLUE}📋 安全审计日志（详细）${NC}"
        echo "════════════════════════════════════════════════════════════"
        echo ""

        node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('$LOG_FILE', 'utf8'));

data.installations.forEach((entry, i) => {
    console.log(\`────────────────────────────────────────────────────────────\`);
    console.log(\`#\${i + 1} \${entry.skillName}\`);
    console.log(\`时间：\${new Date(entry.timestamp).toLocaleString('zh-CN')}\`);
    console.log(\`风险等级：\${entry.riskLevel}\`);
    console.log(\`来源类型：\${entry.sourceType}\`);
    console.log(\`路径：\${entry.skillPath}\`);
    if (entry.warnings && entry.warnings.length > 0) {
        console.log(\`警告：\`);
        entry.warnings.forEach(w => console.log(\`  • \${w}\`));
    }
    console.log('');
});
" 2>/dev/null || echo "需要Node.js查看日志"
        ;;

    "stats")
        # 显示统计图表
        echo "════════════════════════════════════════════════════════════"
        echo -e "${BLUE}📊 安全审计统计${NC}"
        echo "════════════════════════════════════════════════════════════"
        echo ""

        node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('$LOG_FILE', 'utf8'));

// 按来源类型统计
const bySource = {};
const byRisk = {};

data.installations.forEach(entry => {
    bySource[entry.sourceType] = (bySource[entry.sourceType] || 0) + 1;
    byRisk[entry.riskLevel] = (byRisk[entry.riskLevel] || 0) + 1;
});

console.log('📦 按来源类型：');
Object.entries(bySource).forEach(([type, count]) => {
    const bar = '█'.repeat(Math.min(count, 50));
    console.log(\`  \${type.padEnd(12)} [\${count.toString().padStart(3)}] \${bar}\`);
});

console.log('');
console.log('⚠️  按风险等级：');
Object.entries(byRisk).forEach(([level, count]) => {
    const bar = '█'.repeat(Math.min(count, 50));
    const icon = {'CRITICAL':'🔴','HIGH':'🟠','MEDIUM':'🟡','LOW':'🟢'}[level] || '⚪';
    console.log(\`  \${icon} \${level.padEnd(10)} [\${count.toString().padStart(3)}] \${bar}\`);
});
" 2>/dev/null || echo "需要Node.js查看统计"
        ;;

    "clean")
        # 清空日志
        read -p "确认清空所有审计日志？(y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
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
            echo -e "${GREEN}✓ 日志已清空${NC}"
        else
            echo "取消操作"
        fi
        ;;

    *)
        echo "用法: $0 [summary|list|stats|clean]"
        echo ""
        echo "  summary  - 显示摘要（默认）"
        echo "  list     - 显示详细列表"
        echo "  stats    - 显示统计图表"
        echo "  clean    - 清空日志"
        exit 1
        ;;
esac

echo ""
echo "════════════════════════════════════════════════════════════"
