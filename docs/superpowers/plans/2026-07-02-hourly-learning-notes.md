# Hourly Learning Notes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep Day 2 learning notes synchronized after every completed Hour.

**Architecture:** Use one chronological `days/day-2/notes.md` file as the learning record and link it from the Day 2 README. Each completed Hour appends a concise section containing principles, observed mistakes, corrected mental models, and completion status.

**Tech Stack:** Markdown, Git

---

### Task 1: Create the Day 2 learning record

**Files:**
- Create: `days/day-2/notes.md`
- Modify: `days/day-2/README.md`

- [x] **Step 1: Add the completed Hour 1 notes**

Create `days/day-2/notes.md` with the Location Selection algorithm, Prefix boundary behavior, URI normalization, Named Location behavior, observed prediction corrections, and `Hour 1 狀態：**完成**。`

- [x] **Step 2: Link the notes from the Day 2 entry page**

Add the following section after the title in `days/day-2/README.md`:

```markdown
## 今日教材

- [學習筆記](notes.md)
```

- [x] **Step 3: Verify document structure and whitespace**

Run:

```bash
rg -n "Hour 1|Location Selection|完成" days/day-2/notes.md
git diff --check
```

Expected: the Hour 1 headings and completion marker are found, and `git diff --check` prints no errors.

- [x] **Step 4: Commit the Hour 1 notes**

```bash
git add days/day-2/README.md days/day-2/notes.md
git commit -m "docs: record day 2 hour 1 learning"
```

### Task 2: Update notes after subsequent Hours

**Files:**
- Modify: `days/day-2/notes.md`

- [x] **Step 1: Append the completed Hour section**

After the Hour passes its planned validation, append a section containing its learning objective, core principles, actual mistakes or experimental evidence, corrected reusable mental model, and explicit completion marker.

- [x] **Step 2: Verify the new completion marker**

Run:

```bash
rg -n "Hour [2-8].*完成|Hour [2-8] 狀態" days/day-2/notes.md
git diff --check
```

Expected: the newly completed Hour is listed and `git diff --check` prints no errors.

- [x] **Step 3: Commit the completed Hour**

```bash
git add days/day-2/notes.md
git commit -m "docs: record completed day 2 learning hour"
```
