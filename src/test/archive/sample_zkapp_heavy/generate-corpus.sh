#!/usr/bin/env bash
#
# Regenerate the zkApp-heavy precomputed-block corpus used by the archive-node
# memory benchmark. Bootstraps a small local network, submits heavy zkApp
# update-state transactions, then extracts and repackages the produced
# precomputed blocks into ./precomputed_blocks.tar.xz (next to this script).
#
# Prereqs (build first, inside `nix develop mina`):
#   dune build src/app/cli/src/mina.exe src/app/archive/archive.exe \
#     src/app/zkapp_test_transaction/zkapp_test_transaction.exe \
#     src/app/mina_graphql_client/mina_graphql_client_app.exe \
#     src/app/logproc/logproc.exe
#
# Usage: generate-corpus.sh [count] [num_events] [num_actions] [elements_per]
#   defaults: 120 20 20 8
#
set -uo pipefail
COUNT="${1:-120}"; NE="${2:-20}"; NA="${3:-20}"; EP="${4:-8}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../../.." && pwd)"
cd "$REPO"

BUILD="$REPO/_build/default"
ZK="$BUILD/src/app/zkapp_test_transaction/zkapp_test_transaction.exe"
GC="$BUILD/src/app/mina_graphql_client/mina_graphql_client_app.exe"
NET="${MINA_NETWORK_DIR:-$HOME/.mina-network}"
REST="${MINA_REST_URI:-http://127.0.0.1:4001/graphql}"
export MINA_PRIVKEY_PASS="${MINA_PRIVKEY_PASS:-naughty blue worm}"

# --- 1. bootstrap a small local network (future genesis avoids multi-node fork
#        stall; -pl none / long slots keep it light; requires the local-network
#        script's genesis-ledger padding to be fixed for block production) ------
echo "[gen] bootstrapping local network (2 whales)..."
scripts/mina-local-network/mina-local-network.sh \
    -c reset -w 2 -f 0 -n 0 -pl none -st 30000 -u delay_sec:180 -lp \
    > "$NET/localnet.log" 2>&1 &
NETPID=$!
trap 'kill $(jobs -p) 2>/dev/null || true' EXIT

wait_for_rest() {
  for _ in $(seq 1 120); do
    "$GC" account --graphql-uri "$REST" \
        --public-key "$(cat "$NET/offline_whale_keys/offline_whale_account_0.pub")" \
        >/dev/null 2>&1 && return 0
    sleep 10
  done
  echo "[gen] ERROR: network REST never came up"; exit 1
}
echo "[gen] waiting for the network (genesis is 180s in the future)..."
wait_for_rest

# --- 2. generate heavy zkApp load --------------------------------------------
FP="$NET/offline_whale_keys/offline_whale_account_0"
ZKA="$NET/zkapp_keys/zkapp_account"
mkdir -p "$NET/zkapp_keys"
if [ ! -f "$ZKA" ]; then
  "$BUILD/src/app/cli/src/mina.exe" advanced generate-keypair --privkey-path "$ZKA" >/dev/null 2>&1 || true
fi
FPPUB="$(cat "$FP.pub")"; ZKAPUB="$(cat "$ZKA.pub")"
nonce_of() { "$GC" account --graphql-uri "$REST" --public-key "$1" 2>/dev/null \
  | jq -rs '[.[]|.inferred_nonce]|map(select(.!=null))|last // "0"'; }
onchain() { "$GC" account --graphql-uri "$REST" --public-key "$ZKAPUB" 2>/dev/null \
  | jq -rs '(.[-1].total_balance // null) != null'; }

