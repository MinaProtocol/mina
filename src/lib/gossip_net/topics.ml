(* topics.ml -- libp2p pub-sub topics *)

[%%import
"../../config.mlh"]

[%%ifdef
consensus_mechanism]

let consensus = "coda/consensus-messages/0.0.1"

[%%endif]

let block_headers = "coda/block-headers-messages/0.0.1"

let transactions = "coda/transactions-messages/0.0.1"

[%%ifdef
consensus_mechanism]

(* consensus nodes will publish to block_headers w/out subscribing *)
let all = [consensus]

[%%else]

let all = [block_headers; transactions]

[%%endif]
