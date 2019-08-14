open Coda_base

val verify :
     target_hash:State_hash.t
  -> transition_chain_proof:State_hash.t * State_body_hash.t list
  -> State_hash.t Non_empty_list.t option