# Deploy the zkApp account using the SAME whale as fee-payer AND sender: with
# distinct keys create_zkapp_command sets the sender nonce precondition to
# succ(sender_nonce), which no external nonce satisfies.
if [ "$(onchain)" != "true" ]; then
  n=$(nonce_of "$FPPUB")
  echo "[gen] deploying zkApp account (fee-payer=sender nonce=$n)..."
  q=$("$ZK" create-zkapp-account --fee-payer-key "$FP" --nonce "$n" \
        --sender-key "$FP" --sender-nonce "$n" --receiver-amount 1000 \
        --zkapp-account-key "$ZKA" --fee 5 2>/dev/null | sed 1,7d)
  "$GC" send-raw --graphql-uri "$REST" --query "$q" >/dev/null 2>&1
  for _ in $(seq 1 40); do [ "$(onchain)" = "true" ] && break; sleep 15; done
  [ "$(onchain)" = "true" ] || { echo "[gen] ERROR: deploy never applied"; exit 1; }
fi

nonce=$(nonce_of "$FPPUB"); ok=0
echo "[gen] submitting $COUNT heavy update-states (events=$NE actions=$NA elems=$EP)..."
for ((i=0;i<COUNT;i++)); do
  q=$("$ZK" update-state --fee-payer-key "$FP" --nonce "$nonce" \
        --zkapp-account-key "$ZKA" --zkapp-state $(( (i%7)+1 )) \
        --num-events "$NE" --num-actions "$NA" --elements-per "$EP" --fee 5 2>/dev/null | sed 1,5d)
  h=$("$GC" send-raw --graphql-uri "$REST" --query "$q" 2>/dev/null | grep -o '"hash":"[^"]*"' | head -1)
  if [ -n "$h" ]; then ok=$((ok+1)); nonce=$((nonce+1)); else sleep 3; nonce=$(nonce_of "$FPPUB"); fi
  sleep 3
done
echo "[gen] submitted ok=$ok/$COUNT; waiting ~4min for the mempool to drain into blocks..."
sleep 240

# --- 3. extract + repackage ---------------------------------------------------
LOG="$NET/nodes/whale_0/precomputed_blocks.log"
[ -f "$LOG" ] || { echo "[gen] ERROR: no precomputed_blocks.log at $LOG"; exit 1; }
tmp=$(mktemp -d)
python3 - "$LOG" "$tmp" <<'PY'
import json, sys, os, hashlib
log, out = sys.argv[1], sys.argv[2]
seen=set(); rows=[]; zk=ev=ac=0
for ln in open(log, encoding="utf-8", errors="replace"):
    ln=ln.strip()
    if not ln: continue
    try: b=json.loads(ln)
    except: continue
    d=b.get("data", b)
    try: h=int(d["protocol_state"]["body"]["consensus_state"]["blockchain_length"])
    except: continue
    dig=hashlib.md5(ln.encode("utf-8","replace")).hexdigest()[:10]
    if dig in seen: continue
    seen.add(dig)
    for part in d.get("staged_ledger_diff",{}).get("diff",[]):
        if not part: continue
        for c in part.get("commands",[]):
            da=c.get("data")
            if isinstance(da,list) and da and da[0]=="Zkapp_command":
                zk+=1
                for au in da[1].get("account_updates",[]) or []:
                    body=au["elt"]["account_update"]["body"] if "elt" in au else au.get("body",{})
                    ev+=sum(len(x) for x in body.get("events",[]) or [])
                    ac+=sum(len(x) for x in body.get("actions",[]) or [])
    rows.append((h,dig,ln))
rows.sort(key=lambda r:(r[0],r[1]))
for h,dig,ln in rows:
    open(os.path.join(out,f"{h:07d}_{dig}.json"),"w",encoding="utf-8").write(ln)
print(f"[gen] extracted {len(rows)} blocks, {zk} zkApp cmds, {ev} event fields, {ac} action fields")
PY
tar cJf "$HERE/precomputed_blocks.tar.xz" -C "$tmp" .
rm -rf "$tmp"
echo "[gen] wrote $HERE/precomputed_blocks.tar.xz ($(du -h "$HERE/precomputed_blocks.tar.xz" | cut -f1))"
