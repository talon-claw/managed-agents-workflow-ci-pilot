# VPS 持续工作直到验收工作流 — Specs

## 1. 目标

把当前仓库作为业务仓库，建立一套可在 VPS 上长期运行的工程代理骨架，满足以下目标：

- 任务必须先规格化，再执行
- OpenSpec 作为规范层，负责 change / proposal / tasks 的结构化管理
- 代理的完成声明必须由 repo 内脚本化验收定义
- Claude Code 负责守门与复核，Codex 负责主执行
- VPS 默认隔离方式为 `git worktree`
- MVP 先建设通用骨架，不直接上全量自动化
- 只有在 MVP 被真实测试成功之后，才进入自动化扩展阶段

## 2. 范围

### In scope（MVP）

本阶段只建设通用骨架，包含：

- Git 仓库初始化与默认基线约定
- OpenSpec CLI 安装与最小初始化
- `openspec/` 规范层目录
- `CLAUDE.md`
- `AGENTS.md`（如缺失则补齐，如已存在则收敛约束）
- `.claude/settings.json`
- `specs/design/` 设计文档目录
- `specs/tasks/task-template.md`
- `scripts/lint.sh`
- `scripts/typecheck.sh`
- `scripts/test-unit.sh`
- `scripts/test-integration.sh`
- `scripts/test-e2e.sh`
- `scripts/verify.sh`
- `scripts/acceptance.sh`
- `scripts/review-check.sh`
- `scripts/guard-command.sh`
- `artifacts/tasks/<task_id>/<run_id>/` 证据目录契约
- CI 调用统一脚本的接入点
- `docs/drafts/*.md` 到 OpenSpec 的迁移或冻结策略

### Out of scope（本阶段明确不做）

- 自动 merge
- 自动 release
- nightly maintenance
- systemd 守护化
- 自动任务拾取
- 多任务并行调度器
- 高风险任务自动 publish
- 数据库/生产配置/密钥类自动变更
- 一开始就启用 OpenSpec 的 Claude / Codex tool integration

## 3. 核心角色

- Human operator：定义任务、批准高风险动作、最终确认
- OpenSpec：规范层，维护 proposal / design / tasks 的结构化事实来源
- Codex：主执行代理，负责 Search / Apply / Execute / Reveal / Verify
- Claude Code：守门代理，负责 hooks、危险命令门禁、Stop/PR 复核
- CI：统一裁判，只认脚本与证据，不认代理自然语言总结

## 4. 功能需求

### FR-1 任务规格先行

任意实现任务开始前，必须同时满足：

- 已存在对应的 OpenSpec change
- 已存在 repo 内任务规格文件 `specs/tasks/<task>.md`

其中：

- OpenSpec change 负责变更意图、proposal、任务拆解与设计决策留痕
- `specs/tasks/<task>.md` 负责执行期字段、验证矩阵、证据要求与 worktree 绑定

任务规格最少必须包含：

- `task_id`
- `title`
- `status`
- `risk_level`
- `goal`
- `non_goals`
- `constraints`
- `dependencies`
- `files_or_areas_expected`
- `validation_matrix`
- `required_evidence`
- `publish_mode`
- `approved_design_refs`

### FR-2 OpenSpec bootstrap 不可跳过

在 `/ccg:spec-impl` 之前，仓库必须完成：

- Git 初始化
- Node.js 版本满足 OpenSpec CLI 要求
- OpenSpec CLI 已安装
- `openspec init --tools none --profile core` 已完成或等效最小初始化已完成
- 已明确 `docs/drafts/*.md` 的迁移或冻结策略，避免双重真相

### FR-3 Search 不可跳过

执行代理在改代码前必须：

- 读取 OpenSpec change
- 读取任务 spec
- 读取仓库规则文件
- 搜索相关代码、测试、脚本
- 形成最小计划

### FR-4 Apply 必须最小化

- 只允许在 task 对应的 `git worktree` 内工作
- 一个活跃任务只允许一个 worktree
- 优先最小 diff
- 同步补测试或更新测试夹具

### FR-5 Execute 必须真实执行

代理不得将“推测通过”当成完成。必须实际运行验证脚本。

最小验证矩阵入口：

- `scripts/lint.sh`
- `scripts/typecheck.sh`
- `scripts/test-unit.sh`
- `scripts/test-integration.sh`
- `scripts/test-e2e.sh`
- `scripts/verify.sh`

允许根据任务风险和类型跳过部分检查，但必须记录显式原因。

### FR-6 Reveal 必须留证据

每次运行都必须在 `artifacts/tasks/<task_id>/<run_id>/` 下产出：

- `search-plan.md`
- `verify.txt`
- `acceptance.txt`
- `review.txt`
- `manifest.json`

### FR-7 Verify 是唯一完成定义

只有同时满足以下条件，任务才允许宣称完成：

- `scripts/acceptance.sh` 返回 0
- 当前 run 的必要证据齐全
- `scripts/review-check.sh` 未拦截
- 证据绑定到当前 worktree 的 commit SHA

