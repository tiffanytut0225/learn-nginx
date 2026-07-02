# Project README Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Traditional Chinese root README that lets beginner and experienced Nginx learners understand, start, and navigate this five-day learning project.

**Architecture:** Keep the root README as the project entry point and link to detailed material under `days/` and `docs/`. Document only workflows and commands supported by existing repository content, while showing the incomplete status of Day 2–5 accurately.

**Tech Stack:** Markdown, Git, Docker, Nginx, curl, OpenSSL

---

### Task 1: Confirm documented usage

**Files:**
- Read: `days/day-1/labs/hour-*/**`
- Read: `days/day-1/day-1-assessment.md`
- Read: `docs/superpowers/plans/2026-07-01-nginx-intensive-learning-plan.md`

- [ ] **Step 1: Extract the actual Day 1 commands and ports**

Run:

```bash
rg -n 'docker|nginx -[tTs]|curl|openssl|127\.0\.0\.1|localhost|8080' days/day-1 docs/superpowers/plans/2026-07-01-nginx-intensive-learning-plan.md
```

Expected: command examples for environment checks, config validation, lab startup, HTTP requests, reloads, and cleanup.

- [ ] **Step 2: Confirm repository status**

Run:

```bash
find days -maxdepth 3 -type f | sort
```

Expected: Day 1 contains notes, labs, and assessment; Day 2–5 contain their README outlines only.

### Task 2: Create the project entry README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write the README**

Create `README.md` with these concrete sections:

```markdown
# Learn Nginx

五天、40 小時的 Nginx 密集學習專案，透過「先預測、再實驗、故意破壞、最後驗證」建立可用於實務攻錯的心智模型。

## 適合誰
## 教材進度
## 使用前準備
## 快速開始
## 建議學習方式
## 五日學習路線
## 專案結構
## 常用驗證指令
## 注意事項
```

The finished content must link to each daily README, the question list, the five-day plan, and the design document. It must state that Day 1 is complete while Day 2–5 are outlines, and must not invent setup automation.

- [ ] **Step 2: Review the rendered Markdown structure**

Run:

```bash
sed -n '1,280p' README.md
```

Expected: headings are ordered logically, code fences are closed, tables are readable, and a new reader can identify the first action without reading another file.

### Task 3: Verify README correctness

**Files:**
- Test: `README.md`

- [ ] **Step 1: Check formatting and placeholders**

Run:

```bash
git diff --check
rg -n 'TBD|TODO|PLACEHOLDER' README.md
```

Expected: `git diff --check` prints nothing; placeholder search returns no matches.

- [ ] **Step 2: Verify relative links**

Extract every local Markdown link from `README.md` and confirm its target exists in the repository.

Expected: every local link resolves to an existing file or directory.

- [ ] **Step 3: Review the final diff**

Run:

```bash
git diff -- README.md
git status --short
```

Expected: `README.md` is the only uncommitted content change; the approved design and implementation plan are tracked separately.
