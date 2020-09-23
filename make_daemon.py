import json
import datetime

d = datetime.datetime.utcnow()
d = d.isoformat("T") + "Z"

with open('./genesis_ledger.json') as f:
  ledger = json.load(f)

data = {
  "daemon": {},
  "genesis": {
    "genesis_state_timestamp": d,
    "k": 6,
    "delta": 3
  },
  "proof": {
    "c": 8
  },
  "ledger": ledger
}

with open('daemon.json', 'w') as outfile:
    json.dump(data, outfile)
