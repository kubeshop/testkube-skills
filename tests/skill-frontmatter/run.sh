#!/usr/bin/env bash
#
# Static checks for every skill under plugins/testkube-skills/skills/.
#
# What this guards, per skill:
#   1. SKILL.md opens with a YAML frontmatter block that is closed by a second `---`.
#   2. `name` matches the skill's directory and the Agent Skills rules: lowercase
#      letters, digits and single hyphens, at most 64 characters.
#   3. `description` is present, non-empty and at most 1024 characters, the Agent
#      Skills limit. Agents match requests against it, so a description that is cut
#      off or missing makes the skill unreachable.
#   4. agents/openai.yaml exists and its `default_prompt` invokes the skill by name
#      (`$<name>`), so the Codex entry does not point at a renamed skill.
#
# Dependencies: bash + python3 (standard library only). No network, no secrets.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS="$(cd "$HERE/../../plugins/testkube-skills/skills" && pwd)"

pass=0; fail=0
ok()   { echo "  PASS: $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL: $1"; fail=$((fail+1)); }

for dir in "$SKILLS"/*/; do
  dir="${dir%/}"
  skill="$(basename "$dir")"
  echo "== $skill =="

  if [ ! -f "$dir/SKILL.md" ]; then
    bad "$skill has no SKILL.md"
    continue
  fi

  # Prints one "PASS|FAIL<TAB>message" line per check.
  checks="$(python3 -I - "$dir/SKILL.md" "$skill" <<'EOF'
import re, sys

path, skill = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8").read().split("\n")

def say(ok, msg):
    print(("PASS" if ok else "FAIL") + "\t" + msg)

if not lines or lines[0] != "---" or "---" not in lines[1:]:
    say(False, "SKILL.md does not open with a closed --- frontmatter block")
    sys.exit()
front = lines[1:lines[1:].index("---") + 1]
say(True, "frontmatter block")

# A top-level scalar: plain, quoted, or a folded (>) or literal (|) block whose
# indented lines follow it.
def value(key):
    for i, line in enumerate(front):
        if not line.startswith(key + ":"):
            continue
        v = line[len(key) + 1:].strip()
        if v[:1] in (">", "|"):
            body = []
            for cont in front[i + 1:]:
                if cont and not cont[0].isspace():
                    break
                body.append(cont.strip())
            return (" " if v[0] == ">" else "\n").join(b for b in body if b)
        if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
            v = v[1:-1]
        return v
    return None

name = value("name")
if name is None:
    say(False, "no name")
elif name != skill:
    say(False, f"name {name!r} does not match the directory {skill!r}")
elif len(name) > 64 or not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", name):
    say(False, f"name {name!r} is not lowercase letters, digits and single hyphens, at most 64 characters")
else:
    say(True, "name matches the directory")

desc = value("description")
if not desc:
    say(False, "no description")
elif len(desc) > 1024:
    say(False, f"description is {len(desc)} characters; the limit is 1024")
else:
    say(True, f"description is {len(desc)} characters")
EOF
)"
  while IFS=$'\t' read -r verdict msg; do
    if [ "$verdict" = PASS ]; then ok "$msg"; else bad "$msg"; fi
  done <<< "$checks"

  if [ ! -f "$dir/agents/openai.yaml" ]; then
    bad "no agents/openai.yaml"
  elif grep -Eq "^[[:space:]]*default_prompt:.*\\\$$skill([^a-z0-9-]|\$)" "$dir/agents/openai.yaml"; then
    ok "agents/openai.yaml invokes \$$skill"
  else
    bad "agents/openai.yaml default_prompt does not invoke \$$skill"
  fi
done

echo
echo "$fail failed"
[ "$fail" = 0 ]
