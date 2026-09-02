#!/bin/bash
# Exercises git/hooks/pre-commit in a throwaway repo under $TMPDIR.
# Never touches the dotfiles repo itself.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/git/hooks/pre-commit"
BASE="$(mktemp -d "${TMPDIR:-/tmp}/precommit-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT

cd "$BASE" || exit 1
git init -q .
mkdir -p git/hooks obsidian/config/plugins/some-plugin dot_config/nvim
cp "$HOOK" git/hooks/pre-commit
git config core.hooksPath git/hooks
git config user.email test@example.com
git config user.name test
echo '{"vimrcFileName":".obsidian.vimrc"}' > obsidian/config/plugins/some-plugin/data.json
echo 'vim.opt.number = true' > dot_config/nvim/init.lua
if ! git add -A >/dev/null || ! git commit -q -m base; then
    echo "FATAL - could not create the base commit; every later result would be misleading" >&2
    exit 1
fi

pass=0
failed=0

try() { # try <name> <expected rc: 0 allowed, 1 blocked>
    local name="$1" want="$2" rc
    git add -A -f >/dev/null 2>&1
    git commit -m "$name" >"$BASE/out" 2>&1
    rc=$?
    (( rc > 1 )) && rc=1
    if [[ "$rc" == "$want" ]]; then
        echo "ok   - $name"
        (( pass++ ))
    else
        echo "FAIL - $name (want rc=$want, got rc=$rc)"
        sed 's/^/       /' "$BASE/out"
        (( failed++ ))
    fi
    git reset -q --hard HEAD >/dev/null 2>&1
    git clean -qfd >/dev/null 2>&1
}

# Assembled at runtime so no literal token pattern is ever stored in this public
# repo, where GitHub secret scanning would flag it.
# Note: not AWS's AKIAIOSFODNN7EXAMPLE - gitleaks allowlists that as a known
# example, so a fixture using it would pass for the wrong reason.
AWS_KEY="$(printf 'AKIA%s' '4ZXCVBNM7QWERTYU')"
GH_PAT="$(printf 'ghp_%s' '012345678901234567890123456789abcdef')"
# No recognisable prefix - only the key name marks this one as a credential.
OPAQUE_TOKEN="$(printf 'abc123%s' 'def456')"

echo "== gitleaks, whole staged diff =="
printf 'local k = "%s"\n' "$AWS_KEY" > dot_config/nvim/secret.lua
try "aws key anywhere in the repo is blocked" 1

printf 'local t = "%s"\n' "$GH_PAT" > dot_config/nvim/secret.lua
try "github PAT anywhere in the repo is blocked" 1

printf 'local ok = "just a normal string"\n' > dot_config/nvim/fine.lua
try "ordinary config passes" 0

echo "== obsidian-specific rules =="
printf '{"apiKey":"%s","other":true}\n' "$OPAQUE_TOKEN" > obsidian/config/plugins/some-plugin/data.json
try "apiKey holding an unrecognised token is blocked" 1

echo '{"settings":{"personalAccessToken":"hunter2"}}' > obsidian/config/plugins/some-plugin/data.json
try "personalAccessToken is blocked" 1

echo '{"apiKey":"","enabled":true}' > obsidian/config/plugins/some-plugin/data.json
try "empty apiKey passes" 0

echo '{"main":{"id":"some note.md"}}' > obsidian/config/workspace.json
try "workspace.json is blocked even when force-added" 1

echo '{"colorGroups":[]}' > obsidian/config/graph.json
try "graph.json is blocked even when force-added" 1

echo "== degradation =="
# A PATH holding only the tools the hook needs, so gitleaks is absent no matter
# where it is installed on this machine. /usr/bin would still contain it on a
# box where it came from apt.
STUB_PATH="$BASE/stub-bin"
mkdir -p "$STUB_PATH"
for tool in git grep sed; do
    ln -sf "$(command -v "$tool")" "$STUB_PATH/$tool"
done
if PATH="$STUB_PATH" command -v gitleaks >/dev/null 2>&1; then
    echo "FAIL - stub PATH still resolves gitleaks; the fallback is not being exercised"
    (( failed++ ))
fi

printf 'local k = "%s"\n' "$AWS_KEY" > dot_config/nvim/secret.lua
git add -A -f >/dev/null 2>&1
PATH="$STUB_PATH" git commit -m "no gitleaks on PATH" >"$BASE/out" 2>&1
rc=$?
if (( rc != 0 )) && grep -q "refusing to commit unscanned" "$BASE/out"; then
    echo "ok   - without gitleaks: fails closed"
    (( pass++ ))
else
    echo "FAIL - without gitleaks should fail closed (rc=$rc)"
    sed 's/^/       /' "$BASE/out"
    (( failed++ ))
fi

PATH="$STUB_PATH" DOTFILES_ALLOW_MISSING_GITLEAKS=1 \
    git commit -m "no gitleaks, opted out" >"$BASE/out" 2>&1
rc=$?
if (( rc == 0 )) && grep -q "skipped by request" "$BASE/out"; then
    echo "ok   - without gitleaks: DOTFILES_ALLOW_MISSING_GITLEAKS allows the commit"
    (( pass++ ))
else
    echo "FAIL - escape hatch did not allow the commit (rc=$rc)"
    sed 's/^/       /' "$BASE/out"
    (( failed++ ))
fi

echo
echo "passed=$pass failed=$failed"
(( failed == 0 ))
