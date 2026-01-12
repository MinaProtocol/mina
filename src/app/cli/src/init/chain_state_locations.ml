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
let of_config ~logger ~signature_kind ~(genesis_constants : Genesis_constants.t)
    ~constraint_constants ~proof_level ~conf_dir (config : Runtime_config.t) :
    t * string Option.t =
  let chain_state = conf_dir in
  let chain_id_opt =
    let open Option.Let_syntax in
    let%bind genesis_constants =
      Genesis_ledger_helper.make_genesis_constants ~logger
        ~default:genesis_constants config
      |> Result.ok
    in
    let%bind constraint_constants =
      Option.map
        ~f:
          (Genesis_ledger_helper.make_constraint_constants
             ~default:constraint_constants )
        config.proof
    in
    let%map genesis_ledger, genesis_epoch_data = make_hashed_ledgers config in
    Genesis_ledger_helper.make_chain_id ~signature_kind ~genesis_constants
      ~constraint_constants ~proof_level ~genesis_ledger ~genesis_epoch_data
  in
  let config_modifier : string -> string =
    Option.value_map
      ~default:(ident : string -> string)
      ~f:(fun x s -> chain_state ^/ x ^/ s)
      chain_id_opt
  in
  ( { chain_state
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
  , chain_id_opt )
