open Core_kernel
open Async

let rec deferred_list_fold ~init ~f = function
  | [] ->
      Async.Deferred.Result.return init
  | h :: t ->
      let open Async.Deferred.Result.Let_syntax in
      let%bind init = f init h in
      deferred_list_fold ~init ~f t

module Json_layout = struct
  module Accounts = Runtime_config_v1.Json_layout.Accounts
  module Ledger = Runtime_config_v1.Json_layout.Ledger
  module Epoch_data = Runtime_config_v1.Json_layout.Epoch_data

  module Daemon = struct
    type t =
      { compile_config : Mina_compile_config.Inputs.t
      ; peer_list_url : string option
      }
    [@@deriving yojson]
  end

  module Constraint = struct
    type t =
      { constraint_constants : Genesis_constants.Constraint_constants.Inputs.t
      ; proof_level : string
      }
    [@@deriving yojson]
  end

  type t =
    { daemon : Daemon.t
    ; genesis : Genesis_constants.Inputs.t
    ; proof : Constraint.t
    ; ledger : Ledger.t
    ; epoch_data : Epoch_data.t option [@default None]
    }
  [@@deriving yojson]
end

module Daemon = struct
  type t =
    { compile_config : Mina_compile_config.t; peer_list_url : string option }
  [@@deriving to_yojson]

  let of_json_layout : Json_layout.Daemon.t -> t =
   fun { compile_config; peer_list_url } ->
    { compile_config = Mina_compile_config.make compile_config; peer_list_url }
end

module Constraint = struct
  type t =
    { constraint_constants : Genesis_constants.Constraint_constants.t
    ; proof_level : Genesis_constants.Proof_level.t
    }
  [@@deriving to_yojson]

  let of_json_layout : Json_layout.Constraint.t -> t =
   fun { constraint_constants; proof_level } ->
    { constraint_constants =
        Genesis_constants.Constraint_constants.make constraint_constants
    ; proof_level = Genesis_constants.Proof_level.of_string proof_level
    }
end

module Accounts = Runtime_config_v1.Accounts
module Ledger = Runtime_config_v1.Ledger
module Epoch_data = Runtime_config_v1.Epoch_data

type t =
  { daemon : Daemon.t
  ; genesis_constants : Genesis_constants.t
  ; proof : Constraint.t
  ; ledger : Runtime_config_v1.Ledger.t
  ; epoch_data : Runtime_config_v1.Epoch_data.t option
  }
[@@deriving to_yojson]

let format_as_json_without_accounts (x : t) =
  let genesis_accounts =
    let ({ accounts; _ } : Json_layout.Ledger.t) =
      Ledger.to_json_layout x.ledger
    in
    Option.map ~f:List.length accounts
  in
  let staking_accounts =
    let%bind.Option { staking; _ } = x.epoch_data in
    Option.map ~f:List.length (Ledger.to_json_layout staking.ledger).accounts
  in
  let next_accounts =
    let%bind.Option { next; _ } = x.epoch_data in
    let%bind.Option { ledger; _ } = next in
    Option.map ~f:List.length (Ledger.to_json_layout ledger).accounts
  in
  let f ledger =
    { (Ledger.to_json_layout ledger) with Json_layout.Ledger.accounts = None }
  in
  let g ({ staking; next } : Epoch_data.t) =
    { Json_layout.Epoch_data.staking =
        (let l = f staking.ledger in
         { accounts = None
         ; seed = staking.seed
         ; hash = l.hash
         ; s3_data_hash = l.s3_data_hash
         } )
    ; next =
        Option.map next ~f:(fun n ->
            let l = f n.ledger in
            { Json_layout.Epoch_data.Data.accounts = None
            ; seed = n.seed
            ; hash = l.hash
            ; s3_data_hash = l.s3_data_hash
            } )
    }
  in
  let json : Yojson.Safe.t =
    `Assoc
      [ ("daemon", Daemon.to_yojson x.daemon)
      ; ("genesis", Genesis_constants.to_yojson x.genesis_constants)
      ; ( "proof"
        , Genesis_constants.Constraint_constants.to_yojson
            x.proof.constraint_constants )
      ; ("ledger", Json_layout.Ledger.to_yojson @@ f x.ledger)
      ; ( "epoch_data"
        , Option.value_map ~default:`Null ~f:Json_layout.Epoch_data.to_yojson
            (Option.map ~f:g x.epoch_data) )
      ]
  in
  ( json
  , `Accounts_omitted
      (`Genesis genesis_accounts, `Staking staking_accounts, `Next next_accounts)
  )

