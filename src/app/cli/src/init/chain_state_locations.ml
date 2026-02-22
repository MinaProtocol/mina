open Core

(** The locations of the chain state in a daemon. These will be computed by
      [chain_state_locations] based on the runtime daemon config. By default,
      the [chain_state] will be located in the mina config directory and the
      other directories will be located in the [chain_state]. *)
type t =
  { chain_state : string  (** The top-level chain state directory *)
  ; mina_net : string  (** Mina networking information *)
  ; trust : string  (** P2P trust information *)
  ; root : string  (** The root snarked ledgers *)
  ; genesis : string  (** The genesis ledgers *)
  ; frontier : string  (** The transition frontier *)
  ; epoch_ledger : string  (** The epoch ledger snapshots *)
  ; proof_cache : string  (** The proof cache *)
  ; zkapp_vk_cache : string  (** The zkApp vk cache *)
  ; snark_pool : string  (** The snark pool *)
  }

(** Determine the locations of the chain state components based on the daemon
      runtime config *)
let of_config ~conf_dir (config : Runtime_config.t) : t =
  (* TODO: post hard fork, we should not be ignoring this *)
  let _config = config in
  let chain_state = conf_dir in
  { chain_state
  ; mina_net = chain_state ^/ "mina_net2"
  ; trust = chain_state ^/ "trust"
  ; root = chain_state ^/ "root"
  ; genesis = chain_state ^/ "genesis"
  ; frontier = chain_state ^/ "frontier"
  ; epoch_ledger = chain_state
  ; proof_cache = chain_state ^/ "proof_cache"
  ; zkapp_vk_cache = chain_state ^/ "zkapp_vk_cache"
  ; snark_pool = chain_state ^/ "snark_pool"
  }
