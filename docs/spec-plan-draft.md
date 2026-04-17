# VPS 持续代理工作流 Spec Plan（精简版）

## Goal

为 VPS 上的长期工程代理建立一套最小但严格的闭环：
- 任务先规格化
- 代理按规则执行
- 所有完成声明必须经过统一验收脚本
- 中高风险操作必须被 Claude 守门层拦住或升级确认

本 Spec Plan 不是最终自动化蓝图，而是“第一版可落地规格”。

---

## Problem statement

当前问题不是“没有代理”，而是“代理缺少统一完成定义和受控执行边界”。

如果直接让代理长期在 VPS 上做事，常见失败模式是：
- 没有 spec 就开工
- 代码改了但证据不完整
- 测试零散，缺统一入口
- 代理过早宣布完成
- 高风险命令没有被 deterministic gate 拦住

因此，需要把代理工作流程产品化，而不是靠人每次临场指挥。

---

## Scope

### In scope (MVP)

1. 六步工作流的 MVP 版本：
   - search
   - apply
   - execute
   - reveal
   - verify
   - publish

2. 仓库骨架新增：
   - `CLAUDE.md`
   - `.claude/settings.json`
   - `specs/tasks/task-template.md`
   - `scripts/verify.sh`
   - `scripts/acceptance.sh`
   - `scripts/review-check.sh`
   - `scripts/guard-command.sh`
   - `artifacts/reports/`

3. 角色定义：
   - Codex = 主执行代理
   - Claude Code = 守门/复核代理

4. 统一完成定义：
   - `scripts/acceptance.sh == 0`

### Out of scope (Phase 2/3)

- 自动 merge / 自动 release
- nightly maintenance
- systemd 守护化
- 多任务并行大规模编排
- 视频级 artifacts
- 全自动 reviewer orchestration

---

## Stakeholders

- Human operator（你）
- Codex 主执行代理
- Claude Code 守门代理
- CI 系统（最终统一裁判）

---

## Functional requirements

### FR-1 任务规格先行

每个实现任务开始前，必须存在：
- `specs/tasks/<task>.md`

最少包含：
- Goal
- Non-goals
- Acceptance criteria
- Constraints
- Evidence required

### FR-2 Search 阶段不可跳过

代理开始实现前，必须先：
- 读 spec
- 读仓库规则文件
- 搜索相关代码/测试/脚本
- 形成简短 plan/checklist

退出条件：
- 已明确本任务会改哪些文件、跑哪些验证、产出哪些证据

### FR-3 Apply 必须最小化

代理实现阶段必须：
- 只在 feature branch / worktree 上工作
- 尽量保持最小 diff
- 同步补测试

禁止：
- 越权改生产配置
- 直接改 secrets
- 直接改生产数据库

### FR-4 Execute 必须真实执行

代理不得把“推测通过”当成完成。
必须实际运行相关脚本。

最小脚本矩阵：
- `scripts/verify.sh`
- 需要时任务级 smoke checks

### FR-5 Reveal 必须产证据

每个任务至少生成：
- 一个文本报告文件到 `artifacts/reports/`

最小内容：
- 改动摘要
- 运行过的命令/脚本摘要
- 结果摘要
- 路径引用

### FR-6 Verify 是唯一完成定义

任务只有在以下条件成立时才允许声明完成：
- `scripts/acceptance.sh` 返回 0
- 必要 artifacts 存在
- review-check 未拦截

### FR-7 Publish 只做受控交付

MVP 阶段 publish 的定义仅限于：
- 生成 PR-ready 输出
- 附带风险摘要和证据路径
- 交给 CI / human / reviewer 决定是否 merge

---

## Non-functional requirements

### NFR-1 安全边界

- 非 root 用户运行代理
- 代理只拥有项目目录权限
- `.env` 不允许原地重写
- 命令必须经过 `guard-command.sh`

### NFR-2 可复核性

- 所有完成结论必须可由脚本和 artifacts 复核
- 不依赖代理的自然语言自证

### NFR-3 渐进采用

- 不要求第一版覆盖所有任务类型
- 必须允许先在一个低风险试点任务中验证闭环

### NFR-4 与现有仓库兼容

- 尽量复用现有 AGENTS.md 和 CI
- 不强迫仓库一次性重构目录结构

---

## Refined six-step workflow

### 1. Search
输入：spec + 规则 + 代码上下文
输出：小计划 / checklist
完成条件：范围、改动点、验证点明确

### 2. Apply
输入：计划
输出：最小代码改动 + 测试改动
完成条件：改动已落地，无明显越界

### 3. Execute
输入：改动后的分支
输出：脚本运行结果
完成条件：实际执行所需验证，不靠推断

### 4. Reveal
输入：执行结果
输出：`artifacts/reports/*.txt`
完成条件：外部 reviewer 能复核结果

### 5. Verify
输入：代码 + artifacts
输出：acceptance 结论
完成条件：`acceptance.sh == 0`

### 6. Publish
输入：通过验收的结果
输出：PR-ready 交付物
完成条件：附证据、附摘要、进入 CI/review

---

## Simplifications from the original plan

这版规格相较原计划做了 4 个精简：

1. 先不把 nightly / automation 放进 MVP
2. 先不要求所有任务都跑全量 e2e
3. publish 先定义为“交付到 PR / review 阶段”，不等于自动 merge
4. reveal 先只要求文本证据，不强制截图/视频

---

## Additions missing from the original plan

这版规格补了 4 个必要项：

1. 任务分级
   - low-risk
   - medium-risk
   - high-risk

2. 跳过规则
   - 某些测试为何可跳过，必须写明

3. 失败升级规则
   - 连续失败超过阈值要升级给人/守门代理

4. MVP / Phase 2 边界
   - 防止第一次实施就过度设计

---

## Risk classification for workflow decisions

### Low-risk task
示例：
- 文档
- 小型测试补充
- 局部重构

策略：
- 可按规则自动推进到 PR-ready

### Medium-risk task
示例：
- 跨模块实现
- 改验证逻辑
- 改 CI 脚本

策略：
- 必须经过 Claude 守门 review
- Publish 后等人工确认 merge

### High-risk task
示例：
- 环境变量策略
- 数据迁移
- 部署脚本
- shell 启动文件
- 生产配置

策略：
- 必须人工明确确认
- 不进入自动 publish

---

## Acceptance criteria for this spec itself

当开始实施本 spec 时，下面这些条件同时满足，才算第一阶段成功：

1. 能创建一个任务 spec 并让代理读取它
2. Codex 能在独立 worktree 完成一个低风险试点任务
3. Claude hook 能拦截至少一种危险命令
4. Claude Stop 或等价 gate 能触发 acceptance
5. `artifacts/reports/` 中有至少一份机器可复核报告
6. CI 能调用统一脚本并给出一致结论

---

## Implementation plan (trimmed)

### Phase 1 — Define
- 建任务模板
- 建统一脚本入口
- 建 Claude guard/hook 骨架
- 建 artifacts 目录

### Phase 2 — Pilot
- 选一个低风险真实任务
- 跑完整六步闭环
- 修补脚本和规则缺口

### Phase 3 — Expand
- 接入更多任务类型
- 接入 PR review
- 再上 nightly / automation

---

## Final recommendation

这份需求应当被确认，但计划要收窄为：

“先让一个低风险真实任务，按照六步工作流在 VPS 上闭环成功，并由 acceptance.sh 定义完成。”

这才是第一阶段真正该追求的目标。
不是先追求全自动，不是先追求多代理编排，而是先追求：
- 边界清楚
- 验收真实
- 证据完整
- 一次闭环跑通。