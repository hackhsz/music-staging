#!/bin/sh
# Usage: scripts/check-clean.sh [--staged]
#   --staged  check only what is staged (used by .githooks/pre-commit)
#   default   check every tracked and untracked-but-not-ignored file
# Env: HYGIENE_MAX_BYTES (default 1048576), HYGIENE_STRICT=1 makes stylua/selene findings block.

mode=all
[ "$1" = "--staged" ] && mode=staged

root=$(git rev-parse --show-toplevel) || exit 1
cd "$root" || exit 1

export LC_ALL=C
max_bytes=${HYGIENE_MAX_BYTES:-1048576}
errors=0
warnings=0
tmp=$(mktemp -d 2>/dev/null || mktemp -d -t hygiene)
trap 'rm -rf "$tmp"' EXIT

fail() { printf 'ERROR: %s\n' "$1" >&2; errors=$((errors + 1)); }
warn() { printf 'WARN:  %s\n' "$1" >&2; warnings=$((warnings + 1)); }
lint_issue() { if [ "$HYGIENE_STRICT" = 1 ]; then fail "$1"; else warn "$1"; fi; }
gitq() { git -c core.quotepath=off "$@"; }
nul() { tr '\n' '\0'; }

if [ "$mode" = staged ]; then
	gitq diff --cached --name-only --diff-filter=ACMR > "$tmp/files"
	gitq diff --cached --name-only --diff-filter=A > "$tmp/new"
else
	{ gitq ls-files; gitq ls-files --others --exclude-standard; } | sort -u > "$tmp/files"
	while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done < "$tmp/files" > "$tmp/existing"
	mv "$tmp/existing" "$tmp/files"
	cp "$tmp/files" "$tmp/new"
fi

if [ "$mode" = staged ]; then
	sed 's/^/:/' "$tmp/files" | git cat-file --batch-check='%(objectsize)' > "$tmp/sizes"
	paste -d '\t' "$tmp/sizes" "$tmp/files"
else
	nul < "$tmp/files" | xargs -0 -r wc -c | awk '{ s = $1; sub(/^ *[0-9]+ /, ""); if ($0 != "total") printf "%s\t%s\n", s, $0 }'
fi > "$tmp/sized"
while IFS="$(printf '\t')" read -r size f; do
	case "$size" in *[!0-9]*|'') continue ;; esac
	[ "$size" -gt "$max_bytes" ] && fail "$f is $size bytes (limit $max_bytes). Keep large binaries out of git."
done < "$tmp/sized"

grep -iE '\.(rbxl|rbxlx|rbxm|rbxmx)(\.lock)?$' "$tmp/files" > "$tmp/places" || true
while IFS= read -r f; do
	fail "$f is a Roblox place/model file. The place is built from src/; do not commit binaries."
done < "$tmp/places"

scratch_re='(^|/)(scratch|_scratch|tmp|temp|backups?|_backup|_old|_audit)(/|$)|[_.-](old|backup|bak|orig|copy|compilecheck|audit)([_./-]|$)|compilecheck|backup_?[0-9]{6,}|updaterecovery| - copy|(^|/)copy of |\([0-9]+\)\.[^/]+$|\.(bak|orig|tmp|temp|swp)$|(^|[/_.-])test[0-9]+([_./-]|$)|(^|/)(untitled|asdf|foo)[0-9]*\.[^/]+$'
grep -iE "$scratch_re" "$tmp/files" > "$tmp/scratch" || true
while IFS= read -r f; do
	fail "$f looks like a scratch/backup file. Delete it or give it a real name."
done < "$tmp/scratch"

grep -iE '\.md$' "$tmp/new" | grep -vE '^(README|CLAUDE)\.md$|^docs/|^\.[^/]+/' > "$tmp/md" || true
while IFS= read -r f; do
	warn "$f: Markdown outside docs/. Docs live in docs/; only add .md files when asked."
done < "$tmp/md"

grep -iE '\.(luau|lua)$' "$tmp/files" | grep -v '/Packages/' > "$tmp/luau" || true

