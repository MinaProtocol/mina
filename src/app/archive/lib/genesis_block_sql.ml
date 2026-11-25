(* genesis_block_sql.ml -- requests about the genesis block of --config-file
   (see Processor.add_genesis_block) *)

open Mina_caqti

let other_geneses_req =
  collect_req
    Caqti_type.(t2 int64 string)
    Caqti_type.string
    {sql| SELECT state_hash FROM blocks
          WHERE height = $1
            AND global_slot_since_hard_fork = 0
            AND state_hash <> $2
    |sql}

(** The state hashes of the genesis blocks (global slot since hard fork 0) at
    [genesis_height] other than [state_hash]: another config's, another
    network's. *)
let other_geneses (module Conn : CONNECTION) ~genesis_height ~state_hash =
  Conn.collect_list other_geneses_req (genesis_height, state_hash)
