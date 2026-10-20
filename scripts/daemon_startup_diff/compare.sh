#!/usr/bin/env bash
# Differential test of daemon startup: run a fixed matrix of startup scenarios
# against two mina.exe binaries and diff the normalised results.
#
# Usage: compare.sh BASE_MINA_EXE NEW_MINA_EXE OUT_DIR [SCENARIO...]
#
# Each scenario starts `mina daemon` with a fresh config directory. A run that
# reaches the start of [Mina_lib.create] ("Creating daemon with commit id") is
# killed there: every setting has been resolved and validated by that point.
# Runs that fail are left to exit on their own (crash reports can take a while).
#
# The comparison is of outcome class (user-error / crash / reached-create),
# exit code, stdout, stderr and the mina.log stream, after normalise.py has
# masked timestamps, source locations, backtraces, run paths and commit ids.
# The two binaries' runs live in old/ and new/: the names have equal length
# because the stdout logger only interpolates values below a length limit, so
# run paths of different lengths can render the same log line differently.

set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 BASE_MINA_EXE NEW_MINA_EXE OUT_DIR [SCENARIO...]" >&2
  exit 2
fi

BASE_EXE=$(realpath "$1")
NEW_EXE=$(realpath "$2")
OUT=$(realpath -m "$3")
shift 3

HERE=$(dirname "$(realpath "$0")")
TIMEOUT_SECS=${TIMEOUT_SECS:-180}

export MINA_PROFILE=${MINA_PROFILE:-dev}

PEER=/ip4/127.0.0.1/tcp/3002/p2p/12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsg

mkdir -p "$OUT"
FIXTURES=$OUT/fixtures
mkdir -p "$FIXTURES"
chmod 700 "$FIXTURES"

# Fixtures are generated once, with the base binary, so both binaries see
# byte-identical inputs.
if [[ ! -f $FIXTURES/bp-key ]]; then
  MINA_PRIVKEY_PASS=pw "$BASE_EXE" advanced generate-keypair \
    --privkey-path "$FIXTURES/bp-key" >/dev/null
fi
BP_PUBKEY=$(cat "$FIXTURES/bp-key.pub")
BP_PRIVKEY=$(MINA_PRIVKEY_PASS=pw "$BASE_EXE" advanced dump-keypair \
  --privkey-path "$FIXTURES/bp-key" | sed -n 's/^Private key: //p')

if [[ ! -f $FIXTURES/genesis.json ]]; then
  cat >"$FIXTURES/genesis.json" <<JSON
{ "genesis": { "genesis_state_timestamp": "2024-01-01T00:00:00Z" },
  "ledger": { "accounts": [ { "pk": "$BP_PUBKEY", "balance": "1000000" } ] } }
JSON
fi

write_json() {
  # write_json FILE JSON
  printf '%s\n' "$2" >"$1"
}

# --- Scenarios --------------------------------------------------------------
#
# Each scenario function runs in the scenario's run directory, with $CONF the
# (not yet existing) config directory, and must set:
#   ARGS  - array of daemon arguments (--config-directory is added)
#   ENVS  - array of NAME=VALUE environment entries
# It may write files into the run directory beforehand. Every run gets
# --config-file $FIXTURES/genesis.json (genesis ledger only, no daemon section)
# ahead of ARGS.

scenario_seed() { ARGS=(--seed); ENVS=(); }

scenario_demo_mode() { ARGS=(--demo-mode); ENVS=(); }

scenario_peer_flag() { ARGS=(--peer "$PEER"); ENVS=(); }

scenario_no_peers() { ARGS=(); ENVS=(); }

scenario_invalid_peer() { ARGS=(--peer not-a-multiaddr); ENVS=(); }

scenario_missing_peer_list_file() {
  ARGS=(--peer-list-file "$PWD/does-not-exist"); ENVS=()
}

scenario_peer_list_file() {
  printf '%s\n' "$PEER" >"$PWD/peers.txt"
  ARGS=(--peer-list-file "$PWD/peers.txt"); ENVS=()
}

scenario_peer_list_url_bad_scheme() {
  ARGS=(--peer-list-url ftp://example.com/peers); ENVS=()
}

scenario_peer_list_url_http() {
  ARGS=(--peer-list-url http://127.0.0.1:9/peers); ENVS=()
}

scenario_missing_config_file() {
  ARGS=(--seed --config-file "$PWD/does-not-exist.json"); ENVS=()
}

scenario_daemon_json_operator_keys() {
  mkdir -p "$CONF"
  write_json "$CONF/daemon.json" '{"daemon": {
    "--client-port": 18301,
    "client-port": 18999,
    "--external-port": 18302,
    "min-connections": 7,
    "max-connections": 70,
    "validation-queue-size": 99,
    "log-txn-pool-gossip": true,
    "log-snark-work-gossip": true,
    "log-block-creation": false,
    "work-selection": "seq",
    "work-reassignment-wait": 1234,
    "snark-worker-fee": 5,
    "stop-time": 1000,
    "stop-time-interval": 3,
    "node-status-url": "http://127.0.0.1:9/status",
    "peers": ["'"$PEER"'"]
  }}'
  ARGS=(--max-connections 80); ENVS=()
}

