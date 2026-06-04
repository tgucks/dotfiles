---
name: explain-this
description: Explain the diff of the current branch against the repo's default remote branch (origin/main or origin/master). Use whenever the user wants to understand a code change - "explain this", "explain this branch", "what does this change do", "walk me through this diff", "explain my PR", "why was this change made". Covers what the change does, how it does it, why it made certain decisions, and the broader codebase/business reason it was needed. If not in a git repo, say so and stop.
argument-hint: [base-branch] [-- path...]
allowed-tools: [Bash, Read, Grep, Glob]
---

# Explain This Change

Explain the change that the current branch introduces relative to the repository's default remote branch. Produce an explanation that answers four questions: **what** the change does, **how** it does it, **why** it chose its approach over alternatives, and **why** it was needed in the first place (the codebase and business context).

## Step 0: Confirm this is a git repository

Run:

```bash
git rev-parse --is-inside-work-tree 2>/dev/null
```

If this fails or does not print `true`, tell the user plainly that the current directory is not a git repository and stop. Do not run anything else. There is nothing to explain without a repo.

## Step 1: Determine the base branch

The base is the repository's default remote branch. Resolve it in this order and use the first that works:

1. **Explicit override** — if the user passed a base branch in `$ARGUMENTS` (the first token before any `--`), use that.
2. **Remote's configured default** — the most reliable signal:
   ```bash
   git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/@@'
   ```
   This prints e.g. `origin/master` or `origin/main`. If `origin/HEAD` is not set, set and retry once with `git remote set-head origin --auto` (it queries the remote), then re-run the command above.
3. **Probe the common names** — if the above is still empty, check which exists:
   ```bash
   git rev-parse --verify --quiet origin/main >/dev/null && echo origin/main
   git rev-parse --verify --quiet origin/master >/dev/null && echo origin/master
   ```
   Prefer `origin/main`, then `origin/master`.
4. **No `origin` remote** — if there is no `origin`, look for any remote's default, or fall back to a local `main`/`master`. Tell the user which base you settled on and why, since it is a guess.

If you cannot find any plausible base branch, say so and ask the user which branch to compare against rather than inventing one.

Confirm the resolved base out loud (one line) before continuing, e.g. "Comparing `feature/x` against `origin/master`."

## Step 2: Gather the change

Use the merge-base (three-dot) form so you see only what this branch introduced, not changes that landed on the base after you branched off. Let `BASE` be the branch from Step 1.

```bash
git diff --stat BASE...HEAD                 # files touched + churn overview
git log --oneline --no-merges BASE..HEAD    # commits on this branch (note: two dots)
git diff BASE...HEAD                         # the actual change
```

Notes:
- If the user passed paths after `--` in `$ARGUMENTS`, append `-- <paths>` to the diff commands to scope the explanation.
- If the diff is large, read it in sections rather than truncating. Use `--stat` to prioritize the files that carry the substance of the change over noise (lockfiles, generated output, formatting-only churn).
- Also capture uncommitted work if it is relevant: `git status --short`. Mention it separately if the working tree has changes not yet committed, since those are part of "this change" even though they are not in the commit log.

## Step 3: Gather context for the "why"

The "what" and "how" come from the diff. The "why" needs grounding so the explanation is accurate rather than imagined. Pull from these sources, in rough order of authority:

- **Commit messages** (`git log BASE..HEAD`, full bodies via `git log BASE..HEAD --format=%B`) — the author's own stated intent. This is your strongest evidence for the why.
- **Branch name** — often encodes a ticket ID, fix, or feature (`fix/...`, `feat/...`, `JIRA-123-...`).
- **Linked issues / PRs** — if a commit or branch references an issue number, and a tool is available to read it (e.g. `gh issue view`, `gh pr view`, an Atlassian/Jira MCP), use it. Do not fabricate issue content you cannot read.
- **Surrounding code** — read the files the diff touches, not just the diff hunks, so you understand what the changed code interacts with and why the new approach fits (or breaks from) existing patterns.
- **Project docs** — `README`, `CLAUDE.md`, `CONTRIBUTING`, architecture notes — to ground claims about the codebase's conventions and the change's place in it.

## Step 4: Write the explanation

Structure the output with these sections. Adapt depth to the size of the change - a one-line fix does not need five paragraphs, and a large refactor should not be flattened into one.

```
## Summary
One or two sentences: what this branch changes, at a glance.

## What it does
The observable behavior change. What is different after this change that was not before - new capabilities, fixed behavior, removed functionality.

## How it works
The mechanism. Walk through the key files and the flow of the change. Reference specific code as `path:line`. Explain the non-obvious parts; do not narrate every trivial line.

## Key decisions and tradeoffs
Where the change picked one approach over a plausible alternative, name the choice and the reasoning. If the reasoning is evident from the code or commits, state it. If it is your inference, mark it as such ("Likely because...").

## Why it was needed
The broader reason. What problem this solves, what it fixes or unblocks, and how it fits the codebase and its purpose. Ground this in commit messages, issues, and surrounding code.
```

## Grounding rules

The value of this skill is an explanation the user can trust. To keep it accurate:

- **Separate evidence from inference.** State what the diff and commits directly show as fact. Mark interpretation ("this appears to...", "likely intended to...") so the user knows which is which.
- **Do not invent business context.** If there is no issue, no descriptive commit, and no clue in the code about *why* a change was made, say the rationale is not documented rather than manufacturing one. A grounded "the why isn't recorded here" is more useful than a confident guess.
- **Read before you explain.** Open the changed files for surrounding context. A diff hunk in isolation often misleads.
- **Prefer the built-in.** When the change uses a third-party library or framework, check whether it is using a built-in feature correctly before describing it as custom logic.
