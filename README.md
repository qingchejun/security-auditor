# Security Auditor v2.0

🛡️ **OpenClaw 安全审计工具** - 基于来源信任级别的智能代码安全扫描器

审计任何代码、脚本、项目的安全性，自动识别可信来源并智能调整审计策略。

## 📋 用途

这是一个**通用的代码安全审计工具**，可以审计：
- ✅ OpenClaw skills/plugins
- ✅ GitHub 开源项目
- ✅ npm 包和依赖
- ✅ Shell 脚本（.sh, .bash, .zsh）
- ✅ 下载的第三方代码
- ✅ AI 生成的代码
- ✅ 任何需要运行的代码

**在运行任何第三方代码前，先用它审计，保护你的系统安全。**

## 🌟 核心特性

### 1. 来源信任级别识别
- ✅ **官方来源**：OpenClaw官方仓库 → 跳过审计
- ✅ **白名单依赖**：全部使用可信NPM包 → 仅检查CRITICAL
- ⚠️ **未知来源**：包含未知依赖 → 完整安全审计

### 2. 三种审计模式
- `audit-smart`：智能审计（推荐）- 先检查来源再决定策略
- `audit`：完整审计 - 不考虑来源，全面检测
- `check-source`：仅检查来源信任级别

## 检查项目

### 🔴 CRITICAL（严重 - 禁止安装）
1. **危险文件系统操作**：`rm -rf`, `chmod 777`, 磁盘格式化等
2. **敏感文件泄露**：上传 `.env`, `.ssh`, `.aws`, `.npmrc` 等凭证文件
3. **OpenClaw数据窃取**：访问 `~/.openclaw/` 配置和会话数据
4. **浏览器数据窃取**：访问浏览器 Cookies、密码数据
5. **命令历史泄露**：读取 `.bash_history`, `.zsh_history`
6. **macOS钥匙串访问**：使用 `security` 命令访问钥匙串
7. **网络劫持**：修改 `/etc/hosts`, 安装代理证书
8. **代码混淆**：base64编码命令、反检测等

### 🟠 HIGH（高风险 - 需要用户批准）
9. **危险命令执行**：`eval`, `exec`, `system()`
10. **持久化机制**：修改 `.bashrc`, 创建 `LaunchAgent`, `crontab` 等

### 🟡 MEDIUM（中风险 - 自动安装并记录）
11. **非HTTPS请求**（非白名单服务）
12. **依赖较多外部服务**（>5个）
13. **代码中处理敏感数据**
14. **依赖较多第三方包**（>10个）

### 🟢 LOW（低风险 - 直接安装）
15. **已知安全服务**：wttr.in 等公开API
16. **少量外部依赖**
17. **子进程调用**：spawn, execFile
18. **读取环境变量**
19. **文档中的敏感词**

## 使用方法

### 智能审计（推荐）
```bash
# 先检查来源，再决定审计策略
openclaw security-audit-smart <path>

# 示例
openclaw security-audit-smart ~/Downloads/suspicious-project
openclaw security-audit-smart ./install.sh
openclaw security-audit-smart ~/.openclaw/skills/weather-skill
```

### 完整审计
```bash
# 不考虑来源，直接完整审计
openclaw security-audit <path>

# 示例
openclaw security-audit ~/github/some-repo
```

### 仅检查来源
```bash
# 只想知道来源是否可信
openclaw security-check-source <path>
```

### 查看审计日志
```bash
# 查看摘要
openclaw security-log

# 查看详细列表
openclaw security-log-list

# 查看统计图表
openclaw security-log-stats

# 清空日志
bash ~/.openclaw/skills/security-auditor/view-audit-log.sh clean
```

## 返回码说明
- `0` = 安全/低风险（直接安装）
- `1` = CRITICAL（禁止安装）
- `2` = HIGH风险（需要用户批准）
- `3` = MEDIUM风险（安装并记录）

## 📋 白名单管理

### NPM包白名单
配置文件：`whitelist.json`

**可信组织（@scope）：**
- @types, @babel, @vue, @angular, @react
- @microsoft, @google-cloud, @aws-sdk
- @anthropic, @openai, @stripe, @vercel
- 等（共14个官方组织）

**可信基础包：**
- Web框架：express, koa, fastify
- HTTP客户端：axios, node-fetch, got
- 工具库：lodash, chalk, commander
- 日期处理：moment, dayjs, date-fns
- 等（共60+个常用包）

**黑名单：**
- 已知恶意包：event-stream@3.3.6, flatmap-stream等

### 更新策略
- 📅 每季度更新一次（3个月）
- 🚨 发现安全事件时立即更新黑名单
- 📊 基于NPM Registry数据和社区反馈

## 🔄 智能审计流程
```
Step 1: 检查来源
  ├─ 官方仓库？ → ✅ 跳过审计，直接安装
  ├─ 全白名单依赖？ → 🔍 轻度审计（仅CRITICAL）
  └─ 未知来源 → 🔍🔍 完整审计

Step 2: 风险评估
  ├─ CRITICAL → ❌ 禁止安装
  ├─ HIGH     → ⚠️ 需要用户批准
  ├─ MEDIUM   → 📝 自动安装+记录
  └─ LOW      → ✅ 直接安装
```

## 📊 审计策略对比

| 来源类型 | 审计策略 | 检查项 | 安装速度 | 日志记录 |
|---------|---------|--------|---------|---------|
| 官方来源 | 跳过审计 | 无 | ⚡⚡⚡ 最快 | ✅ 记录 |
| 白名单依赖 | 轻度审计 | 仅CRITICAL（10项） | ⚡⚡ 快 | ✅ 记录 |
| 未知来源 | 完整审计 | 全部（30+项） | ⚡ 较慢 | ✅ 记录 |

## 📝 审计日志系统

### 功能特性
- ✅ **自动记录**：每次审计后自动记录结果
- ✅ **详细信息**：记录skill名称、路径、风险等级、警告详情
- ✅ **多种视图**：摘要、详细列表、统计图表
- ✅ **可追溯**：包含时间戳、来源类型、信任级别

### 日志存储
- **位置**：`~/.openclaw/security/audit-log.json`
- **格式**：JSON格式，易于查询和分析
- **内容**：
  ```json
  {
    "timestamp": "2026-02-02T10:08:26Z",
    "skillName": "test-skill",
    "skillPath": "/path/to/skill",
    "riskLevel": "LOW",
    "trustLevel": "whitelist",
    "sourceType": "whitelist",
    "warnings": ["白名单依赖,轻度审计通过"],
    "autoInstalled": true
  }
  ```

### 日志查看

**摘要视图：**
```bash
openclaw skill-log
```
显示总安装数、按风险分类统计、最近5次安装

**详细列表：**
```bash
openclaw skill-log-list
```
显示每次安装的完整信息和警告详情

**统计图表：**
```bash
openclaw skill-log-stats
```
按来源类型和风险等级的柱状图统计

### 定期审查建议
- 📅 每周查看一次审计日志
- ⚠️ 关注MEDIUM和HIGH风险的安装
- 🔍 定期检查是否有异常安装模式
