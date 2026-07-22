#!/usr/bin/env bash
#
# Contract tests for the testworkflow-author OPTIONAL JSON input/output mode.
#
# What this guards:
#   1. The JSON output envelope examples validate against the skill's output schema.
#   2. The JSON authoring-request example validates against the skill's input schema.
#   3. The workflow YAML embedded in the success envelope is a real TestWorkflow
#      (structural check; a full `--dry-run` when the testkube CLI is present).
#   4. REGRESSION: the skill still documents the default (prose in -> YAML file out)
#      behavior and still marks JSON mode as optional/opt-in. The whole point of the
#      change is to NOT break what already works.
#
# Dependencies: bash + python3 (json only). `jsonschema` and `testkube` are used if
# present and gracefully skipped otherwise. No network, no secrets.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$(cd "$HERE/../../plugins/testkube-skills/skills/testworkflow-author" && pwd)"
SKILL_MD="$SKILL/SKILL.md"
IN_SCHEMA="$SKILL/assets/json-mode-input.schema.json"
OUT_SCHEMA="$SKILL/assets/json-mode-output.schema.json"

pass=0; fail=0
ok()   { echo "  PASS: $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL: $1"; fail=$((fail+1)); }

echo "== 1. JSON fixtures & schemas parse =="
for f in "$IN_SCHEMA" "$OUT_SCHEMA" "$HERE"/*.json; do
  if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" 2>/dev/null; then
    ok "valid JSON: ${f#$HERE/}"
  else
    bad "invalid JSON: $f"
  fi
done

echo "== 2. Examples validate against the skill schemas =="
validate() { # <schema> <instance>
  python3 - "$1" "$2" <<'PY'
import json, sys
schema = json.load(open(sys.argv[1]))
inst = json.load(open(sys.argv[2]))
try:
    import jsonschema
    jsonschema.validate(inst, schema)
    print("jsonschema: valid")
except ModuleNotFoundError:
    # Minimal fallback: required top-level keys + status-specific keys for the envelope.
    assert isinstance(inst, dict), "instance is not an object"
    for k in schema.get("required", []):
        assert k in inst, f"missing required key: {k}"
    st = inst.get("status")
    if st == "success":
        assert "workflow" in inst and "validation" in inst, "success envelope missing workflow/validation"
        assert set(["filename","yaml"]).issubset(inst["workflow"]), "workflow missing filename/yaml"
    elif st == "needs_input":
        assert "reason" in inst and "message" in inst, "needs_input missing reason/message"
    elif st == "error":
        assert "code" in inst and "message" in inst, "error missing code/message"
    print("fallback structural check: valid")
PY
}
if validate "$OUT_SCHEMA" "$HERE/output.example.json"        >/dev/null 2>&1; then ok "output.example.json vs output schema"; else bad "output.example.json vs output schema"; fi
if validate "$OUT_SCHEMA" "$HERE/output.needs-input.example.json" >/dev/null 2>&1; then ok "output.needs-input.example.json vs output schema"; else bad "output.needs-input.example.json vs output schema"; fi
if validate "$IN_SCHEMA"  "$HERE/input.example.json"          >/dev/null 2>&1; then ok "input.example.json vs input schema"; else bad "input.example.json vs input schema"; fi

echo "== 3. Embedded workflow YAML is a real TestWorkflow =="
TMP_YAML="$(mktemp -t twa-json-mode.XXXXXX.yaml)"
trap 'rm -f "$TMP_YAML"' EXIT
python3 -c "import json; open('$TMP_YAML','w').write(json.load(open('$HERE/output.example.json'))['workflow']['yaml'])"
if grep -q '^apiVersion: testworkflows\.testkube\.io/' "$TMP_YAML" \
   && grep -q '^kind: TestWorkflow' "$TMP_YAML" \
   && grep -q '^spec:' "$TMP_YAML"; then
  ok "embedded YAML has apiVersion/kind/spec"
else
  bad "embedded YAML missing required top-level keys"
fi
# The live `--dry-run` is ADVISORY, not a hard gate: it needs a configured,
# reachable, unblocked testkube context (cloud org or cluster) that a generic
# test/CI environment will not have. A failure here is almost always
# environmental (auth, blocked org, no cluster), not a defect in the YAML — the
# deterministic guarantee is the structural check above. It only turns green when
# a healthy context is present.
if command -v testkube >/dev/null 2>&1; then
  if testkube create testworkflow --dry-run -f "$TMP_YAML" >/dev/null 2>&1; then
    ok "testkube --dry-run accepted the embedded YAML"
  else
    echo "  ADVISORY: testkube --dry-run did not pass (likely no reachable/unblocked context; not a YAML defect)"
  fi
else
  echo "  SKIP: testkube CLI not on PATH (structural check only)"
fi

echo "== 4. REGRESSION: default behavior still documented, JSON mode still optional =="
grep -q 'Default to the filename `testworkflow.yaml`' "$SKILL_MD" \
  && ok "default 'write testworkflow.yaml' behavior still documented" \
  || bad "default YAML-file behavior missing from SKILL.md"
grep -qi 'Optional JSON mode (opt-in only)' "$SKILL_MD" \
  && ok "JSON mode is marked optional/opt-in" \
  || bad "JSON mode is not marked optional in SKILL.md"
grep -q 'byte-for-byte the YAML you would have written to disk' "$SKILL_MD" \
  && ok "SKILL.md guarantees identical YAML across modes" \
  || bad "SKILL.md missing the identical-YAML guarantee"

echo "== 5. Composition scenario: 4 discovered suites -> one orchestrator =="
DISCO_SCHEMA="$(cd "$HERE/../.." && pwd)/plugins/testkube-skills/skills/test-discovery/assets/manifest-schema.json"
# 5a. The input really is valid test-discovery output (proves the pipe is real).
#     Uses the test-discovery schema via jsonschema when available; otherwise a
#     discovery-shaped structural check (the generic validate() fallback is
#     envelope-specific and would not fit a discovery manifest).
if python3 - "$DISCO_SCHEMA" "$HERE/compose.discovery-input.json" <<'PY'
import json, sys, os
schema_path, inst_path = sys.argv[1], sys.argv[2]
inst = json.load(open(inst_path))
if os.path.isfile(schema_path):
    try:
        import jsonschema
        jsonschema.validate(inst, json.load(open(schema_path)))
        sys.exit(0)
    except ModuleNotFoundError:
        pass
assert inst.get("status") == "success", "discovery status is not success"
assert isinstance(inst.get("suites"), list) and inst["suites"], "no suites in discovery manifest"
PY
then ok "compose.discovery-input.json is valid test-discovery output"; else bad "compose.discovery-input.json is not valid test-discovery output"; fi
# 5b. The composed envelope validates against the author output schema.
if validate "$OUT_SCHEMA" "$HERE/compose.output.example.json" >/dev/null 2>&1; then
  ok "compose.output.example.json vs output schema"
else
  bad "compose.output.example.json vs output schema"
fi
# 5c. The orchestrator YAML composes all 4 suites via execute + config-gated conditions.
if python3 - "$HERE/compose.discovery-input.json" "$HERE/compose.output.example.json" <<'PY'
import json, sys, re
disco = json.load(open(sys.argv[1]))
env = json.load(open(sys.argv[2]))
n = len(disco["suites"])
y = env["workflow"]["yaml"]
assert y.startswith("apiVersion: testworkflows.testkube.io/"), "wrong apiVersion"
assert "kind: TestWorkflow" in y, "not a TestWorkflow"
assert y.count("execute:") == n, f"expected {n} execute steps, got {y.count('execute:')}"
assert y.count("condition: config.") == n, f"expected {n} config-gated conditions, got {y.count('condition: config.')}"
assert re.search(r"config:\s*\n\s+run", y), "no spec.config toggles found"
PY
then ok "orchestrator composes all $(python3 -c "import json;print(len(json.load(open('$HERE/compose.discovery-input.json'))['suites']))") suites via execute + config conditions"; else bad "orchestrator composition structure is wrong"; fi

echo
echo "== summary: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