let ledger_accounts (ledger : Mina_ledger.Ledger.Any_ledger.witness) =
  let open Async.Deferred.Result.Let_syntax in
  let yield = Async_unix.Scheduler.yield_every ~n:100 |> Staged.unstage in
  let%bind accounts =
    Mina_ledger.Ledger.Any_ledger.M.to_list ledger
    |> Async.Deferred.map ~f:Result.return
  in
  let%map accounts =
    deferred_list_fold ~init:[]
      ~f:(fun acc el ->
        let open Async.Deferred.Infix in
        let%bind () = yield () >>| Result.return in
        let%map elt = Accounts.Single.of_account el |> Async.Deferred.return in
        elt :: acc )
      accounts
  in
  List.rev accounts

let ledger_of_accounts accounts =
  Ledger.
    { base = Accounts accounts
    ; num_accounts = None
    ; balances = []
    ; hash = None
    ; s3_data_hash = None
    ; name = None
    ; add_genesis_winner = Some false
    }

let make_fork_config ~staged_ledger ~global_slot_since_genesis ~state_hash
    ~blockchain_length ~staking_ledger ~staking_epoch_seed ~next_epoch_ledger
    ~next_epoch_seed ~genesis_constants ~(proof : Constraint.t) ~daemon =
  let open Async.Deferred.Result.Let_syntax in
  let global_slot_since_genesis =
    Mina_numbers.Global_slot_since_genesis.to_int global_slot_since_genesis
  in
  let blockchain_length = Unsigned.UInt32.to_int blockchain_length in
  let yield () =
    let open Async.Deferred.Infix in
    Async_unix.Scheduler.yield () >>| Result.return
  in
  let%bind () = yield () in
  let%bind accounts =
    Mina_ledger.Ledger.Any_ledger.cast (module Mina_ledger.Ledger) staged_ledger
    |> ledger_accounts
  in
  let hash =
    Option.some @@ Mina_base.Ledger_hash.to_base58_check
    @@ Mina_ledger.Ledger.merkle_root staged_ledger
  in
  let fork =
    Genesis_constants.Fork_constants.
      { state_hash
      ; blockchain_length = Mina_numbers.Length.of_int blockchain_length
      ; global_slot_since_genesis =
          Mina_numbers.Global_slot_since_genesis.of_int
            global_slot_since_genesis
      }
  in
  let%bind () = yield () in
  let%bind staking_ledger_accounts = ledger_accounts staking_ledger in
  let%bind () = yield () in
  let%map next_epoch_ledger_accounts =
    match next_epoch_ledger with
    | None ->
        return None
    | Some l ->
        ledger_accounts l >>| Option.return
  in
  let epoch_data =
    let open Epoch_data in
    let open Data in
    { staking =
        { ledger = ledger_of_accounts staking_ledger_accounts
        ; seed = staking_epoch_seed
        }
    ; next =
        Option.map next_epoch_ledger_accounts ~f:(fun accounts ->
            { ledger = ledger_of_accounts accounts; seed = next_epoch_seed } )
    }
  in
  { (* add_genesis_winner must be set to false, because this
       config effectively creates a continuation of the current
       blockchain state and therefore the genesis ledger already
       contains the winner of the previous block. No need to
       artificially add it. In fact, it wouldn't work at all,
       because the new node would try to create this account at
       startup, even though it already exists, leading to an error.*)
    epoch_data = Some epoch_data
  ; ledger =
      { Ledger.base = Accounts accounts
      ; num_accounts = None
      ; balances = []
      ; hash
      ; s3_data_hash = None
      ; name = None
      ; add_genesis_winner = Some false
      }
  ; proof =
      { proof with
        constraint_constants =
          { proof.constraint_constants with fork = Some fork }
      }
  ; genesis_constants
  ; daemon
  }

