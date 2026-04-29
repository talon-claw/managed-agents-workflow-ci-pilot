# VPS 持续工作直到验收工作流 — Design

> Freeze status (2026-04-17): this draft is frozen as the Phase 0 bootstrap design record. New design work must move to `openspec/changes/*`.

## 1. 设计目标

把当前仓库设计成一个“轻量控制平面”，并在其上叠加 OpenSpec 规范层：

- OpenSpec change / proposal / tasks 是规范层输入源
- repo 内 `specs/tasks/*.md` 是执行层任务规格输入源
- 代理是执行者，不是完成定义的来源
- shell 脚本是统一 gate
- artifacts 是统一证据层
- git worktree 是默认隔离层

本设计刻意把自动化延后，先保证：

- 结构清晰
- 失败可诊断
- 证据可追溯
- 本地与 CI 一致
- 规范层与验收层职责分离

## 2. 目录设计

```text
AGENTS.md
CLAUDE.md
.claude/
  settings.json
openspec/
  config.yaml
  changes/
    <change-id>/
      proposal.md
      design.md
      tasks.md
  specs/
scripts/
  lint.sh
  typecheck.sh
  test-unit.sh
  test-integration.sh
  test-e2e.sh
  verify.sh
  acceptance.sh
  review-check.sh
  guard-command.sh
  worktree-preflight.sh
specs/
  design/
    workflow.md
    risk-policy.md
    artifact-contract.md
  tasks/
    task-template.md
    <task-id>.md
artifacts/
  tasks/
    <task_id>/
      <run_id>/
        search-plan.md
        verify.txt
        acceptance.txt
        review.txt
        manifest.json
docs/
  drafts/
    specs.md
    design.md
    tasks.md
.github/
  workflows/
    ci.yml
```

约定：

- `openspec/` 是规范层，承载 change proposal、设计、任务拆解
- `specs/tasks/` 是执行层，承载执行时所需字段、验证矩阵、证据要求
- `docs/drafts/` 只在迁移期间保留；一旦 OpenSpec 接管后，应归档或冻结

## 3. 数据模型

### 3.1 OpenSpec change

每个变更至少包含：

- `change_id`
- `proposal.md`
- `design.md`
- `tasks.md`
- 与 repo 内 `task_id` 的映射关系

约束：

- 一个活跃 change 可以映射一个或多个 `task_id`
- 一个 `task_id` 只能隶属一个活跃 change
- change 负责表达 why / what / scope，不负责表达完成结论

### 3.2 Task spec

每个任务文件为执行层单一事实来源。建议字段：

- `task_id`
- `change_id`
- `title`
- `status`: `draft | approved | in_progress | verified | published`
- `risk_level`: `low | medium | high`
- `goal`
- `non_goals`
- `constraints`
- `dependencies`
- `files_or_areas_expected`
- `validation_matrix`
- `required_evidence`
- `publish_mode`
- `approved_design_refs`
- `base_branch`
- `worktree_path`

### 3.3 Run artifact manifest

`manifest.json` 至少应记录：

- `task_id`
- `change_id`
- `run_id`
- `timestamp`
- `base_branch`
- `branch`
- `worktree_path`
- `head_sha`
- `executed_checks`
- `skipped_checks`
- `artifact_files`
- `result`

## 4. 生命周期设计

### Phase 0 — Bootstrap OpenSpec

先补运行前置：

- 初始化 Git 仓库，并确认 `git worktree` 可用
- 确认默认基线分支为 `main`
- 确认 Node.js 版本满足 OpenSpec CLI 要求；当前基线固定为 `.nvmrc` 中的 `v22.22.0`
- 确认 OpenSpec CLI 已安装；当前验证版本为 `1.3.0`
- 执行 `openspec init --tools none --profile core`，并保留 `openspec/changes/archive/` 与 `openspec/specs/` 作为最小初始化结构
- 冻结 `docs/drafts/` 为 bootstrap 历史输入，后续活跃规范入口切换到 `openspec/changes/*` 与 `specs/tasks/*`
- 提供一个最小 CI 工作流，仅验证仓库内 shell 入口可被 CI 调用

### Phase 1 — Skeleton

只交付骨架：

- OpenSpec 最小目录
- 模板
- 脚本入口
- 目录契约
- 风险分级
- artifact contract

### Phase 2 — Manual pilot

在一个低风险真实任务中跑完整闭环：

1. 建 OpenSpec change
2. 写 task spec
3. 建 worktree
4. Search
5. Apply
6. Execute
7. Reveal
8. Verify
9. 产出 PR-ready 结果

### Phase 3 — Hardening

基于试点暴露的问题收紧：

- skip 规则
- failure escalation
- overlap/dependency 约束
- hook 精度
- OpenSpec 与 repo task spec 的映射纪律

### Phase 4 — Controlled automation

仅在前述阶段稳定后加入：

- CI 全接入
- hooks 自动触发
- worktree helper
- reviewer 流程
- 之后才考虑 nightly 与更多自动化

## 5. 六步工作流设计

### 5.1 Search

输入：OpenSpec change + task spec + repo rules + code context
输出：`search-plan.md`