if [ "$mode" = staged ]; then
	gitq diff --cached -U0 --no-color --no-ext-diff --diff-filter=ACMR -- '*.luau' '*.lua' | awk '
		/^\+\+\+ / { f = substr($0, 5); sub(/^b\//, "", f); next }
		/^@@ / { split($3, p, ","); n = substr(p[1], 2) + 0; next }
		/^\+/ { printf "%s\t%d\t%s\n", f, n, substr($0, 2); n++ }
	' | grep -v '^[^	]*/Packages/'
else
	nul < "$tmp/luau" | xargs -0 -r awk '{ printf "%s\t%d\t%s\n", FILENAME, FNR, $0 }'
fi > "$tmp/lines"

awk '
{
	f = $0; sub(/\t.*/, "", f)
	rest = substr($0, length(f) + 2); ln = rest; sub(/\t.*/, "", ln)
	text = substr(rest, length(ln) + 2); sub(/\r$/, "", text)
	if (text !~ /^[ \t]*--/ || text ~ /^[ \t]*--(\[|\]|!)/) next
	body = text; sub(/^[ \t]*-+[ \t]*/, "", body)
	kind = ""
	if (text ~ /^[ \t]*--+[ \t]*(=|#|\*|~|-|─|═|━){3,}/ || body ~ /(=|#|\*|~|-|─|═|━){4,}[ \t]*$/)
		kind = "banner comment"
	else if (body ~ /^(local[ \t]+)?[A-Za-z_][A-Za-z0-9_.]*([ \t]*:[ \t]*[A-Za-z_{][]A-Za-z0-9_<>{}?|:,[ ]*)?[ \t]*=[ \t]*(nil|true|false|-?[0-9.]+|"[^"]*"|\{.*\}|[A-Za-z_][A-Za-z0-9_.:]*\(.*\))[ \t]*[,;]?$/ \
		|| body ~ /^local[ \t]+[A-Za-z_][A-Za-z0-9_]*([ \t]*:[ \t]*[A-Za-z_{][]A-Za-z0-9_<>{}?|:,[ ]*)?[ \t]*=/ \
		|| body ~ /^(local[ \t]+)?function[ \t]+[A-Za-z_][A-Za-z0-9_.:]*[ \t]*\(/ \
		|| body ~ /^(end|else|end\))[ \t]*[,;]?$/ \
		|| body ~ /^(if|elseif)[ \t].*[ \t]then$/ \
		|| body ~ /^(for|while)[ \t].*[ \t]do$/ \
		|| body ~ /^return([ \t]+(nil|true|false|self|-?[0-9.]+|\{.*\}|[A-Za-z_][A-Za-z0-9_.:]*\(.*\)))?[ \t]*$/ \
		|| body ~ /^(print|warn|error|require|task\.[a-z]+)[ \t]*\(.*\)[ \t]*$/ \
		|| body ~ /^[A-Za-z_][A-Za-z0-9_]*([.:][A-Za-z_][A-Za-z0-9_]*)+\(.*\)[ \t]*$/)
		kind = "commented-out code"
	else if (body ~ /^(NEW|ADDED|FIXED|FIX|CHANGED|UPDATED|REMOVED|HISTORY|CHANGELOG)[ \t]*[:!-]/ \
		|| tolower(body) ~ /^(added|fixed|removed|changed|updated|refactored)[ \t]/ \
		|| tolower(body) ~ /^history[ \t]*:/)
		kind = "changelog-style comment"
	else if (body ~ /^(TODO|FIXME|XXX|HACK)([ \t:(-]|$)/) {
		t = body; sub(/^(TODO|FIXME|XXX|HACK)[^A-Za-z0-9]*/, "", t)
		if (length(t) < 15) kind = "TODO without substance"
	}
	if (kind != "") printf "%s:%s: %s: %s\n", f, ln, kind, text
}' "$tmp/lines" > "$tmp/comments"
while IFS= read -r hit; do
	fail "$hit"
done < "$tmp/comments"

if [ -s "$tmp/luau" ]; then
	if command -v stylua >/dev/null 2>&1; then
		nul < "$tmp/luau" | xargs -0 -r stylua --check >&2 || lint_issue "stylua --check failed (run: stylua <files>)"
	fi
	if command -v selene >/dev/null 2>&1; then
		nul < "$tmp/luau" | xargs -0 -r selene >&2 || lint_issue "selene reported problems"
	fi
fi

if [ "$errors" -gt 0 ]; then
	printf '\n%d error(s), %d warning(s). See CLAUDE.md for the rules.\n' "$errors" "$warnings" >&2
	[ "$mode" = staged ] && printf 'Commit blocked. Fix, rename, or unstage the offending files.\n' >&2
	exit 1
fi
[ "$warnings" -gt 0 ] && printf '%d warning(s).\n' "$warnings" >&2
[ "$mode" = all ] && echo "check-clean: OK"
exit 0
