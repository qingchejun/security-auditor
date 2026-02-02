# Security Auditor

## 用途

在涉及代码/脚本/项目安装时，自动执行安全检查。

## 触发场景

当用户执行以下操作时，**必须**先运行安全审计：
1. 安装任何 OpenClaw skill（`openclaw skills install`）
2. 运行第三方脚本（`bash install.sh`, `curl | bash` 等）
3. 安装 npm 包到系统目录
4. 执行来自 GitHub/ClawHub 的未知代码

## 使用流程

1. **识别安装意图**：当用户想安装或使用第三方代码时
2. **自动审计**：运行 `openclaw security audit-smart <path>` 或 `./audit.sh <path>`
3. **评估结果**：
   - 🟢 LOW（0）：直接安装
   - 🟡 MEDIUM（3）：自动安装 + 记录日志
   - 🟠 HIGH（2）：询问用户确认
   - 🔴 CRITICAL（1）：**拒绝安装**，告知用户风险
4. **记录日志**：所有审计结果记录到 `~/.openclaw/security/audit-log.json`

## 快速使用

```bash
# 智能审计（推荐）
openclaw security audit-smart <path>

# 完整审计
openclaw security audit <path>

# 检查来源
openclaw security check-source <path>

# 查看日志
openclaw security log
```

## 审计范围

- Shell 脚本（.sh, .bash, .zsh）
- Node.js 项目（package.json）
- Python 脚本
- 任何可执行代码

## 返回码

- `0` - 安全/低风险
- `1` - CRITICAL（禁止安装）
- `2` - HIGH（需用户批准）
- `3` - MEDIUM（自动安装+记录）

## 白名单

配置文件：`whitelist.json`

包含可信的 NPM 组织和包，这些来源会触发轻度审计。

## 日志

位置：`~/.openclaw/security/audit-log.json`

记录所有审计历史，支持摘要、列表、统计三种视图。

## 注意事项

- 此工具仅作为安全辅助，不保证 100% 安全
- 关键操作前仍需人工审查
- 定期更新白名单和黑名单
