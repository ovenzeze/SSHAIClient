### **文档四：分阶段验收文档 (Phased Acceptance Document)**

**Document Title:** Phased Acceptance for AI-Enhanced iOS SSH Client
**Version:** 1.0
**Date:** 2025-09-03
**Author:** Gemini AI Assistant

---

#### Phase 1: 基础架构（周1-2）
- 交付: SSH 连接、SwiftTerm 集成、SQLite 初始化、主题框架、基础后端
- 验收: 成功连接并执行命令；历史记录写入；主题切换生效

#### Phase 2: 核心功能（周3-4）
- 交付: 意图路由(NL2CLI)、错误诊断修复、会话分段摘要、AI 建议卡、脚本执行
- 验收: 意图准确率≥90%；AI 命令可执行；常见错误能诊断；摘要导出 Markdown

#### Phase 3: 优化与测试（周5-6）
- 交付: 性能优化、异常恢复、iOS18特性、脚本库完善、设置同步、测试覆盖
- 验收: 启动≤2s；异常不崩溃；覆盖率≥80%；内存稳定

#### 发布准备
- App素材、描述、隐私条款、TestFlight、审核策略

#### 指标与回归
- 关键指标: 采纳率、修复率、分享查看率、复用率
- 回归用例: 连接异常、网络抖动、命令高危、脱敏校验
