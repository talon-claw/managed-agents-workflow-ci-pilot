# VPS 持续代理工作流可行性报告

## Executive summary

结论：可行，但不适合一次性全量落地。

更准确地说，这套“Codex 主执行 + Claude Code 守门 + 6 步工作流 + 脚本验收”的方案，在当前仓库/当前上下文下属于：
- 战略方向：可行
- 工程落地：可行
- 一次到位：不可取
- 推荐策略：分阶段试点，先单任务闭环，再扩展到 nightly / 自动 review / 多 worktree

我给的总体评级：
- 可行性：8/10
- 初期实施风险：中等
- 长期收益：高

---

## Assessment scope

本次评估基于以下事实：

1. 现有仓库是 Python 项目 `/root/.hermes/hermes-agent`
2. 仓库已有 `AGENTS.md`
3. 仓库已有 GitHub Actions 测试流水线 `.github/workflows/tests.yml`
4. 当前仓库中未发现以下目标骨架：
   - `CLAUDE.md`
   - `.claude/settings.json`
   - `scripts/verify.sh`
   - `scripts/acceptance.sh`
   - `scripts/review-check.sh`
   - `specs/tasks/`
   - `artifacts/reports/`
5. 你已说明：
   - Claude Code 已安装 ECC
   - Codex 已安装 superpowers

这意味着：代理能力层已有基础，但仓库内“规则层、脚本层、证据层、任务规格层”还没成型。

---

## Current-state findings

### Already in place

1. `AGENTS.md` 已存在
   - 说明当前仓库已经有较强的代理协作意识
   - 已定义开发环境、测试命令、项目结构、已知坑点
   - 这是迁移到更完整代理工作流的最大现成资产

2. CI 已存在
   - `.github/workflows/tests.yml` 已经把 main / PR 的测试跑起来了
   - 当前 CI 已区分常规 tests 和 e2e tests
   - 说明“统一裁判”的雏形已经有了，不是从零开始

3. 测试体系已存在
   - 仓库内已有大量 `tests/`
   - 说明“验证靠脚本和测试”是顺势而为，不是硬塞流程

### Missing pieces

1. 任务输入规范缺失
   - 当前没有 `specs/tasks/*.md`
   - 结果会是代理容易直接从口头需求跳到实现

2. 统一脚本入口缺失
   - 当前 CI 里有测试命令，但没有形成统一的：
     - `scripts/lint.sh`
     - `scripts/typecheck.sh`
     - `scripts/verify.sh`
     - `scripts/acceptance.sh`
   - 这会导致“完成标准”仍然分散在人的记忆和不同命令里

3. Claude 守门配置缺失
   - 未发现 `.claude/settings.json`
   - 说明 Claude Code hooks 还没有真正落到仓库级治理层

4. 证据层缺失
   - 未发现 `artifacts/reports/`
   - 当前更像“测试通过就算完”，而不是“有可复核证据才算完”

---

## Feasibility by layer

### 1. 主代理层（Codex 主执行）

可行。

原因：
- 你的目标是 VPS 上长期运行、持续做事、不断迭代
- Codex 更适合长会话、worktree、后台任务、持续实现
- superpowers 作为增强层，天然更适合推进执行而不是只做 gate

限制：
- Codex 必须绑定清晰的 repo rules 和 acceptance scripts，否则仍会“做了很多，但完成定义模糊”

结论：适合当主执行器。

### 2. 守门层（Claude Code + ECC）

可行，而且必要。

原因：
- 你的真正风险不在“写不出代码”，而在“代理越权、过早宣布完成、乱动环境”
- Claude hooks 可以把门禁做成确定性行为
- ECC 适合把规则、上下文、流程约束压到 Claude 侧

限制：
- 如果没有 `.claude/settings.json` 和明确 hook 设计，ECC 也只是“装了”，不是“生效”

结论：适合做 gatekeeper，不适合跟 Codex 平权抢主导。

### 3. 六步工作流本身

可行，但要精简成 MVP 再扩展。

最有价值的不是 6 步这个名字，而是其中三个关键约束：
- Search：先读 spec 再动手
- Reveal：必须交证据
- Verify：完成由 acceptance.sh 定义

潜在问题：
- 如果每一步都搞得很重，会拖慢日常任务
- 所以应该区分：
  - MVP 必须步
  - 高级自动化步

结论：可行，但需要分层，不要一上来全开。

### 4. CI / 验收层

