# VPS 持续工作直到验收工作流 — Tasks

> Freeze status (2026-04-17): this checklist is frozen as a bootstrap execution record. Active change and task tracking must move to `openspec/changes/*` and `specs/tasks/*`.

## Phase 0 — OpenSpec Bootstrap Preconditions

- [x] 0.1 确认当前仓库已初始化为 Git 仓库，并可执行 `git worktree`
- [x] 0.2 确认默认基线分支名称，并写入设计约定
- [x] 0.3 确认本地环境 Node.js 版本满足 OpenSpec CLI 要求
- [x] 0.4 安装 OpenSpec CLI
- [x] 0.5 以 `openspec init --tools none --profile core` 完成最小初始化
- [x] 0.6 明确 `docs/drafts/*.md` 的迁移或冻结策略，避免双重真相
- [x] 0.7 确认本地与 CI 都能调用 repo 内 shell 脚本

## Phase 1 — Skeleton

- [ ] 1.1 建立 `openspec/changes/` 与 `openspec/specs/` 基础结构
- [ ] 1.2 建立 `specs/design/` 目录和首批设计文档骨架
- [ ] 1.3 建立 `specs/tasks/task-template.md`，包含 task metadata、validation matrix、required evidence、change_id 绑定
- [ ] 1.4 收敛或补齐 `AGENTS.md`，明确主执行代理职责和完成定义
- [ ] 1.5 建立 `CLAUDE.md`，明确守门职责、安全边界和证据要求
- [ ] 1.6 建立 `.claude/settings.json`，只放 MVP 所需 hooks 和 command guard
- [ ] 1.7 建立 `scripts/lint.sh`
- [ ] 1.8 建立 `scripts/typecheck.sh`
- [ ] 1.9 建立 `scripts/test-unit.sh`
- [ ] 1.10 建立 `scripts/test-integration.sh`
- [ ] 1.11 建立 `scripts/test-e2e.sh`
- [ ] 1.12 建立 `scripts/verify.sh`，聚合验证矩阵并显式处理 skip
- [ ] 1.13 建立 `scripts/acceptance.sh`，对缺失证据和失败检查 fail closed
- [ ] 1.14 建立 `scripts/review-check.sh`，输出统一 review 结论
- [ ] 1.15 建立 `scripts/guard-command.sh`，先覆盖最小高风险命令集合
- [ ] 1.16 建立 `scripts/worktree-preflight.sh`，校验 worktree、base ref、cleanliness、task ownership
- [ ] 1.17 建立 `artifacts/tasks/<task_id>/<run_id>/` 的 manifest 与报告契约
- [ ] 1.18 定义 OpenSpec change 与 `specs/tasks/<task-id>.md` 的映射规则
- [ ] 1.19 让 CI 改为调用 repo 内统一脚本入口，而不是分散命令

## Phase 2 — Manual Pilot

- [ ] 2.1 选择一个低风险但真实的试点任务
- [ ] 2.2 为试点任务创建 OpenSpec change（proposal/design/tasks）
- [ ] 2.3 为试点任务创建 `specs/tasks/<task-id>.md`
- [ ] 2.4 在独立 git worktree 中执行试点任务
- [ ] 2.5 生成 `search-plan.md`
- [ ] 2.6 跑完 verify 并落地 `verify.txt`
- [ ] 2.7 跑完 acceptance 并落地 `acceptance.txt`
- [ ] 2.8 跑完 review-check 并落地 `review.txt`
- [ ] 2.9 生成 `manifest.json`，绑定 `task_id/change_id/run_id/head_sha`
- [ ] 2.10 验证本地与 CI 对该试点任务给出一致结论

## Phase 3 — Hardening

- [ ] 3.1 收紧 skip 规则，禁止未声明 skip 原因的 acceptance 通过
- [ ] 3.2 增加失败升级阈值与流程
- [ ] 3.3 增加任务依赖与文件区域重叠规则
- [ ] 3.4 收窄 hooks，避免误拦截低风险开发流程
- [ ] 3.5 补强 artifact 清理/归档策略，避免旧证据污染
- [ ] 3.6 冻结或归档 `docs/drafts/`，确保 OpenSpec 成为唯一活跃规范入口

## Phase 4 — Controlled Automation

- [ ] 4.1 在 MVP 试点成功后，再启用更强的 CI 自动化
- [ ] 4.2 在 MVP 试点成功后，再增加 hooks 自动触发能力
- [ ] 4.3 在 MVP 试点成功后，再增加 PR-ready 自动生成
- [ ] 4.4 在 MVP 试点成功后，再评估 OpenSpec tool integration、nightly、reviewer、多 worktree 并发

## Exit Criteria

- [ ] E1 Git 与 OpenSpec 最小骨架全部落地
- [ ] E2 `acceptance.sh` 能对缺失 artifact fail closed
- [ ] E3 `guard-command.sh` 至少能拦截一种高风险命令
- [ ] E4 低风险试点任务在 git worktree 中闭环成功
- [ ] E5 本地与 CI 结论一致
- [ ] E6 `docs/drafts/` 不再与 `openspec/` 并行充当活跃规范真相来源
- [ ] E7 只有在 E1-E6 满足后，才允许进入全量自动化阶段
