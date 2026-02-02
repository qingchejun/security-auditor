# 贡献指南

感谢你对 OpenClaw Security Auditor 的兴趣！我们欢迎各种形式的贡献。

## 如何贡献

### 报告问题

如果你发现了 bug 或有功能建议，请通过 [GitHub Issues](https://github.com/qingchejun/security-auditor/issues) 报告。

请包含以下信息：
- 问题描述
- 复现步骤
- 预期行为
- 实际行为
- 环境信息（操作系统、Shell 版本等）

### 提交代码

1. Fork 本仓库
2. 创建你的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交你的修改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开一个 Pull Request

### 代码规范

- 使用 [ShellCheck](https://www.shellcheck.net/) 检查脚本
- 遵循 [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- 所有脚本必须有可执行权限 (`chmod +x`)
- 添加适当的注释

### 审计规则贡献

如果你想添加新的安全检查项：

1. 在 `audit.sh` 中添加检查逻辑
2. 更新 README.md 中的审计项目列表
3. 添加测试用例
4. 说明该检查项的风险等级和理由

## 开发环境设置

```bash
# 克隆仓库
git clone https://github.com/qingchejun/security-auditor.git
cd security-auditor

# 安装 ShellCheck (macOS)
brew install shellcheck

# 运行测试
./test/run-tests.sh
```

## 联系我们

如有问题，欢迎通过 GitHub Issues 讨论。
