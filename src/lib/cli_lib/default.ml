(* Default values for cli flags *)
let work_reassignment_wait = 420000

let min_connections = 20

let max_connections = 50

let validation_queue_size = 150

let conf_dir_name = ".mina-config"

let stop_time = 168

let receiver_key_warning =
  "Warning: Ensure this address is a non-zkApp account or has the permission \
   to receive funds set as None"

(* 24*7 hours*)

(* TODO uncomment after introducing Bitswap-based block retrieval *)
(* let pubsub_v1 = Gossip_net.Libp2p.RW *)

let pubsub_v0 = Gossip_net.Libp2p.RW
