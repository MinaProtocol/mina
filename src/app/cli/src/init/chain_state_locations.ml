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

module Genesis_data = Consensus.Genesis_data

let make_hashed_ledgers (config : Runtime_config.t) :
    (Genesis_data.Hashed.t * Genesis_data.Hashed.t Genesis_data.Epoch.t) option
    =
  let open Option.Let_syntax in
  (* tries to pull out
      - genesis ledger as Hashed.t
      - epoch data as
          { staking: { ledger: Hashed.t, seed: Fp.t }
          , next: { ledger: Hashed.t, seed: Fp.t } option
          }
  *)
  let%map genesis_ledger, opt_epoch_data =
    let%bind genesis_ledger = config.ledger >>= fun x -> x.hash in
    let%map epoch_ledger =
      let%bind epoch_data = config.epoch_data in
      let%map staking_ledger =
        epoch_data.staking.ledger.hash >>| fun x -> (x, epoch_data.staking.seed)
      in
      let%map next_ledger =
        Option.map
          ~f:(fun x -> x.ledger.hash >>| fun y -> (y, x.seed))
          epoch_data.next
      in
      (staking_ledger, next_ledger)
    in
    (genesis_ledger, epoch_ledger)
  in
  let genesis_ledger =
    { Genesis_data.Hashed.hash =
        Mina_base.Frozen_ledger_hash.of_base58_check_exn genesis_ledger
    ; total_currency = Currency.Amount.zero
    }
  in
  let epoch_data =
    Option.map opt_epoch_data
      ~f:(fun
           ((staking, staking_seed), opt_next)
           :
           Genesis_data.Hashed.t Genesis_data.Epoch.tt
         ->
        { staking =
            { ledger =
                { Genesis_data.Hashed.hash =
                    Mina_base.Frozen_ledger_hash.of_base58_check_exn staking
                ; total_currency = Currency.Amount.zero
                }
                (* TODO: check if this of_string is right *)
            ; seed = Mina_base.Epoch_seed.of_base58_check_exn staking_seed
            }
        ; next =
            Option.map opt_next ~f:(fun (next, next_seed) ->
                { Genesis_data.Epoch.Data.ledger =
                    { Genesis_data.Hashed.hash =
                        Mina_base.Frozen_ledger_hash.of_base58_check_exn next
                    ; total_currency = Currency.Amount.zero
                    }
                    (* TODO: check if this of_string is right *)
                ; seed = Mina_base.Epoch_seed.of_base58_check_exn next_seed
                } )
        } )
  in
  (genesis_ledger, epoch_data)

(** Determine the locations of the chain state components based on the daemon
      runtime config *)
let of_config ~signature_kind ~(genesis_constants : Genesis_constants.t)
    ~constraint_constants ~proof_level ~conf_dir (config : Runtime_config.t) : t
    =
  let chain_state = conf_dir in
  let config_modifier =
    Option.value_map
      (make_hashed_ledgers config)
      ~default:(fun x -> chain_state ^/ x)
      ~f:(fun (genesis, epoch) ->
        let chain_id =
          let consensus_constants =
            Consensus.Constants.create ~constraint_constants
              ~protocol_constants:genesis_constants.protocol
          in
          let protocol_state_with_hashes =
            Mina_state.Genesis_protocol_state.t ~genesis_ledger:genesis
              ~genesis_epoch_data:epoch ~constraint_constants
              ~consensus_constants
              ~genesis_body_reference:Staged_ledger_diff.genesis_body_reference
          in
          let inputs =
            { Mina_base.Chain_id.Inputs.genesis_state_hash =
                protocol_state_with_hashes.hash.state_hash
            ; genesis_constants
            ; constraint_system_digests =
                Lazy.force
                @@ Genesis_proof.constraint_system_digests ~signature_kind
                     ~proof_level ~constraint_constants
            ; protocol_transaction_version =
                Protocol_version.(transaction current)
            ; protocol_network_version = Protocol_version.(network current)
            }
          in
          Mina_base.Chain_id.make inputs
        in
        fun x -> chain_state ^/ chain_id ^/ x )
  in
  { chain_state
  ; mina_net = config_modifier "mina_net2"
  ; trust = config_modifier "trust"
  ; root = config_modifier "root"
  ; genesis = config_modifier "genesis"
  ; frontier = config_modifier "frontier"
  ; epoch_ledger = chain_state
  ; proof_cache = config_modifier "proof_cache"
  ; zkapp_vk_cache = config_modifier "zkapp_vk_cache"
  ; snark_pool = config_modifier "snark_pool"
  }
