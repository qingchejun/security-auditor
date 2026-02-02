# Changelog

所有 notable 变更都会记录在这个文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
并且本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Added
- 新增危险管道执行检测（curl|bash / wget|sh）
- 新增一行执行检测（node -e / python -c / bash -c）
- 新增 package.json 安装脚本风险检测

### Changed
- 扫描仅限代码/配置文件，显著提升性能
- 增强注释过滤（# / // / /* */）降低误报
- 关键字检测加入词边界，减少误报
- 优化白名单：新增 @openclaw、undici、zod、tslib、zx、execa、playwright
- 集成 GitHub Actions CI / MIT 许可证 / 贡献指南 / 安装脚本

## [2.0.0] - 2026-02-02

### Added
- 智能审计模式（基于来源信任级别）
- 白名单系统（NPM 包可信来源）
- 审计日志系统（自动记录、多视图查看）
- 四种风险等级分类（CRITICAL/HIGH/MEDIUM/LOW）
- 19 项安全检查项
- 中文输出和文档

### Changed
- 优化审计逻辑，支持智能判断
- 改进输出格式，更清晰的报告

## [1.0.0] - 2026-02-01

### Added
- 初始版本
- 基础安全审计功能
- 支持检查危险命令、敏感文件访问等