高度可行。

原因：
- 当前仓库已有 `.github/workflows/tests.yml`
- 说明只需要把现有测试命令收束进统一脚本，而不是重做测试体系

建议：
- 不要先重写 CI
- 先把本地脚本写出来，再让 CI 调这些脚本

结论：这是最低风险、最高收益的一层，应优先落地。

---

## Main risks

### Risk 1: 把流程口号化

表现：
- 有 6 步名字
- 但没有每一步退出条件
- 代理还是会自说自话

应对：
- 每一步必须定义进入条件、输出、退出条件

### Risk 2: 把自动化上得太早

表现：
- 还没跑通一个试点任务，就上 nightly / systemd / 自动 PR

应对：
- 先做单任务闭环 MVP
- 再开 nightly 和后台守护

### Risk 3: 验收脚本变空壳

表现：
- `acceptance.sh` 只是调用几个宽松命令
- 通过不代表真的完成

应对：
- acceptance 必须包含：
  - verify
  - 必要 artifacts
  - 关键 smoke checks
  - 至少一条任务级验收项

### Risk 4: 权限边界不清

表现：
- 代理能直接动 root、动生产配置、动真实数据库

应对：
- 非 root
- feature branch/worktree
- staging 环境
- env 只读
- guard-command

---

## Requirements clarification

这套方案要落地，真正的硬性需求其实只有 7 条：

1. 任务必须先有规格文件
2. 代理只能在 feature branch/worktree 上工作
3. 必须有统一验证入口 `verify.sh`
4. 必须有统一验收入口 `acceptance.sh`
5. 必须有 artifacts 证据输出
6. 必须有 Claude command guard / hooks
7. CI 只认脚本和证据，不认代理主观总结

不是硬性第一优先级的内容：
- nightly maintenance
- systemd 守护
- fully automated publish
- 多代理并行大编排

这些应该放到 Phase 2/3，不该塞进 MVP。

---

## What should be simplified

原计划里最该精简的地方：

1. Publish 不要一开始自动化
   - MVP 阶段只做到“自动提 PR / 输出 merge-ready 结果”就够了
   - 不要先碰自动 merge / 自动 release

2. Reveal 不必一开始支持所有产物类型
   - MVP 先支持：
     - 文本报告
     - curl 样例
     - 测试输出摘要
   - 截图/视频以后再补

3. Execute 不必强行包含所有层级测试
   - 对不同任务允许不同测试矩阵
   - 例如文档改动不需要 e2e
   - 但 acceptance 应明确说明为什么跳过某些项

4. Search 不要变成长篇大论
   - Search 的最优产出是 task plan / checklist，不是第二份 PRD

---

## What should be added

原计划里建议补强的地方：

1. 任务分级
   - small / medium / high-risk
   - 决定需要哪些验证步骤和是否必须人工确认

2. 跳过策略
   - 哪些任务可以跳过 e2e
   - 哪些任务必须跑全量 acceptance

3. 失败回路
   - 失败后允许回到 Apply/Execute 的次数
   - 超过阈值后升级给 reviewer / human

4. 任务级 acceptance 模板
   - 不同任务都有自己的额外验收项，而不是只靠通用脚本

---

## Recommended phased rollout

### Phase 0 — 定义试点范围

只选一个低风险真实任务做试点。

目标：
- 验证流程，不是追求自动化炫技

### Phase 1 — MVP

只落地这些：
- `CLAUDE.md`
- `.claude/settings.json`
- `specs/tasks/task-template.md`
- `scripts/verify.sh`
- `scripts/acceptance.sh`
- `scripts/review-check.sh`
- `scripts/guard-command.sh`
- `artifacts/reports/`

### Phase 2 — 代理接入

- Codex 按 spec 执行单任务
- Claude hooks 接 gate
- CI 改为调用统一脚本

### Phase 3 — 扩展

- reviewer agent
- nightly maintenance
- 多 worktree 并行
- systemd / cron

---

## Final verdict

最终结论：

这份任务是可行的，而且值得做。
但它不是“先装几个 agent 增强包就自然成立”的事情。
真正的关键，不在 Codex / Claude / ECC / superpowers 本身，而在于你是否把：
- 任务规格
- 验收脚本
- 权限边界
- 证据输出
- CI gate
这五件事真正固化到仓库里。

一句话结论：

可行，建议做；但必须按“先 MVP 试点、再扩展自动化”的方式推进，不能一次性全量上车。