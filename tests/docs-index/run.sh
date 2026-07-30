#!/usr/bin/env bash
# Verify the curated docs index in the `testkube` skill still points at live,
# canonical pages.
#
# Three signals, because status codes alone prove almost nothing here:
#
#   1. HTTP status, WITHOUT `-L`. Catches outright deletion (404) and any
#      genuine server-side redirect.
#
#   2. The response BODY. testkube-docs maintains a large redirects.js, and
#      Docusaurus implements those redirects CLIENT-SIDE: a renamed page still
#      answers 200, serving a ~350-byte stub containing
#      `<meta http-equiv="refresh" content="0; url=/the/new/path">`.
#      No status-code check can see this. A stub is a FAILURE — the link works,
#      but the index carries a stale slug that should be replaced with the
#      target.
#
#   3. Membership in sitemap.xml. Advisory only — a handful of live pages are
#      intentionally unlisted, so absence is a warning, not a failure.
#
# Usage: bash tests/docs-index/run.sh
# Exit:  0 = all indexed URLs are canonical and reachable; 1 = otherwise.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$REPO_ROOT/plugins/testkube-skills/skills/testkube/SKILL.md"
SITEMAP_URL="https://docs.testkube.io/sitemap.xml"
TIMEOUT=20

pass=0
fail=0
warn=0

ok()      { printf '  PASS: %s\n' "$1"; pass=$((pass + 1)); }
bad()     { printf '  FAIL: %s\n' "$1"; fail=$((fail + 1)); }
advise()  { printf '  WARN: %s\n' "$1"; warn=$((warn + 1)); }

[ -f "$SKILL" ] || { echo "FATAL: skill not found at $SKILL"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Every URL the skill cites, normalised (drop trailing punctuation and slash).
grep -oE 'https://[^ )`>,|]+' "$SKILL" \
  | sed 's/[.,]*$//; s|/$||' \
  | sort -u > "$tmp/indexed.txt"

echo "== 1. Every cited URL is reachable and canonical (no redirects) =="
while read -r url; do
  code="$(curl -s -o "$tmp/body.html" -w '%{http_code}' --max-time "$TIMEOUT" "$url")"
  case "$code" in
    200)
      # Client-side redirect stub? Docusaurus emits a meta refresh naming the
      # real destination; extract it so the fix is copy-pasteable.
      target="$(grep -oiE '<meta[^>]+http-equiv="refresh"[^>]+content="[^"]*url=[^">]+' "$tmp/body.html" \
                 | sed -E 's/.*url=//' | head -1)"
      if [ -n "$target" ]; then
        bad "$url -> client-side redirect to $target (stale slug; update the index to the target)"
      else
        ok "$url"
      fi
      ;;
    301|302|307|308)
      bad "$url -> $code -> $(curl -s -o /dev/null -w '%{redirect_url}' --max-time "$TIMEOUT" "$url") (stale slug)"
      ;;
    000)
      bad "$url -> no response (network or timeout)"
      ;;
    *)
      bad "$url -> $code"
      ;;
  esac
done < "$tmp/indexed.txt"

echo
echo "== 2. Cited docs pages appear in the sitemap (advisory) =="
if curl -sf --max-time "$TIMEOUT" "$SITEMAP_URL" \
     | grep -oE '<loc>[^<]+' | sed 's|<loc>||; s|/$||' | sort -u > "$tmp/sitemap.txt" \
   && [ -s "$tmp/sitemap.txt" ]; then
  # The sitemap never lists itself, so exclude it from its own cross-check.
  grep '^https://docs\.testkube\.io' "$tmp/indexed.txt" \
    | grep -v '/sitemap\.xml$' > "$tmp/docs-only.txt" || true
  missing="$(comm -23 "$tmp/docs-only.txt" "$tmp/sitemap.txt")"
  if [ -z "$missing" ]; then
    ok "all $(wc -l < "$tmp/docs-only.txt" | tr -d ' ') cited docs pages are in the sitemap"
  else
    while read -r url; do
      [ -n "$url" ] && advise "not in sitemap (may be intentionally unlisted): $url"
    done <<< "$missing"
  fi
else
  advise "could not fetch $SITEMAP_URL — skipping sitemap cross-check"
fi

echo
echo "== summary: $pass passed, $fail failed, $warn warnings =="
[ "$fail" -eq 0 ]