要求：
- 明确将修改的文件/区域
- 明确将执行的验证矩阵
- 明确将生成的证据
- 明确 change_id 与 task_id 的绑定

### 5.2 Apply

输入：search 计划
输出：最小代码改动

要求：
- 只在 task worktree 内操作
- 不允许越权改 secrets / 生产配置 / 生产 DB
- 失败后返回 Search 或继续在当前 run 中修复

### 5.3 Execute

输入：代码改动
输出：脚本运行结果

策略：
- 所有检查通过统一脚本入口
- 允许按任务类型裁剪验证矩阵
- 跳过必须显式记录
- OpenSpec 不替代执行脚本

### 5.4 Reveal

输入：执行结果
输出：artifact 契约中的文本证据和 manifest

### 5.5 Verify

输入：代码 + artifacts
输出：统一 acceptance 结论

规则：
- fail closed
- 缺少 artifact 直接失败
- 旧 run 的 artifact 不能复用
- 规范层文档通过不等于实现完成

### 5.6 Publish

输入：通过 verify 的结果
输出：PR-ready 交付物

MVP 约束：
- 不自动 merge
- 不自动 release
- 高风险任务不自动 publish

## 6. 决策表

| 决策项 | 选择 | 原因 |
|---|---|---|
| 当前仓库定位 | 业务仓库 | 用户已明确确认 |
| MVP 策略 | 先做通用骨架 + OpenSpec 最小接入 | 先把规范层与执行层边界立起来 |
| 规范层 | OpenSpec | 用结构化变更管理取代散落草稿 |
| OpenSpec 初始化 | `--tools none --profile core` | 避免污染现有代理提示与工具集成 |
| 隔离方式 | git worktree | 简单、可追踪、与 repo 工作流契合 |
| 完成定义 | acceptance.sh = 0 | 统一、可机器判定 |
| 证据模型 | task_id/run_id 命名空间 | 防止旧证据误判 |
| 自动化时机 | MVP 验证成功后 | 避免过早自动化 |

## 7. 风险与缓解

### R1 当前仓库不是 git repo
- **影响**：无法执行 worktree 策略，也无法稳定接入 OpenSpec 变更流
- **缓解**：实施前先初始化 Git，并明确默认基线分支

### R2 当前环境没有 OpenSpec CLI
- **影响**：无法落地规范层目录与 change 工作流
- **缓解**：先校验 Node.js 版本，再安装 CLI，并用最小 profile 初始化

### R3 `docs/drafts` 与 `openspec` 双重真相
- **影响**：规范来源冲突，后续实现依据不稳定
- **缓解**：迁移完成后冻结或归档 `docs/drafts`，只保留一个活跃入口

### R4 tool integration 副作用
- **影响**：OpenSpec 若直接写入 Claude/Codex 集成，可能污染现有 orchestration 规则
- **缓解**：MVP 阶段只用 `--tools none`，后续再评估集成

### R5 脚本空壳化
- **影响**：流程形式化但不可靠
- **缓解**：脚本对缺失检查、缺失证据、未声明 skip 一律 fail closed

### R6 artifact 污染
- **影响**：历史成功掩盖当前失败
- **缓解**：强制 `task_id/run_id/head_sha` 绑定

### R7 hooks 过宽
- **影响**：误伤正常开发流程
- **缓解**：重检查留给 acceptance，hooks 只做窄门禁

### R8 试点任务过于简单
- **影响**：错误高估体系成熟度
- **缓解**：MVP 通过后必须至少挑一个低风险但真实改码任务验证

## 8. 实施前置条件

在 `/ccg:spec-impl` 开始前，必须满足：

- 仓库已是 Git 仓库
- 可以使用 `git worktree`
- Node.js 版本满足 OpenSpec CLI 要求
- OpenSpec CLI 已安装
- `openspec/` 最小目录已初始化
- 文档骨架目录存在
- 本地 shell 环境可执行脚本
- CI 有能力调用 repo 内脚本

## 9. PBT 设计映射

| Property | 定义 | 边界条件 | 反例生成 |
|---|---|---|---|
| Artifact completeness | success 必有 acceptance artifact | 缺少文件、空文件、错路径 | 删除 acceptance.txt 或写到错误 run_id |
| Verify gates publish | verify fail 时 publish 禁止 | verify 非零、check skipped | 伪造 publish 流程忽略 verify 退出码 |
| Worktree isolation | 工作目录改动只存在于 task worktree | 错 worktree、错分支 | 在主目录直接修改并尝试通过验证 |
| Approval gate | 高风险命令必须有审批记录 | guard 失效、规则遗漏 | 执行高风险命令且无 log |
| Stale artifact rejection | 当前 run 不能复用旧 run 证据 | 同 task 不同 run | 复制旧 artifact 到新 run |
| Skip transparency | 所有 skip 都有显式原因 | 空原因、隐式跳过 | 在 verify 中跳过 e2e 但 acceptance 无说明 |
| OpenSpec bootstrap first | 实现前必须完成 OpenSpec 最小初始化 | 无 openspec、CLI 缺失 | 跳过 init 仍允许进入实现 |
| Single spec source | 活跃规范来源只能有一个 | drafts 与 openspec 同时可写 | 两处分别修改产生冲突 |
