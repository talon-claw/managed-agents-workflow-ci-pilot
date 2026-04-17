# VPS 持续工作直到验收工作流计划

> For Hermes: 这是规划稿，不执行仓库改动。目标是把你给出的 VPS 长跑代理方案，收束成一套可落地的 6 步工作流：search / apply / execute / reveal / verify / publish。

## Goal

在 VPS 上建立一套长期可运行的工程代理工作流：
- Codex 作为主执行代理
- Claude Code 作为门禁/审查代理
- ECC（已安装于 Claude Code）作为规则与上下文增强层
- superpowers（已安装于 Codex）作为执行增强层
- 任何任务都必须以脚本化验收为完成定义，而不是代理自我宣布完成

## Current context / assumptions

- 用户已经给 Claude Code 安装 ECC。
- 用户已经给 Codex 安装 superpowers。
- 目标环境是 VPS，强调长时间运行、持续修复、持续验证、最终可验收。
- 当前需要的是“计划”，不是立即落地执行。
- 当前仓库是 `/root/.hermes/hermes-agent`，但这份计划刻意设计为“项目无关骨架”，可迁移到你的业务仓库。

## Recommendation summary

采用“双代理 + 单一验收定义”架构：

1. Codex = 主执行器
   - 负责实现、修复、补测试、循环跑验证
   - 利用 worktree / background task / 长会话优势

2. Claude Code = 守门员
   - 负责 hooks、危险命令门禁、PR review、停止前验收
   - 利用 ECC 把项目级规则、记忆、约束层钉死

3. 验收脚本 = 唯一完成标准
   - `scripts/verify.sh`
   - `scripts/acceptance.sh`
   - CI 只认脚本退出码和产物，不认代理主观表述

## 六步工作流定义

### Step 1 — Search

**目的：** 先收集任务上下文，禁止代理直接跳到实现。

**输入：**
- `specs/tasks/<task>.md`
- `AGENTS.md`
- `CLAUDE.md`
- 相关代码、测试、历史 artifacts

**代理行为：**
- 读取任务规格
- 读取仓库规则
- 搜索相关实现、测试、接口、脚本
- 输出最小计划，不改代码

**完成标准：**
- 明确 goal / non-goals / constraints / acceptance criteria
- 明确会改哪些文件、跑哪些脚本、产生哪些证据

**建议约束：**
- 如果没有 `specs/tasks/*.md`，先补任务规格，不允许直接开工
- Search 结果必须落成简短计划或 TODO，不允许直接“边做边想”

---

### Step 2 — Apply

**目的：** 基于 Search 结果做最小必要改动。

**输入：**
- Search 阶段形成的计划
- 相关文件定位结果

**代理行为：**
- 在 feature branch / worktree 中改代码
- 优先最小 diff
- 同步补测试或更新测试夹具
- 不允许绕过既有脚本体系

**完成标准：**
- 改动集中、最小化
- 有配套测试更新
- 无越界改动（如 infra/production、密钥、生产库）

**角色分工：**
- Codex 主做 Apply
- Claude hooks 对危险命令、越权改动、敏感文件访问做拦截

---

### Step 3 — Execute

**目的：** 真正跑起来，而不是停留在静态代码层。

**输入：**
- 改动后的分支/worktree
- 开发或 staging 环境

**代理行为：**
- 跑 `scripts/lint.sh`
- 跑 `scripts/typecheck.sh`
- 跑 `scripts/test-unit.sh`
- 跑 `scripts/test-integration.sh`
- 跑 `scripts/test-e2e.sh`
- 必要时启动本地服务或 staging 服务做 smoke test

**完成标准：**
- 所有需要的脚本都实际执行过
- 失败时返回 Apply，不允许“推测已修复”

**VPS 运行建议：**
- 用 tmux 常驻实现会话
- 每个任务独立 worktree
- staging 数据库/服务与生产隔离

---

### Step 4 — Reveal

**目的：** 让代理交付“证据”，不是只说结果。

**输入：**
- Execute 阶段的测试输出、日志、截图、报告

**代理行为：**
- 把关键输出写入 `artifacts/reports/`
- UI 变更时输出截图到 `artifacts/screenshots/`
- 必要时输出 curl / API 响应样例
- 总结：改了什么、为什么改、证据在哪

**完成标准：**
- 至少有一个机器可复核的报告文件
- 用户或 reviewer 不用重新猜代理做了什么

**建议命名：**
- `artifacts/reports/<task>-verify.txt`
- `artifacts/reports/<task>-acceptance.txt`
- `artifacts/reports/<task>-review.txt`

---

### Step 5 — Verify

**目的：** 用统一脚本做最终技术验收。

**输入：**
- 全部代码改动
- Reveal 阶段产物

**代理行为：**
- 运行 `scripts/verify.sh`
- 运行 `scripts/acceptance.sh`
- 运行 `scripts/review-check.sh`
- Claude Code 在 Stop hook 或 PR 阶段二次审查

