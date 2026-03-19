---
name: scan-secrets
description: Scan the current repository for secrets, credentials, API keys, tokens, and sensitive data in both tracked files and git history. This skill should be used when the user asks to "scan for secrets", "check for credentials", "audit for sensitive data", or before pushing code to a remote.
argument-hint: [--history] [path...]
allowed-tools: [Read, Glob, Grep, Bash]
---

# Secret Scanner

Scan the current repository for secrets, credentials, API keys, tokens, private keys, and any other personal or sensitive data that should not be committed or pushed.

## Arguments

Parse the arguments from: $ARGUMENTS

- `--history`: Also scan git history (slower, uses `git log -p`)
- `path...`: Optional paths to limit the scan scope. Defaults to the entire repo.

## Scan Procedure

### Step 1: Identify Scope

Determine the repository root with `git rev-parse --show-toplevel`. If not a git repo, use the current working directory.

If the user provided specific paths, limit scanning to those paths. Otherwise scan the full repo.

### Step 2: File-Based Scan

Search tracked files for high-confidence secret patterns. Use Grep with these patterns:

1. **AWS keys**: `AKIA[0-9A-Z]{16}`
2. **Generic API keys/tokens**: `(?i)(api[_-]?key|api[_-]?secret|access[_-]?token|auth[_-]?token|secret[_-]?key)\s*[:=]\s*['"]?[A-Za-z0-9/+=]{16,}`
3. **Private keys**: `-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----`
4. **Connection strings**: `(?i)(postgres|mysql|mongodb|redis|amqp)://[^\s'"]+@[^\s'"]+`
5. **Password assignments**: `(?i)(password|passwd|pwd)\s*[:=]\s*['"][^'"]{8,}['"]`
6. **Bearer tokens**: `(?i)bearer\s+[A-Za-z0-9\-._~+/]+=*`
7. **GitHub/GitLab tokens**: `(ghp_|gho_|ghu_|ghs_|ghr_|glpat-)[A-Za-z0-9_]{16,}`
8. **Slack tokens**: `xox[bporas]-[A-Za-z0-9-]{10,}`
9. **Generic high-entropy secrets**: `(?i)(secret|token|key|credential)\s*[:=]\s*['"][A-Za-z0-9/+=]{32,}['"]`

### Step 3: Check Sensitive Files

Use Glob to check for the presence of files that commonly contain secrets:

- `.env`, `.env.*` (except `.env.example`, `.env.template`)
- `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.jks`
- `credentials.json`, `service-account*.json`
- `*secret*`, `*.keystore`
- `id_rsa`, `id_ed25519`, `id_ecdsa` (without `.pub`)

Cross-reference with `.gitignore` — flag any sensitive file that is NOT gitignored.

### Step 4: Check .gitignore Coverage

Verify that `.gitignore` includes entries for common secret file patterns:

- `.env`
- `*.pem` / `*.key`
- `credentials.json`

Report any missing gitignore entries as warnings.

### Step 5: Git History Scan (if --history)

Only perform this step if `--history` was passed.

Run `git log -p --all --diff-filter=A -- '*.env' '*.pem' '*.key' 'credentials.json'` to find secrets that were committed and later removed.

Also search recent commits (last 50) for high-confidence patterns:
```bash
git log -p -50 --all | grep -E 'AKIA[0-9A-Z]{16}|-----BEGIN.*PRIVATE KEY-----|(?i)(password|secret|token)\s*[:=]\s*['\''"][^'\''"]{8,}['\''"]'
```

### Step 6: Report

Present findings in a structured format:

**If secrets found:**
```
## Secret Scan Results

### Findings (X issues)

| Severity | File | Line | Type | Pattern |
|----------|------|------|------|---------|
| HIGH     | ... | ... | AWS Key | AKIA... |

### Recommendations
- [specific remediation steps per finding]
- If found in git history: recommend `git filter-repo` or BFG Repo-Cleaner
```

**If clean:**
```
## Secret Scan Results

No secrets or credentials detected.

Scanned: X files
Patterns checked: 9
Git history: [scanned/skipped]
```

## Important Notes

- Never print the full value of a detected secret — truncate or mask it
- False positives are preferable to false negatives — flag anything suspicious
- Remind the user that this scan is pattern-based and not exhaustive; tools like `trufflehog` or `gitleaks` provide deeper analysis
