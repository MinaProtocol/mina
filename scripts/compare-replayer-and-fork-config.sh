cat $1 | jq '.genesis_ledger.accounts | .[] | {pk: .pk, balance: .balance, delegate: .delegate, receipt_chain_hash: .receipt_chain_hash, voting_for: .voting_for, nonce: (.nonce // "0")}' > replayer_output.json
cat $2 | jq '.ledger.accounts | .[] | {pk: .pk, balance: .balance, delegate: .delegate, receipt_chain_hash: .receipt_chain_hash, voting_for: .voting_for, nonce: (.nonce // "0")}' > fork_output.json

diff replayer_output.json fork_output.json