**完成标准：**
- `acceptance.sh` 退出码为 0
- 所有必须产物存在
- 没有被 review gate 拦下

**关键原则：**
- Verify 是“唯一完成定义”
- 任何一步失败都回到 Apply/Execute

---

### Step 6 — Publish

**目的：** 把通过验收的结果，以受控方式送进主线。

**输入：**
- 通过 Verify 的分支或 worktree
- PR / CI 结果

**代理行为：**
- 生成 PR 描述
- 附上验收证据路径
- 触发 CI
- Claude 做 PR review
- 通过后再 merge / release

**完成标准：**
- CI 绿
- PR 有证据、有风险摘要、有变更摘要
- 只有通过 gate 的内容才进入主干

**发布策略：**
- 低风险维护任务：可自动提 PR
- 中风险任务：自动提 PR + 等人工确认 merge
- 高风险任务：必须人工审批后再合并或发布

## 推荐落地架构

### A. 仓库文件骨架

```text
AGENTS.md
CLAUDE.md
.claude/settings.json
scripts/
  setup.sh
  lint.sh
  typecheck.sh
  test-unit.sh
  test-integration.sh
  test-e2e.sh
  verify.sh
  acceptance.sh
  review-check.sh
  guard-command.sh
specs/tasks/
artifacts/reports/
artifacts/screenshots/
.github/workflows/
```

### B. 代理职责

#### Codex + superpowers
- 主循环：Search → Apply → Execute → Reveal → Verify
- 长时间 worktree 任务
- nightly maintenance
- regression 回归

#### Claude Code + ECC
- PreToolUse：危险命令门禁
- PostToolUse：改文件后自动 lint/format
- Stop：停止前强制 acceptance
- PR review / issue triage / 守门报告

## 最小可用版本（MVP）

### Phase 1 — 骨架先行
1. 建 `AGENTS.md`
2. 建 `CLAUDE.md`
3. 建 `scripts/verify.sh`
4. 建 `scripts/acceptance.sh`
5. 建 `scripts/review-check.sh`
6. 建 `specs/tasks/task-template.md`
7. 建 `.claude/settings.json` hooks 骨架

### Phase 2 — 代理接入
1. Codex 改为只在 feature branch/worktree 执行
2. Claude hooks 接管危险命令和停止前验收
3. 把 ECC 规则融合到 `CLAUDE.md`/`.claude/settings.json`
4. 把 superpowers 的常用能力映射到 `AGENTS.md` 的执行要求

### Phase 3 — 自动化
1. 上 CI：`ci.yml`
2. 上 nightly regression：`nightly-maintenance.yml`
3. 上 reviewer 流程：Claude review + acceptance evidence
4. 再考虑 systemd / cron 化

## Risks / tradeoffs

1. **脚本空壳风险**
   如果 `verify.sh` / `acceptance.sh` 只是空跑，整个体系会沦为形式主义。

2. **代理权限过大**
   如果不做 worktree、非 root、只读 env、staging 隔离，长期跑一定翻车。

3. **双代理角色重叠**
   Codex 和 Claude 都能写代码，但这里故意不让他们平权；一个负责推进，一个负责守门。

4. **过早自动化**
   先把单任务闭环跑通，再上 nightly automation，否则只是把混乱自动化。

## Suggested file responsibilities

- `AGENTS.md`：Codex 主流程、完成定义、禁止事项
- `CLAUDE.md`：Claude 项目规则、审查和证据要求
- `.claude/settings.json`：hooks、命令门禁、停止前验收
- `scripts/verify.sh`：统一验证入口
- `scripts/acceptance.sh`：统一验收入口
- `scripts/guard-command.sh`：危险命令拦截
- `specs/tasks/*.md`：任务输入规范
- `artifacts/reports/*`：证据层

## Validation plan

当开始真正实施时，按下面顺序验证：

1. 写一个最小试点任务到 `specs/tasks/`
2. 让 Codex 在独立 worktree 执行一次完整循环
3. 确认 Claude hooks 会在写文件后自动触发 lint
4. 确认 Claude Stop hook 会在结束前跑 acceptance
5. 确认 artifacts/reports/ 中留下可复核证据
6. 确认 CI 与本地 acceptance 结果一致

## Recommended next action

下一步不要直接全面上线，先做一个“试点仓库版本”的模板包，至少包括：
- `AGENTS.md`
- `CLAUDE.md`
- `.claude/settings.json`
- `scripts/verify.sh`
- `scripts/acceptance.sh`
- `scripts/review-check.sh`
- `scripts/guard-command.sh`
- `.github/workflows/ci.yml`
- `specs/task-template.md`

然后用一个真实但低风险任务跑完整 6 步，确认闭环成立，再扩展到 nightly / multi-worktree / auto-review。
