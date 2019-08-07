open Coda_base

val verify :
     target_hash:State_hash.t
  -> transition_chain_witness:State_hash.t * State_body_hash.t list
  -> State_hash.t Non_empty_list.t option
