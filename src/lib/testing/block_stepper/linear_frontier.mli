type t

val create :
     precomputed_values:Precomputed_values.t
  -> context:(module Consensus.Intf.CONTEXT)
  -> keys_module:(module Block_builder.Keys_S)
  -> keypair:Signature_lib.Keypair.t
  -> logger:Logger.t
  -> state_dir:string
  -> unit
  -> t Async.Deferred.Or_error.t

val current : t -> Frontier_base.Breadcrumb.t

val precomputed_values : t -> Precomputed_values.t

val context : t -> (module Consensus.Intf.CONTEXT)

val consensus_local_state : t -> Consensus.Data.Local_state.t

val protocol_states :
  t -> Mina_state.Protocol_state.value Mina_base.State_hash.Map.t

val add_breadcrumb :
  t -> Frontier_base.Breadcrumb.t -> Frontier_base.Breadcrumb.t * t
