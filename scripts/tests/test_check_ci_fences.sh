#!/usr/bin/env bash
# Fixture tests for scripts/check-ci-fences.sh: each case is a throwaway git
# repo holding one file, checked for the script's exit code and output.

set -uo pipefail
checker="$(cd "$(dirname "$0")/.." && pwd)/check-ci-fences.sh"
failures=0

# case NAME FILENAME EXPECTED_EXIT EXPECTED_OUTPUT_SUBSTRING <<< CONTENT
case_() {
  local name=$1 file=$2 want_exit=$3 want_out=$4 repo out status
  repo=$(mktemp -d)
  git -C "$repo" init -q
  mkdir -p "$repo/$(dirname "$file")"
  cat >"$repo/$file"
  git -C "$repo" add -A
  out=$(cd "$repo" && BUILDKITE_BRANCH=develop "$checker" 2>&1)
  status=$?
  rm -rf "$repo"
  if [[ $status != "$want_exit" || $out != *"$want_out"* ]]; then
    printf 'FAIL %s: exit %s (want %s), output:\n%s\n' "$name" "$status" "$want_exit" "$out"
    failures=$((failures + 1))
  else
    echo "ok   $name"
  fi
}

case_ "no fences" a.ml 0 "" <<'EOF'
let x = 1
EOF

case_ "bare ocaml fence passes" a.ml 0 "" <<'EOF'
(* !!!CI-FENCE-BEGIN content canary
#!/usr/bin/env bash
grep -q 'let x' a.ml
!!!CI-FENCE-END *)
let x = 1
EOF

case_ "prefixed fence with case *) and blank comment line passes" Dockerfile 0 "" <<'EOF'
# !!!CI-FENCE-BEGIN develop-only
# #!/usr/bin/env bash
#
# case "$BUILDKITE_BRANCH" in develop) ;; *) exit 1 ;; esac
# !!!CI-FENCE-END
FROM scratch
EOF

case_ "indented yaml fence passes" ci.yaml 0 "" <<'EOF'
jobs:
  # !!!CI-FENCE-BEGIN yaml canary
  # #!/usr/bin/env bash
  # true
  # !!!CI-FENCE-END
  build: {}
EOF

case_ "branch assertion trips" a.sh 1 "this is master-only, found on develop" <<'EOF'
# !!!CI-FENCE-BEGIN master-only
# #!/usr/bin/env bash
# [ "$BUILDKITE_BRANCH" = master ] || { echo "this is master-only, found on $BUILDKITE_BRANCH"; exit 1; }
# !!!CI-FENCE-END
EOF

case_ "missing END" a.sh 1 "BEGIN without END" <<'EOF'
# !!!CI-FENCE-BEGIN oops
# #!/usr/bin/env bash
# true
EOF

case_ "END without BEGIN" a.sh 1 "END without BEGIN" <<'EOF'
# !!!CI-FENCE-END
EOF

case_ "prefix drift" a.sh 1 "does not start with" <<'EOF'
# !!!CI-FENCE-BEGIN drift
# #!/usr/bin/env bash
#true
# !!!CI-FENCE-END
EOF

case_ "missing shebang" a.sh 1 "shebang" <<'EOF'
# !!!CI-FENCE-BEGIN no shebang
# true
# !!!CI-FENCE-END
EOF

case_ "empty caption" a.sh 1 "empty caption" <<'EOF'
# !!!CI-FENCE-BEGIN
# #!/usr/bin/env bash
# true
# !!!CI-FENCE-END
EOF

case_ "host closer in ocaml body" a.ml 1 "host comment closer" <<'EOF'
(* !!!CI-FENCE-BEGIN closer
#!/usr/bin/env bash
case x in *) true ;; esac
!!!CI-FENCE-END *)
EOF

case_ "report-all" a.sh 1 "b-fails" <<'EOF'
# !!!CI-FENCE-BEGIN a-fails
# #!/usr/bin/env bash
# false
# !!!CI-FENCE-END
# !!!CI-FENCE-BEGIN b-fails
# #!/usr/bin/env bash
# false
# !!!CI-FENCE-END
EOF

((failures == 0)) || { echo "$failures case(s) failed"; exit 1; }