scenario_config_file_precedence() {
  mkdir -p "$CONF"
  write_json "$CONF/daemon.json" '{"daemon": {"min-connections": 3, "stop-time": 11}}'
  write_json "$PWD/a.json" '{"daemon": {"min-connections": 4, "max-connections": 40}}'
  write_json "$PWD/b.json" '{"daemon": {"min-connections": null, "max-connections": 41}}'
  ARGS=(--seed --config-file "$PWD/a.json" --config-file "$PWD/b.json")
  ENVS=("MINA_CONFIG_FILE=$PWD/a.json")
}

scenario_config_int_wrong_type() {
  mkdir -p "$CONF"
  write_json "$CONF/daemon.json" '{"daemon": {"min-connections": "not-an-int"}}'
  ARGS=(--seed); ENVS=()
}

scenario_config_bool_wrong_type() {
  mkdir -p "$CONF"
  write_json "$CONF/daemon.json" '{"daemon": {"log-block-creation": "yes"}}'
  ARGS=(--seed); ENVS=()
}

scenario_config_port_wrong_type() {
  mkdir -p "$CONF"
  write_json "$CONF/daemon.json" '{"daemon": {"--client-port": "8301"}}'
  ARGS=(--seed); ENVS=()
}

scenario_config_work_selection_not_string() {
  mkdir -p "$CONF"
  write_json "$CONF/daemon.json" '{"daemon": {"work-selection": 5}}'
  ARGS=(--seed); ENVS=()
}

scenario_config_work_selection_overridden() {
  mkdir -p "$CONF"
  write_json "$CONF/daemon.json" '{"daemon": {"work-selection": 5}}'
  ARGS=(--seed --work-selection seq); ENVS=()
}

scenario_config_peers_not_list() {
  mkdir -p "$CONF"
  write_json "$CONF/daemon.json" '{"daemon": {"peers": "'"$PEER"'"}}'
  ARGS=(--seed); ENVS=()
}

scenario_config_pubsub_v0_bogus() {
  mkdir -p "$CONF"
  write_json "$CONF/daemon.json" '{"daemon": {"pubsub-v0": "bogus"}}'
  ARGS=(--seed); ENVS=()
}

scenario_config_negative_fee() {
  mkdir -p "$CONF"
  write_json "$CONF/daemon.json" '{"daemon": {"snark-worker-fee": -1}}'
  ARGS=(--seed); ENVS=()
}

scenario_config_bad_snark_worker_key() {
  mkdir -p "$CONF"
  write_json "$CONF/daemon.json" '{"daemon": {"run-snark-worker": "not-a-key"}}'
  ARGS=(--seed); ENVS=()
}

scenario_config_bad_snark_worker_key_overridden() {
  mkdir -p "$CONF"
  write_json "$CONF/daemon.json" '{"daemon": {"run-snark-worker": "not-a-key"}}'
  ARGS=(--seed --run-snark-worker "$BP_PUBKEY"); ENVS=()
}

scenario_bad_env_privkey() {
  ARGS=(--seed); ENVS=("MINA_BP_PRIVKEY=garbage")
}

scenario_env_privkey() {
  ARGS=(--seed); ENVS=("MINA_BP_PRIVKEY=$BP_PRIVKEY")
}

scenario_bp_key_file() {
  ARGS=(--seed --block-producer-key "$FIXTURES/bp-key")
  ENVS=("MINA_PRIVKEY_PASS=pw")
}

scenario_bp_key_file_wrong_password() {
  ARGS=(--seed --block-producer-key "$FIXTURES/bp-key")
  ENVS=("MINA_PRIVKEY_PASS=wrong")
}

scenario_bp_key_file_password_flag_conflict() {
  ARGS=(--seed --block-producer-key "$FIXTURES/bp-key"
    --block-producer-password other)
  ENVS=("MINA_PRIVKEY_PASS=pw")
}

scenario_bp_key_and_pubkey() {
  ARGS=(--seed --block-producer-key "$FIXTURES/bp-key"
    --block-producer-pubkey "$BP_PUBKEY")
  ENVS=()
}

scenario_bp_env_and_pubkey() {
  ARGS=(--seed --block-producer-pubkey "$BP_PUBKEY")
  ENVS=("MINA_BP_PRIVKEY=$BP_PRIVKEY")
}

scenario_bad_external_ip() { ARGS=(--seed --external-ip not-an-ip); ENVS=(); }

scenario_bad_bind_ip() {
  ARGS=(--seed --external-ip 127.0.0.1 --bind-ip not-an-ip); ENVS=()
}

scenario_client_trustlist_env() {
  ARGS=(--seed --external-ip 127.0.0.1)
  ENVS=("MINA_CLIENT_TRUSTLIST=10.0.0.0/8,not-a-cidr")
}

