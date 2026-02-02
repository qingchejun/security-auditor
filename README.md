# OpenClaw Security Auditor

<p align="center">
  🛡️ 智能代码安全审计工具 - 基于来源信任级别的自动化安全扫描器
</p>

<p align="center">
  <a href="https://github.com/qingchejun/security-auditor/actions"><img src="https://github.com/qingchejun/security-auditor/workflows/CI/badge.svg" alt="CI Status"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
  <a href="#"><img src="https://img.shields.io/badge/version-2.0.0-green.svg" alt="Version"></a>
  <a href="#"><img src="https://img.shields.io/badge/OpenClaw-Skill-orange.svg" alt="OpenClaw Skill"></a>
</p>

---

## 📋 目录

- [功能特性](#-功能特性)
- [安装](#-安装)
- [使用方法](#-使用方法)
- [审计项目](#-审计项目)
- [风险等级](#-风险等级)
- [智能审计流程](#-智能审计流程)
- [审计日志](#-审计日志)
- [白名单管理](#-白名单管理)
- [返回码](#-返回码)
- [开发计划](#-开发计划)
- [许可证](#-许可证)

---

## 🌟 功能特性

### 1. 来源信任级别识别

| 来源类型 | 处理方式 | 审计策略 |
|---------|---------|----------|
| ✅ 官方来源 | OpenClaw 官方仓库 | **跳过审计**，直接安装 |
| ✅ 白名单依赖 | 全部使用可信 NPM 包 | **轻度审计**（仅检查 CRITICAL）|
| ⚠️ 未知来源 | 包含未知依赖 | **完整审计**（30+ 检查项）|

### 2. 三种审计模式

- **`audit-smart`**：智能审计（推荐）- 先检查来源再决定策略
- **`audit`**：完整审计 - 不考虑来源，全面检测
- **`check-source`**：仅检查来源信任级别

### 3. 自动化日志记录

每次审计自动记录到 `~/.openclaw/security/audit-log.json`，支持摘要、详细列表、统计图表多种视图。

---

## 📦 安装

### 方式一：作为 OpenClaw Skill 安装（推荐）

```bash
# 克隆仓库
git clone https://github.com/qingchejun/security-auditor.git

# 复制到 OpenClaw skills 目录
cp -r security-auditor ~/.openclaw/skills/

# 验证安装
openclaw skills check
```

### 方式二：直接使用

```bash
# 克隆并直接使用
git clone https://github.com/qingchejun/security-auditor.git
cd security-auditor
./audit.sh <path-to-skill>
```

---

## 🚀 使用方法

### 智能审计（推荐）

```bash
# 先检查来源，再决定审计策略
openclaw security audit-smart <path>

# 示例
openclaw security audit-smart ~/Downloads/suspicious-project
openclaw security audit-smart ./install.sh
openclaw security audit-smart ~/.openclaw/skills/weather-skill
```

### 完整审计

```bash
# 不考虑来源，直接完整审计
openclaw security audit <path>

# 示例
openclaw security audit ~/github/some-repo
```

### 仅检查来源

```bash
# 只想知道来源是否可信
openclaw security check-source <path>
```

### 查看审计日志

```bash
# 查看摘要
openclaw security log

# 查看详细列表
openclaw security log-list

# 查看统计图表
openclaw security log-stats

# 清空日志
bash ~/.openclaw/skills/security-auditor/view-audit-log.sh clean
```

---

## 🔍 审计项目

### 🔴 CRITICAL（严重 - 禁止安装）

1. **危险文件系统操作**：`rm -rf`, `chmod 777`, 磁盘格式化等
2. **敏感文件泄露**：上传 `.env`, `.ssh`, `.aws`, `.npmrc` 等凭证文件
3. **OpenClaw 数据窃取**：访问 `~/.openclaw/` 配置和会话数据
4. **浏览器数据窃取**：访问浏览器 Cookies、密码数据
5. **命令历史泄露**：读取 `.bash_history`, `.zsh_history`
6. **macOS 钥匙串访问**：使用 `security` 命令访问钥匙串
7. **网络劫持**：修改 `/etc/hosts`, 安装代理证书
8. **代码混淆**：base64 编码命令、反检测等

### 🟠 HIGH（高风险 - 需要用户批准）

9. **危险命令执行**：`eval`, `exec`, `system()`
10. **持久化机制**：修改 `.bashrc`, 创建 `LaunchAgent`, `crontab` 等

### 🟡 MEDIUM（中风险 - 自动安装并记录）

11. **非 HTTPS 请求**（非白名单服务）
12. **依赖较多外部服务**（>5 个）
13. **代码中处理敏感数据**
14. **依赖较多第三方包**（>10 个）

### 🟢 LOW（低风险 - 直接安装）

15. **已知安全服务**：wttr.in 等公开 API
16. **少量外部依赖**
17. **子进程调用**：spawn, execFile
18. **读取环境变量**
19. **文档中的敏感词**

---

## 📊 风险等级

| 等级 | 颜色 | 说明 | 处理方式 |
|-----|------|------|----------|
| 🟢 安全 | 绿色 | 无警告或仅有低风险警告 | 直接安装 |
| 🟡 中风险 | 黄色 | 发现中风险警告 | 自动安装 + 记录日志 |
| 🟠 高风险 | 橙色 | 发现高风险警告 | 需要用户明确批准 |
| 🔴 严重 | 红色 | 发现严重安全威胁 | **禁止安装** |

---

## 🔄 智能审计流程

```
Step 1: 检查来源
  ├─ 官方仓库？ → ✅ 跳过审计，直接安装
  ├─ 全白名单依赖？ → 🔍 轻度审计（仅 CRITICAL）
  └─ 未知来源 → 🔍🔍 完整审计

Step 2: 风险评估
  ├─ CRITICAL → ❌ 禁止安装
  ├─ HIGH     → ⚠️ 需要用户批准
  ├─ MEDIUM   → 📝 自动安装 + 记录
  └─ LOW      → ✅ 直接安装
```

### 审计策略对比

| 来源类型 | 审计策略 | 检查项 | 安装速度 | 日志记录 |
|---------|---------|--------|---------|---------|
| 官方来源 | 跳过审计 | 无 | ⚡⚡⚡ 最快 | ✅ 记录 |
| 白名单依赖 | 轻度审计 | 仅 CRITICAL（10 项） | ⚡⚡ 快 | ✅ 记录 |
| 未知来源 | 完整审计 | 全部（30+ 项） | ⚡ 较慢 | ✅ 记录 |

---

## 📝 审计日志

### 日志位置

```
~/.openclaw/security/audit-log.json
```

### 日志格式

```json
{
  "timestamp": "2026-02-02T10:08:26Z",
  "skillName": "test-skill",
  "skillPath": "/path/to/skill",
  "riskLevel": "LOW",
  "trustLevel": "whitelist",
  "sourceType": "whitelist",
  "warnings": ["白名单依赖, 轻度审计通过"],
  "autoInstalled": true
}
```

### 日志功能

- ✅ **自动记录**：每次审计后自动记录结果
- ✅ **详细信息**：记录 skill 名称、路径、风险等级、警告详情
- ✅ **多种视图**：摘要、详细列表、统计图表
- ✅ **可追溯**：包含时间戳、来源类型、信任级别

### 定期审查建议

- 📅 每周查看一次审计日志
- ⚠️ 关注 MEDIUM 和 HIGH 风险的安装
- 🔍 定期检查是否有异常安装模式

---

## 📋 白名单管理

### NPM 包白名单

配置文件：`whitelist.json`

**可信组织（@scope）：**
- @types, @babel, @vue, @angular, @react
- @microsoft, @google-cloud, @aws-sdk
- @anthropic, @openai, @stripe, @vercel
- 等（共 14 个官方组织）

**可信基础包：**
- Web 框架：express, koa, fastify
- HTTP 客户端：axios, node-fetch, got
- 工具库：lodash, chalk, commander
- 日期处理：moment, dayjs, date-fns
- 等（共 60+ 个常用包）

**黑名单：**
- 已知恶意包：event-stream@3.3.6, flatmap-stream 等

### 更新策略

- 📅 每季度更新一次（3 个月）
- 🚨 发现安全事件时立即更新黑名单
- 📊 基于 NPM Registry 数据和社区反馈

---

## 🔢 返回码

| 返回码 | 含义 | 说明 |
|-------|------|------|
| `0` | 安全/低风险 | 直接安装 |
| `1` | CRITICAL | **禁止安装** |
| `2` | HIGH 风险 | 需要用户批准 |
| `3` | MEDIUM 风险 | 自动安装并记录 |

---

## 🗺️ 开发计划

- [ ] 集成到 OpenClaw 自动触发（pre-install hook）
- [ ] Web UI 查看审计报告
- [ ] 自动更新白名单数据库
- [ ] 支持更多语言（Python, Ruby, Go 等）
- [ ] VS Code 扩展
- [ ] 与 ClawHub 集成，显示安全评分

---

## 🤝 贡献

欢迎提交 Issue 和 PR！

1. Fork 本仓库
2. 创建你的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交你的修改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开一个 Pull Request

---

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE) 开源。

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/qingchejun">qingchejun</a>
</p>