### FR-8 Publish 只做受控交付

MVP 中 publish 只表示：

- 生成 PR-ready 输出
- 附带风险摘要和证据路径
- 交给 CI / 人工 / reviewer 决定是否 merge

## 5. 非功能需求

### NFR-1 安全边界

- 默认使用 `git worktree` 隔离
- 代理以非 root 用户运行
- `.env` 不允许原地重写
- 高风险命令必须经过 `scripts/guard-command.sh`
- 涉及生产配置、密钥、部署、数据迁移的任务一律视为高风险

### NFR-2 可复核性

- 所有完成结论必须能被脚本和 artifacts 复核
- 禁止把旧 artifacts 误当成当前成功证据
- artifacts 必须按 `task_id/run_id` 命名空间隔离

### NFR-3 单一事实来源分层

- OpenSpec 是规范层事实来源，不直接定义完成状态
- repo 内 shell 脚本与 artifacts 是完成状态事实来源
- `docs/drafts/*.md` 在迁移完成后必须归档或冻结，只保留一个活跃规范入口

### NFR-4 可迁移性

- 即使代理工具不同，验收逻辑仍以 repo 内 shell 脚本为准
- hooks 是加速器，不是唯一 enforcement layer
- OpenSpec 初始接入使用 `--tools none`，避免修改现有代理提示体系

### NFR-5 渐进上线

- 第一阶段只落地骨架与 OpenSpec 最小接入
- 第二阶段先跑一个低风险真实任务
- 第三阶段才允许引入更强自动化

## 6. 风险分级规则

### Low-risk

示例：文档、小型测试补充、局部重构。

规则：允许进入 PR-ready，但仍需 verify、acceptance、artifacts。

### Medium-risk

示例：跨模块实现、验证逻辑修改、CI 变更。

规则：必须经过 Claude 守门 review；publish 后等待人工确认 merge。

### High-risk

示例：部署脚本、生产配置、密钥、数据库迁移、shell 启动文件。

规则：不得自动 publish；必须人工明确批准。

## 7. 跳过规则

- 跳过检查必须写入 `validation_matrix` 和 `acceptance.txt`
- 跳过原因必须是任务类型驱动，而不是执行失败后的临时借口
- 未显式声明跳过原因时，acceptance 必须失败

## 8. 失败升级规则

- 同一 `task_id` 的每次重试必须生成新的 `run_id`
- 连续失败超过阈值后，任务必须升级给 human operator 或 Claude 守门层
- 缺少证据视为失败，不是 warning

## 9. PBT / 不变量

### P1 Artifact completeness
- **Invariant**：任何 `success` 任务都必须存在 `artifacts/tasks/<task_id>/<run_id>/acceptance.txt`
- **Falsification**：构造成功状态但删除 acceptance 证据，系统必须判失败

### P2 Verify gates publish
- **Invariant**：`verify` 失败时，`publish` 必须被禁止
- **Falsification**：模拟 verify 非零退出码，publish 仍可继续则违反约束

### P3 Worktree isolation
- **Invariant**：任务 worktree 内的改动不得直接污染主工作目录
- **Falsification**：在错误目录执行任务并观察主分支状态被污染

### P4 Explicit high-risk approval
- **Invariant**：高风险命令必须留下 guard 记录并要求人工确认
- **Falsification**：执行高风险命令却无 guard log 或无审批拦截

### P5 No stale artifacts reuse
- **Invariant**：旧 run 的 artifacts 不能满足当前 run 的 acceptance
- **Falsification**：复用历史 artifacts 仍通过 acceptance

### P6 Skip transparency
- **Invariant**：任何被跳过的检查都必须在 acceptance 输出中出现显式原因
- **Falsification**：存在 skipped check 但 acceptance 输出没有说明

### P7 OpenSpec bootstrap before implementation
- **Invariant**：进入实现前，仓库必须已完成 OpenSpec 最小初始化
- **Falsification**：没有 `openspec/` 结构仍允许开始实现，则违反约束

### P8 Single active spec source
- **Invariant**：同一 change 不能同时让 `docs/drafts` 与 `openspec` 作为活跃规范真相来源
- **Falsification**：迁移后两个位置都继续被更新，且内容不一致

## 10. 验收标准

本次 plan 对应的 MVP 在开始实施后，必须以以下成功判据验收：

1. 仓库已完成 Git 初始化，并可执行 `git worktree`
2. OpenSpec CLI 已安装，且仓库已完成最小初始化
3. 可以创建并读取 OpenSpec change 与 `specs/tasks/<task>.md`
4. 可以在 git worktree 中执行一个低风险试点任务
5. `guard-command.sh` 至少能拦截一种危险命令
6. `acceptance.sh` 会在缺少证据或检查失败时 fail closed
7. `artifacts/tasks/<task_id>/<run_id>/` 中有机器可复核证据
8. CI 与本地运行相同脚本并得出一致结论