scenario_uptime_partial() {
  ARGS=(--seed --uptime-url http://127.0.0.1:9/uptime); ENVS=()
}

scenario_uptime_bad_pubkey() {
  ARGS=(--seed --uptime-url http://127.0.0.1:9/uptime
    --uptime-submitter-pubkey not-a-key)
  ENVS=()
}

scenario_no_peers_and_uptime_partial() {
  ARGS=(--uptime-url http://127.0.0.1:9/uptime); ENVS=()
}

scenario_no_peers_and_bad_env_privkey() {
  ARGS=(); ENVS=("MINA_BP_PRIVKEY=garbage")
}

ALL_SCENARIOS=$(declare -F | sed -n 's/^declare -f scenario_//p')

# --- Runner -----------------------------------------------------------------

run_one() {
  # run_one EXE LABEL SCENARIO
  local exe=$1 label=$2 scenario=$3
  local dir=$OUT/$label/$scenario
  rm -rf "$dir"
  mkdir -p "$dir"
  (
    cd "$dir"
    CONF=$dir/conf
    "scenario_$scenario"
    ARGS=(--config-file "$FIXTURES/genesis.json" "${ARGS[@]}")
    MINA_PROFILE=$MINA_PROFILE "$exe" version >"$dir/commit_id_raw" 2>&1 || true
    sed -n 's/^Commit //p' "$dir/commit_id_raw" >"$dir/commit_id"
    printf '%q ' "${ENVS[@]}" daemon --config-directory "$CONF" "${ARGS[@]}" \
      >"$dir/command"
    # TMPDIR is per run: the daemon creates its temporary ledger databases
    # under $TMPDIR/coda_cache_dir and does not remove them.
    mkdir -p "$dir/tmp"
    env -i PATH="$PATH" HOME="$dir/home" TMPDIR="$dir/tmp" \
      MINA_PROFILE="$MINA_PROFILE" "${ENVS[@]}" \
      setsid "$exe" daemon --config-directory "$CONF" "${ARGS[@]}" \
      >"$dir/stdout" 2>"$dir/stderr" &
    local pid=$!
    local waited=0 code=
    while kill -0 "$pid" 2>/dev/null; do
      if grep -q '"Creating daemon with commit id' "$CONF/mina.log" 2>/dev/null; then
        kill -9 -- "-$pid" 2>/dev/null || true
        break
      fi
      if (( waited >= TIMEOUT_SECS * 10 )); then
        echo "timeout" >"$dir/timed_out"
        kill -9 -- "-$pid" 2>/dev/null || true
        break
      fi
      sleep 0.1
      waited=$((waited + 1))
    done
    wait "$pid" && code=0 || code=$?
    echo "$code" >"$dir/exit_code"
    # Children (prover/verifier) share the session; make sure none linger.
    kill -9 -- "-$pid" 2>/dev/null || true
  )
  python3 -I "$HERE/normalise.py" "$dir"
  # Keep the logs, drop ledgers, crash-report tarballs and other bulk.
  rm -rf "$dir/tmp" "$dir/home"
  find "$dir/conf" -mindepth 1 -maxdepth 1 ! -name mina.log \
    -exec rm -rf {} + 2>/dev/null || true
}

SCENARIOS=("$@")
if [[ ${#SCENARIOS[@]} -eq 0 ]]; then
  read -r -a SCENARIOS <<<"$(echo $ALL_SCENARIOS)"
fi

JOBS=${JOBS:-4}
run_scenario_pair() {
  run_one "$BASE_EXE" old "$1"
  run_one "$NEW_EXE" new "$1"
}
export -f run_one run_scenario_pair
export OUT HERE TIMEOUT_SECS MINA_PROFILE BASE_EXE NEW_EXE FIXTURES PEER \
  BP_PUBKEY BP_PRIVKEY
for s in $ALL_SCENARIOS; do export -f "scenario_$s"; done
export -f write_json

printf '%s\n' "${SCENARIOS[@]}" |
  xargs -P "$JOBS" -I{} bash -c 'run_scenario_pair "$@"' _ {}

status=0
printf '%-48s %-16s %-16s %s\n' SCENARIO BASE NEW RESULT >"$OUT/summary"
for s in "${SCENARIOS[@]}"; do
  b=$(cat "$OUT/old/$s/outcome")
  n=$(cat "$OUT/new/$s/outcome")
  if diff -q "$OUT/old/$s/normalised" "$OUT/new/$s/normalised" >/dev/null; then
    r=identical
  else
    r=DIFFERENT
    status=1
    diff -u "$OUT/old/$s/normalised" "$OUT/new/$s/normalised" \
      >"$OUT/$s.diff" || true
  fi
  printf '%-48s %-16s %-16s %s\n' "$s" "$b" "$n" "$r" >>"$OUT/summary"
done
cat "$OUT/summary"
exit $status