type constants =
  { genesis_constants : Genesis_constants.t
  ; proof : Constraint.t
  ; compile_config : Mina_compile_config.t
  }

module type Config_loader = sig
  val load_config :
       ?itn_features:bool
    -> ?cli_proof_level:Genesis_constants.Proof_level.t
    -> config_file:string
    -> unit
    -> t Deferred.Or_error.t

  val load_config_exn :
       ?itn_features:bool
    -> ?cli_proof_level:Genesis_constants.Proof_level.t
    -> config_file:string
    -> unit
    -> t Deferred.t

  val load_constants :
       ?cli_proof_level:Genesis_constants.Proof_level.t
    -> config_file:string
    -> unit
    -> constants Deferred.Or_error.t

  val load_constants_exn :
       ?cli_proof_level:Genesis_constants.Proof_level.t
    -> config_file:string
    -> unit
    -> constants Deferred.t

  val of_json_layout : Json_layout.t -> (t, string) Result.t

  val merge_json : Yojson.Safe.t -> Yojson.Safe.t -> (Yojson.Safe.t,string) result
end

module Config_loader : Config_loader = struct
  module Compiled = struct
    type t =
      { genesis_constants : Genesis_constants.Inputs.t
      ; constraint_constants : Genesis_constants.Constraint_constants.Inputs.t
      ; proof_level : string
      ; compile_config : Mina_compile_config.Inputs.t
      }

    let constants : t =
      let genesis_constants : Genesis_constants.Inputs.t =
        { genesis_state_timestamp = Node_config.genesis_state_timestamp
        ; k = Node_config.k
        ; slots_per_epoch = Node_config.slots_per_epoch
        ; slots_per_sub_window = Node_config.slots_per_sub_window
        ; grace_period_slots = Node_config.grace_period_slots
        ; delta = Node_config.delta
        ; pool_max_size = Node_config.pool_max_size
        ; num_accounts = None
        ; zkapp_proof_update_cost = Node_config.zkapp_proof_update_cost
        ; zkapp_signed_single_update_cost =
            Node_config.zkapp_signed_single_update_cost
        ; zkapp_signed_pair_update_cost =
            Node_config.zkapp_signed_pair_update_cost
        ; zkapp_transaction_cost_limit =
            Node_config.zkapp_transaction_cost_limit
        ; max_event_elements = Node_config.max_event_elements
        ; max_action_elements = Node_config.max_action_elements
        ; zkapp_cmd_limit_hardcap = Node_config.zkapp_cmd_limit_hardcap
        ; minimum_user_command_fee = Node_config.minimum_user_command_fee
        }
      in
      let constraint_constants : Genesis_constants.Constraint_constants.Inputs.t
          =
        { scan_state_with_tps_goal = Node_config.scan_state_with_tps_goal
        ; scan_state_tps_goal_x10 = Node_config.scan_state_tps_goal_x10
        ; block_window_duration = Node_config.block_window_duration
        ; scan_state_transaction_capacity_log_2 =
            Node_config.scan_state_transaction_capacity_log_2
        ; supercharged_coinbase_factor =
            Node_config.supercharged_coinbase_factor
        ; scan_state_work_delay = Node_config.scan_state_work_delay
        ; coinbase = Node_config.coinbase
        ; account_creation_fee_int = Node_config.account_creation_fee_int
        ; ledger_depth = Node_config.ledger_depth
        ; sub_windows_per_window = Node_config.sub_windows_per_window
        ; fork = None
        }
      in
      let proof_level = Node_config.proof_level in
      let compile_config : Mina_compile_config.Inputs.t =
        { curve_size = Node_config.curve_size
        ; default_transaction_fee_string = Node_config.default_transaction_fee
        ; default_snark_worker_fee_string = Node_config.default_snark_worker_fee
        ; minimum_user_command_fee_string = Node_config.minimum_user_command_fee
        ; itn_features = Node_config.itn_features
        ; compaction_interval_ms = Node_config.compaction_interval
        ; block_window_duration_ms = Node_config.block_window_duration
        ; vrf_poll_interval_ms = Node_config.vrf_poll_interval
        ; rpc_handshake_timeout_sec = Node_config.rpc_handshake_timeout_sec
        ; rpc_heartbeat_timeout_sec = Node_config.rpc_heartbeat_timeout_sec
        ; rpc_heartbeat_send_every_sec =
            Node_config.rpc_heartbeat_send_every_sec
        ; zkapp_proof_update_cost = Node_config.zkapp_proof_update_cost
        ; zkapp_signed_pair_update_cost =
            Node_config.zkapp_signed_pair_update_cost
        ; zkapp_signed_single_update_cost =
            Node_config.zkapp_signed_single_update_cost
        ; zkapp_transaction_cost_limit =
            Node_config.zkapp_transaction_cost_limit
        ; max_event_elements = Node_config.max_event_elements
        ; max_action_elements = Node_config.max_action_elements
        ; network_id = Node_config.network
        ; zkapp_cmd_limit = Node_config.zkapp_cmd_limit
        ; zkapp_cmd_limit_hardcap = Node_config.zkapp_cmd_limit_hardcap
        ; zkapps_disabled = Node_config.zkapps_disabled
        ; slot_chain_end = None
        ; slot_tx_end = None
        }
      in
      { genesis_constants; constraint_constants; proof_level; compile_config }

    let combine (a : t) (b : Runtime_config_v1.Json_layout.t) : t =
      let genesis_constants =
        { a.genesis_constants with
          k =
            Option.value ~default:a.genesis_constants.k
              Option.(b.genesis >>= fun b -> b.k)
        ; delta =
            Option.value ~default:a.genesis_constants.delta
              Option.(b.genesis >>= fun b -> b.delta)
        ; slots_per_epoch =
            Option.value ~default:a.genesis_constants.slots_per_epoch
              Option.(b.genesis >>= fun b -> b.slots_per_epoch)
        ; slots_per_sub_window =
            Option.value ~default:a.genesis_constants.slots_per_sub_window
              Option.(b.genesis >>= fun b -> b.slots_per_sub_window)
        ; grace_period_slots =
            Option.value ~default:a.genesis_constants.grace_period_slots
              Option.(b.genesis >>= fun b -> b.grace_period_slots)
        ; genesis_state_timestamp =
            Option.value ~default:a.genesis_constants.genesis_state_timestamp
              Option.(b.genesis >>= fun b -> b.genesis_state_timestamp)
        ; pool_max_size =
            Option.value ~default:a.genesis_constants.pool_max_size
              Option.(b.daemon >>= fun b -> b.txpool_max_size)
        }
      in
      let constraint_constants =
        let fork : Genesis_constants.Fork_constants.Inputs.t option =
          match a.constraint_constants.fork with
          | None ->
              None
          | Some a ->
              Some
                { state_hash =
                    Option.value ~default:a.state_hash
                      Option.(
                        b.proof
                        >>= fun b -> map ~f:(fun b -> b.state_hash) b.fork)
                ; blockchain_length =
                    Option.value ~default:a.blockchain_length
                      Option.(
                        b.proof
                        >>= fun b ->
                        map ~f:(fun b -> b.blockchain_length) b.fork)
                ; global_slot_since_genesis =
                    Option.value ~default:a.global_slot_since_genesis
                      Option.(
                        b.proof
                        >>= fun b ->
                        map ~f:(fun b -> b.global_slot_since_genesis) b.fork)
                }
        in

        { a.constraint_constants with
          sub_windows_per_window =
            Option.value ~default:a.constraint_constants.sub_windows_per_window
              Option.(b.proof >>= fun b -> b.sub_windows_per_window)
        ; ledger_depth =
            Option.value ~default:a.constraint_constants.ledger_depth
              Option.(b.proof >>= fun b -> b.ledger_depth)
        ; scan_state_work_delay =
            Option.value ~default:a.constraint_constants.scan_state_work_delay
              Option.(b.proof >>= fun b -> b.work_delay)
        ; block_window_duration =
            Option.value ~default:a.constraint_constants.block_window_duration
              Option.(b.proof >>= fun b -> b.block_window_duration_ms)
        ; scan_state_transaction_capacity_log_2 =
            Option.value
              ~default:
                a.constraint_constants.scan_state_transaction_capacity_log_2
              Option.(
                b.proof
                >>= fun b -> b.transaction_capacity >>= fun b -> Some b.log_2)
        ; coinbase =
            Option.value ~default:a.constraint_constants.coinbase
              Option.(
                b.proof
                >>= fun b ->
                map ~f:Currency.Amount.to_mina_string b.coinbase_amount)
        ; supercharged_coinbase_factor =
            Option.value
              ~default:a.constraint_constants.supercharged_coinbase_factor
              Option.(b.proof >>= fun b -> b.supercharged_coinbase_factor)
        ; account_creation_fee_int =
            Option.value
              ~default:a.constraint_constants.account_creation_fee_int
              Option.(
                b.proof
                >>= fun b ->
                map ~f:Currency.Fee.to_mina_string b.account_creation_fee)
        ; fork
        }
      in
      let proof_level =
        Option.value ~default:a.proof_level
          Option.(b.proof >>= fun b -> b.level)
      in
      let compile_config =
        { a.compile_config with
          zkapp_proof_update_cost =
            Option.value ~default:a.compile_config.zkapp_proof_update_cost
              Option.(b.daemon >>= fun b -> b.zkapp_proof_update_cost)
        ; zkapp_signed_single_update_cost =
            Option.value
              ~default:a.compile_config.zkapp_signed_single_update_cost
              Option.(b.daemon >>= fun b -> b.zkapp_signed_single_update_cost)
        ; zkapp_signed_pair_update_cost =
            Option.value ~default:a.compile_config.zkapp_signed_pair_update_cost
              Option.(b.daemon >>= fun b -> b.zkapp_signed_pair_update_cost)
        ; zkapp_transaction_cost_limit =
            Option.value ~default:a.compile_config.zkapp_transaction_cost_limit
              Option.(b.daemon >>= fun b -> b.zkapp_transaction_cost_limit)
        ; max_event_elements =
            Option.value ~default:a.compile_config.max_event_elements
              Option.(b.daemon >>= fun b -> b.max_event_elements)
        ; max_action_elements =
            Option.value ~default:a.compile_config.max_action_elements
              Option.(b.daemon >>= fun b -> b.max_action_elements)
        ; slot_tx_end =
            Option.value ~default:a.compile_config.slot_tx_end
              Option.(b.daemon >>= fun b -> Some b.slot_tx_end)
        ; slot_chain_end =
            Option.value ~default:a.compile_config.slot_chain_end
              Option.(b.daemon >>= fun b -> Some b.slot_chain_end)
        ; minimum_user_command_fee_string =
            Option.value
              ~default:a.compile_config.minimum_user_command_fee_string
              Option.(
                b.daemon
                >>= fun b ->
                map ~f:Currency.Fee.to_mina_string b.minimum_user_command_fee)
        ; network_id =
            Option.value ~default:a.compile_config.network_id
              Option.(b.daemon >>= fun b -> b.network_id)
        }
      in
      { genesis_constants; constraint_constants; proof_level; compile_config }
  end

  (* right-biased merging of json values *)
  let rec merge_json (a : Yojson.Safe.t) (b : Yojson.Safe.t) : (Yojson.Safe.t,string) result =
    let module T = Monad_lib.Make_ext2(Result) in
    let open Result.Let_syntax in
    match (a, b) with
    | (`Assoc obj_a, `Assoc obj_b) ->
        Result.map ~f:(fun kvs -> `Assoc (List.rev kvs)) @@ 
          T.fold_m ~f:(fun acc (key, value) ->
              let%bind merged_value =
                match List.find ~f:(fun (key',_) -> String.equal key key') obj_a with
                | Some (_,value') -> merge_json value' value
                | None -> Result.return value
              in Result.return @@ (key, merged_value) :: 
                (List.filter ~f:(fun (x,_) -> String.(key <> x)) acc)
            ) ~init:obj_a obj_b
    | (`List _, `List _) -> Result.return b
    | (`Bool _, `Bool _) -> Result.return b
    | (`Int _, `Int _) -> Result.return b
    | (`Float _, `Float _) -> Result.return b
    | (`String _, `String _) -> Result.return b
    (*Null values overwrites anything*)
    | (_, `Null) -> Result.return `Null
    (*Anything overwrites a Null value*)
    | (`Null, _) -> Result.return b
    | (a,b) -> Error (sprintf "Cannot merge %s and %s" (Yojson.Safe.to_string a) (Yojson.Safe.to_string b))

  let%test_module _ = (module struct
      let assert_equal a b =
        if not (Yojson.Safe.equal a b) then
          failwithf "Expected %s but got %s" (Yojson.Safe.pretty_to_string a) (Yojson.Safe.pretty_to_string b) () 
  
      let%test_unit "simple object union" =
        let json1 = `Assoc [("a", `Int 1); ("b", `Int 2)] in
        let json2 = `Assoc [("c", `Int 3); ("d", `Int 4)] in
        let expected = `Assoc [("a", `Int 1); ("b", `Int 2); ("c", `Int 3); ("d", `Int 4)] in
        assert_equal (merge_json json1 json2 |> Result.ok_or_failwith) expected

      let%test_unit "simple object overwrite" =
          let json1 = `Assoc [("a", `Int 1)] in
          let json2 = `Assoc [("a", `Int 2)] in
          let expected = `Assoc [("a", `Int 2)] in
          assert_equal (merge_json json1 json2 |> Result.ok_or_failwith) expected
  
      let%test_unit "nested object union" =
        let json1 = `Assoc [("a", `Assoc [("b", `Int 1)])] in
        let json2 = `Assoc [("a", `Assoc [("c", `Int 2)])] in
        let expected = `Assoc [("a", `Assoc [("b", `Int 1); ("c", `Int 2)])] in
        assert_equal (merge_json json1 json2 |> Result.ok_or_failwith) expected

      let%test_unit "nested object overwrite" =
        let json1 = `Assoc [("a", `Assoc [("b", `Int 1)])] in
        let json2 = `Assoc [("a", `Assoc [("b", `Int 2)])] in
        let expected = `Assoc [("a", `Assoc [("b", `Int 2)])] in
        assert_equal (merge_json json1 json2 |> Result.ok_or_failwith) expected


      let%test_unit "Null values get overridden" = 
        let json1 = `Assoc [("a", `Int 1); ("b", `Null)] in
        let json1' = `Assoc [("a", `Int 1)] in
        let json2 = `Assoc [("a", `Int 2); ("b", `Int 3)] in
        let expected = `Assoc [("a", `Int 2); ("b", `Int 3)] in
        let result = merge_json json1 json2 |> Result.ok_or_failwith in
        let result' = merge_json json1' json2 |> Result.ok_or_failwith in
        assert_equal expected result;
        assert_equal expected result'

    end)

  let load_json_files (files : string Mina_stdlib.Nonempty_list.t) : Yojson.Safe.t Deferred.t =
    let module T = Monad_lib.Make_ext(Deferred) in
    let open Deferred.Let_syntax in
    let read_json_file x = 
      Reader.file_contents x |> Deferred.map ~f:Yojson.Safe.from_string
    in
    let (file,rest) = Mina_stdlib.Nonempty_list.uncons files in
    let%bind init = read_json_file file in
    let f acc filename = 
        let%bind json = read_json_file filename in
        match merge_json acc json with 
        | Error e -> Deferred.Or_error.error_string e |> Deferred.Or_error.ok_exn
        | Ok x -> Deferred.return x 
    in T.fold_m ~f ~init rest


  let load_constants ?(cli_proof_level : Genesis_constants.Proof_level.t option)
      ~config_file () : constants Deferred.Or_error.t =
    let open Deferred.Or_error.Let_syntax in
    let%bind json =
      Monitor.try_with_or_error (fun () ->
          Deferred.map ~f:Yojson.Safe.from_string
          @@ Reader.file_contents config_file )
    in
    match Runtime_config_v1.Json_layout.of_yojson json with
    | Ok config ->
        let a = Compiled.combine Compiled.constants config in
        Deferred.Or_error.return
          { genesis_constants = Genesis_constants.make a.genesis_constants
          ; compile_config = Mina_compile_config.make a.compile_config
          ; proof =
              { constraint_constants =
                  Genesis_constants.Constraint_constants.make
                    a.constraint_constants
              ; proof_level =
                  Option.value
                    ~default:
                      (Genesis_constants.Proof_level.of_string a.proof_level)
                    cli_proof_level
              }
          }
    | Error e ->
        Deferred.Or_error.error_string e

  let load_constants_exn ?cli_proof_level ~config_file () =
    Deferred.Or_error.ok_exn @@ load_constants ?cli_proof_level ~config_file ()


  let load_config_json filename : Json_layout.t Deferred.Or_error.t =
    let open Deferred.Or_error.Let_syntax in
    let module T = Monad_lib.Make_ext(Deferred.Or_error) in
    let%bind json =
      Monitor.try_with_or_error (fun () ->
          Deferred.map ~f:Yojson.Safe.from_string
          @@ Reader.file_contents filename )
    in
    match Runtime_config_v1.Json_layout.of_yojson json with
    | Ok config ->
        let a = Compiled.combine Compiled.constants config in
        let config =
          { Json_layout.daemon =
              { compile_config = a.compile_config
              ; peer_list_url =
                  Option.(config.daemon >>= fun x -> x.peer_list_url)
              }
          ; genesis = a.genesis_constants
          ; proof =
              { constraint_constants = a.constraint_constants
              ; proof_level = a.proof_level
              }
          ; ledger =
              ( match config.ledger with
              | Some ledger ->
                  ledger
              | None ->
                  failwithf "ledger not found in %s" filename () )
          ; epoch_data = config.epoch_data
          }
        in
        Deferred.Or_error.return config
    | Error e ->
        Deferred.Or_error.error_string e

  let of_json_layout (config : Json_layout.t) : (t, string) result =
    let open Result.Let_syntax in
    let proof = Constraint.of_json_layout config.proof in
    let genesis_constants = Genesis_constants.make config.genesis in
    let daemon = Daemon.of_json_layout config.daemon in
    let%bind ledger = Ledger.of_json_layout config.ledger in
    let%map epoch_data =
      match config.epoch_data with
      | None ->
          Ok None
      | Some conf ->
          Epoch_data.of_json_layout conf |> Result.map ~f:Option.some
    in
    { proof; genesis_constants; daemon; ledger; epoch_data }

  let load_config ?(itn_features = false) ?cli_proof_level ~config_file () =
    let open Deferred.Or_error.Let_syntax in
    let%bind config = load_config_json config_file in
    let e_config = of_json_layout config in
    match e_config with
    | Ok config ->
        let { Constraint.proof_level; _ } = config.proof in
        Deferred.Or_error.return
          { config with
            proof =
              { config.proof with
                proof_level = Option.value ~default:proof_level cli_proof_level
              }
          ; daemon =
              { config.daemon with
                compile_config =
                  { config.daemon.compile_config with itn_features }
              }
          }
    | Error e ->
        Deferred.Or_error.error_string e

  let load_config_exn ?itn_features ?cli_proof_level ~config_file () =
    Deferred.Or_error.ok_exn
    @@ load_config ?itn_features ?cli_proof_level ~config_file ()
end
