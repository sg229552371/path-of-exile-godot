---
description: 生成提交（验证 → 暂存 → 提交）
argument-hint: [可选：提交信息草稿]
---
为当前改动创建一个提交。

流程：
1. 并行运行 `git status`、`git diff`（含 staged）、`git log`（最近若干条）了解全部改动与提交风格。
2. 对照原则 3（外科手术式改动）：确认每处改动都对应本次任务；无关改动分离出去，不混入本次提交。
3. 若 $ARGUMENTS 为空，按改动性质起草简洁信息（**why 优先于 what**，1–2 句）；否则以 $ARGUMENTS 为基础润色。
4. 暂存**明确相关**的文件（按名指定，避免 `git add -A`/`git add .` 误纳敏感文件如 `.env`、密钥）。
5. 用 HEREDOC 提交。不跳过 hook（`--no-verify`）；不 amend 既有提交。
6. 提交后 `git status` 确认。

禁止：force push、`--no-verify`、提交 `.env`/凭据/密钥、向 main/master 强推。
