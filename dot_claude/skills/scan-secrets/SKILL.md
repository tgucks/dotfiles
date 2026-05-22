---
name: scan-secrets
description: Scan the current repository for credentials, secrets, and personal or confidential data - anything that should not appear on the public web.
argument-hint: [--history] [path...]
allowed-tools: [Read, Glob, Grep, Bash]
disable-model-invocation: true
---

# Secret & Confidentiality Scanner

Scan the current repository for two classes of findings:

1. **Tier 1** - credentials and secrets (API keys, tokens, private keys, etc.)
2. **Tier 2** - personal or confidential data (anything identifying the user, their devices, their employer, or their non-public work)

## Guiding Question

The single test for any finding is: **"Would the user be comfortable if this exact file went up on a public GitHub repo right now?"**

- If clearly no -> flag it.
- If unsure -> flag it as `BORDERLINE` and let the user decide.
- If clearly yes -> ignore.

Do not store, cache, or hardcode any of the user's personal info anywhere - not in this skill, not in config files, not in the report verbatim. The skill is stateless about identity. Mask values in the report the same way credentials are masked.

## Arguments

Parse the arguments from: $ARGUMENTS

- `--history`: Also scan git history (slower, uses `git log -p`)
- `path...`: Optional paths to limit the scan scope. Defaults to the entire repo.

## Scan Procedure

### Step 1: Identify Scope

Determine the repository root with `git rev-parse --show-toplevel`. If not a git repo, use the current working directory.

If the user provided specific paths, limit scanning to those paths. Otherwise scan the full repo.

---

## Tier 1: Secrets & Credentials

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

Use Glob to check for the presence of files that commonly contain secrets or sensitive local state:

- `.env`, `.env.*` (except `.env.example`, `.env.template`)
- `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.jks`
- `credentials.json`, `service-account*.json`
- `*secret*`, `*.keystore`
- `id_rsa`, `id_ed25519`, `id_ecdsa` (without `.pub`)
- `.aws/credentials`, `.aws/config`
- `.kube/config`, `kubeconfig*`
- `.netrc`, `.pgpass`
- `.bash_history`, `.zsh_history`, `.python_history`, `.psql_history`
- Browser profile directories

Cross-reference with `.gitignore` - flag any sensitive file that is NOT gitignored.

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

---

## Tier 2: Personal & Confidential Data

This tier is judgement-based and noisy by design. Apply the guiding question to every finding. Borderline items are not bugs - they are invitations for the user to decide.

### Step 6: Personal Identifiers

- **Email addresses**: `[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}`. Suppress obvious open-source contact emails (`noreply@github.com`, `*@users.noreply.github.com`). Flag anything else - personal emails generally should not be hardcoded.
- **Phone numbers**: US (`\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b`) and international (`\+\d{1,3}[\s-]?\d{1,4}[\s-]?\d{3,}`).
- **Real-name-shaped strings** in author/committer/owner/contact fields outside `LICENSE`, `AUTHORS`, `CODEOWNERS`, and git metadata (`.git/`).

### Step 7: Device & Network Identifiers

- **Absolute home paths**: `/Users/[^/\s]+/`, `/home/[^/\s]+/`, `C:\\Users\\[^\\]+\\`. These leak both the username and the host's filesystem layout.
- **Internal-looking hostnames**: `\.(internal|corp|lan|intranet|priv|office)\b`. Treat `*.local` cautiously - flag unless the surrounding context clearly indicates mDNS/dev use (`localhost.local`, `*.local` in test fixtures).
- **Private-range IPv4 in non-test/non-doc context**: `\b10\.\d{1,3}\.\d{1,3}\.\d{1,3}\b`, `\b172\.(1[6-9]|2[0-9]|3[01])\.\d{1,3}\.\d{1,3}\b`, `\b192\.168\.\d{1,3}\.\d{1,3}\b`.
- **MAC addresses**: `\b([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}\b`.
- **SSH/VPN config content**: contents of `.ssh/config`, `known_hosts`, `authorized_keys`, Tailscale, WireGuard, OpenVPN configs.

### Step 8: Company / Work Identifiers

- **Private SaaS workspace URLs**: `[a-z0-9-]+\.slack\.com`, `[a-z0-9-]+\.atlassian\.net`, `linear\.app/[a-z0-9-]+`, `[a-z0-9-]+\.notion\.site`, internal Confluence/Google Docs links.
- **Ticket/issue IDs in source code**: patterns like `[A-Z]{2,}-\d+` in code comments outside commit messages and CHANGELOG files. Flag as borderline.
- **Project / code-name-shaped strings**: capitalized identifiers that read like internal codenames. **Borderline-name handling**: when `gh` is available on PATH, run `gh repo view <name> --json visibility 2>/dev/null` to check whether a same-named public repo exists.
  - Public repo found -> suppress.
  - Private or not found -> flag as `BORDERLINE`.
  - `gh` unavailable -> flag as `BORDERLINE` without the lookup.

### Step 9: Prose / Content Heuristics

- **Long prose blocks** (>200 chars) in non-doc files (i.e. not under `docs/`, not `*.md`, not `README*`) that read like meeting notes, transcripts, or ticket descriptions. Signals: dialogue colons (`Alice:`), phrases like `said`, `the team`, `we decided`, `as discussed`, `action items`.
- **TODO/FIXME comments** referencing internal systems, named individuals, or ticket IDs.
- **Pasted log snippets / stack traces** containing absolute paths or hostnames covered above.

---

## Step 10: Report

Present findings in two tiers. If a tier has no findings, replace its table with a single line: `No findings.`

```
## Scan Results

### Tier 1: Secrets & Credentials (X findings)

| Severity | File | Line | Type | Pattern (masked) |
|----------|------|------|------|------------------|
| HIGH     | ...  | ...  | AWS Key | AKIA**** |

### Tier 2: Personal & Confidential Data (Y findings)

| Confidence | File | Line | Category | Snippet (masked) |
|------------|------|------|----------|------------------|
| HIGH       | ...  | ...  | Home path | /Users/****/... |
| BORDERLINE | ...  | ...  | Project name | "Acme****" - public repo not found |

### Recommendations
- [per-finding remediation]
- For BORDERLINE items, confirm whether the referenced thing is already public.
- If found in git history: recommend `git filter-repo` or BFG Repo-Cleaner.

Scanned: X files
Git history: [scanned/skipped]
```

If both tiers are clean, replace the whole body with: `No findings. Scanned X files. Git history: [scanned/skipped].`

## Important Notes

- **Statelessness**: never store, cache, or hardcode the user's personal info into this skill, configs, or persistent files. The skill must work on any machine without prior knowledge of the user.
- **Masking**: never print the full value of a detected secret or piece of personal data - truncate or mask it.
- **False positives are preferable to false negatives** - flag anything suspicious. Tier 2 in particular is judgement-based and noisy by design.
- **Pattern-based limits**: this scan is not exhaustive. Tools like `trufflehog` or `gitleaks` provide deeper credential analysis but do not cover Tier 2 categories.
