---
name: add-instruction
description: Add a new instruction to a CLAUDE.md file. Use when the user wants to add a rule, guideline, or preference to their Claude configuration. Accepts the scope (user/repo/project) and the instruction text.
argument-hint: <user|repo|project> <instruction text>
allowed-tools: [Read, Edit, Bash]
---

# Add Instruction to CLAUDE.md

Add a new instruction to the appropriate CLAUDE.md file based on the requested scope.

## Arguments

Parse the arguments from: $ARGUMENTS

The first argument is the scope. Everything after is the instruction to add.

If the scope argument is missing or not one of `user`, `repo`, or `project`, ask the user which scope to use:

- **user** — `~/.claude/CLAUDE.md`: personal preferences that apply to all projects
- **repo** — `CLAUDE.md` at the repo root: committed guidelines shared with the team
- **project** — `.claude/CLAUDE.md` at the repo root: local project instructions, not committed

If the instruction text is missing, ask the user what instruction they want to add.

## Procedure

1. Determine the target file path based on scope:
   - `user` → `~/.claude/CLAUDE.md`
   - `repo` → `<repo-root>/CLAUDE.md`
   - `project` → `<repo-root>/.claude/CLAUDE.md`

2. Read the target file to understand its current structure and sections.

3. Decide which existing section the instruction best fits under. If none fit, create a new section with a short descriptive heading.

4. Write a succinct, actionable instruction — one bullet point, imperative voice. Condense the user's wording if needed while preserving intent.

5. Edit the file to add the instruction in the chosen section.

6. **Chezmoi check**: If the target file is managed by chezmoi (i.e., a corresponding source file exists in the chezmoi source directory), edit the chezmoi source file instead, then run `chezmoi apply` to propagate the change. Use `chezmoi source-path <target>` to check.
