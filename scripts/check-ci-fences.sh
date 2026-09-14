#!/usr/bin/env bash
# Run every CI fence in the git-tracked tree. See README-branching.md.
# Exit 0 when all fences pass, 1 on any fence failure or parse error.

set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2

# Split so this script does not contain the markers itself.
BEGIN_MARK='!!!CI-FENCE-''BEGIN'
END_MARK='!!!CI-FENCE-''END'

tmp=$(mktemp -d) || exit 2
trap 'rm -rf "$tmp"' EXIT
failed=0

report() { # location, message...
  local loc=$1
  shift
  printf '✖ fence (%s)\n' "$loc"
  printf '  %s\n' "$@"
  failed=1
}

closer_for() {
  case "$1" in
    *.ml | *.mli) echo '*)' ;;
    *.dhall) echo '-}' ;;
    *.rs | *.go | *.nix | *.js | *.ts) echo '*/' ;;
  esac
}

# The body prefix is exactly the text before the END marker on its line.
check_fence() { # file, begin line, caption, prefix, body lines...
  local file=$1 loc="$1:$2" caption=$3 p=$4
  shift 4
  local closer script="$tmp/fence" line stripped status out
  local p_bare=${p%"${p##*[![:space:]]}"} # p without trailing whitespace
  closer=$(closer_for "$file")

  if [[ -z "${caption//[[:space:]]/}" ]]; then
    report "$loc" "parse error: empty caption"
    return
  fi

  : >"$script"
  for line in "$@"; do
    if [[ -n "$closer" && $line == *"$closer"* ]]; then
      report "$loc" "\"$caption\"" "parse error: body contains the host comment closer $closer"
      return
    fi
    if [[ -z "${line//[[:space:]]/}" || $line == "$p_bare" ]]; then
      stripped=""
    elif [[ $line == "$p"* ]]; then
      stripped=${line#"$p"}
    else
      report "$loc" "\"$caption\"" "parse error: line does not start with \"$p\": $line"
      return
    fi
    # drop leading blank lines so the shebang is the first line
    [[ -s "$script" || -n "$stripped" ]] && printf '%s\n' "$stripped" >>"$script"
  done

  if [[ $(head -c2 "$script") != '#!' ]]; then
    report "$loc" "\"$caption\"" "parse error: first body line must be a shebang"
    return
  fi

  chmod +x "$script"
  out=$(timeout 60 "$script" 2>&1 </dev/null)
  status=$?
  if ((status == 124)); then
    report "$loc" "\"$caption\"" "timed out after 60s" "output:" "$(sed 's/^/  /' <<<"$out")"
  elif ((status != 0)); then
    report "$loc" "\"$caption\"" "exited $status" "output:" "$(sed 's/^/  /' <<<"$out")"
  fi
}

while IFS= read -r file; do
  in_fence=0 n=0 begin=0 caption="" body=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    n=$((n + 1))
    if [[ $line == *"$BEGIN_MARK"* ]]; then
      ((in_fence)) && report "$file:$begin" "parse error: BEGIN without END"
      caption=${line#*"$BEGIN_MARK"}
      in_fence=1 begin=$n caption=${caption#"${caption%%[![:space:]]*}"} body=()
    elif [[ $line == *"$END_MARK"* ]]; then
      if ((in_fence)); then
        check_fence "$file" "$begin" "$caption" "${line%%"$END_MARK"*}" "${body[@]}"
        in_fence=0
      else
        report "$file:$n" "parse error: END without BEGIN"
      fi
    elif ((in_fence)); then
      body+=("$line")
    fi
  done <"$file"
  ((in_fence)) && report "$file:$begin" "parse error: BEGIN without END"
done < <(git grep -lF -e "$BEGIN_MARK" -e "$END_MARK" -- \
  ':!README-branching.md' ':!scripts/tests/test_check_ci_fences.sh')

exit "$failed"
