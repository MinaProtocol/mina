open Mina_base

val verify :
     target_hash:State_hash.t
  -> transition_chain_proof:State_hash.t * State_body_hash.t list
  -> State_hash.t Mina_stdlib.Nonempty_list.t option
