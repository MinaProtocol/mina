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

let of_json_layout (json : Json_layout.t) : (t, string) result =
  let open Result.Let_syntax in
  let daemon = Daemon.of_json_layout json.daemon in
  let genesis_constants = Genesis_constants.make json.genesis in
  let proof = Constraint.of_json_layout json.proof in
  let%bind ledger = Ledger.of_json_layout json.ledger in
  let%map epoch_data =
    match json.epoch_data with
    | None ->
        Ok None
    | Some epoch_data ->
        Epoch_data.of_json_layout epoch_data |> Result.map ~f:Option.some
  in
  { daemon; genesis_constants; proof; ledger; epoch_data }

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

module type Json_loader_intf = sig
  val load_config_files :
       ?conf_dir:string
    -> ?commit_id_short:string
    -> logger:Logger.t
    -> string list
    -> Yojson.Safe.t Deferred.Or_error.t
end

module Json_loader : Json_loader_intf = struct
  (* Right biased recursively merge of two json values 'a' and 'b'. Used to handle cases where we allow providing
      multiple configuration files with the assumption that the later files will overwrite the earlier ones.
     See test cases for examples
  *)
  let rec merge_json (a : Yojson.Safe.t) (b : Yojson.Safe.t) :
      (Yojson.Safe.t, string) result =
    let module T = Monad_lib.Make_ext2 (Result) in
    let open Result.Let_syntax in
    match (a, b) with
    | `Assoc obj_a, `Assoc obj_b ->
        Result.map ~f:(fun kvs -> `Assoc (List.rev kvs))
        @@ T.fold_m
             ~f:(fun acc (key, value) ->
               let%bind merged_value =
                 match
                   List.find ~f:(fun (key', _) -> String.equal key key') obj_a
                 with
                 | Some (_, value') ->
                     merge_json value' value
                 | None ->
                     Result.return value
               in
               Result.return
               @@ (key, merged_value)
                  :: List.filter ~f:(fun (x, _) -> String.(key <> x)) acc )
             ~init:obj_a obj_b
    | `List _, `List _ ->
        Result.return b
    | `Bool _, `Bool _ ->
        Result.return b
    | `Int _, `Int _ ->
        Result.return b
    | `Float _, `Float _ ->
        Result.return b
    | `String _, `String _ ->
        Result.return b
    (*Null values overwrites anything*)
    | _, `Null ->
        Result.return `Null
    (*Anything overwrites a Null value*)
    | `Null, _ ->
        Result.return b
    | a, b ->
        Error
          (sprintf "Cannot merge %s and %s" (Yojson.Safe.to_string a)
             (Yojson.Safe.to_string b) )

  let%test_module _ =
    ( module struct
      let assert_equal a b =
        if not (Yojson.Safe.equal a b) then
          failwithf "Expected %s but got %s"
            (Yojson.Safe.pretty_to_string a)
            (Yojson.Safe.pretty_to_string b)
            ()

      let%test_unit "simple object union" =
        let json1 = `Assoc [ ("a", `Int 1); ("b", `Int 2) ] in
        let json2 = `Assoc [ ("c", `Int 3); ("d", `Int 4) ] in
        let expected =
          `Assoc [ ("a", `Int 1); ("b", `Int 2); ("c", `Int 3); ("d", `Int 4) ]
        in
        assert_equal (merge_json json1 json2 |> Result.ok_or_failwith) expected

      let%test_unit "simple object overwrite" =
        let json1 = `Assoc [ ("a", `Int 1) ] in
        let json2 = `Assoc [ ("a", `Int 2) ] in
        let expected = `Assoc [ ("a", `Int 2) ] in
        assert_equal (merge_json json1 json2 |> Result.ok_or_failwith) expected

      let%test_unit "nested object union" =
        let json1 = `Assoc [ ("a", `Assoc [ ("b", `Int 1) ]) ] in
        let json2 = `Assoc [ ("a", `Assoc [ ("c", `Int 2) ]) ] in
        let expected =
          `Assoc [ ("a", `Assoc [ ("b", `Int 1); ("c", `Int 2) ]) ]
        in
        assert_equal (merge_json json1 json2 |> Result.ok_or_failwith) expected

      let%test_unit "nested object overwrite" =
        let json1 = `Assoc [ ("a", `Assoc [ ("b", `Int 1) ]) ] in
        let json2 = `Assoc [ ("a", `Assoc [ ("b", `Int 2) ]) ] in
        let expected = `Assoc [ ("a", `Assoc [ ("b", `Int 2) ]) ] in
        assert_equal (merge_json json1 json2 |> Result.ok_or_failwith) expected

      let%test_unit "Null values get overridden" =
        let json1 = `Assoc [ ("a", `Int 1); ("b", `Null) ] in
        let json1' = `Assoc [ ("a", `Int 1) ] in
        let json2 = `Assoc [ ("a", `Int 2); ("b", `Int 3) ] in
        let expected = `Assoc [ ("a", `Int 2); ("b", `Int 3) ] in
        let result = merge_json json1 json2 |> Result.ok_or_failwith in
        let result' = merge_json json1' json2 |> Result.ok_or_failwith in
        assert_equal expected result ;
        assert_equal expected result'
    end )

  let get_magic_config_files ?conf_dir ?commit_id_short () =
    let config_file_configdir =
      Option.map
        ~f:(fun dir -> (Core.(dir ^/ "daemon.json"), `May_be_missing))
        conf_dir
    in
    (* Search for config files installed as part of a deb/brew package.
       These files are commit-dependent, to ensure that we don't clobber
       configuration for dev builds or use incompatible configs.
    *)
    let config_file_installed =
      let f commit_id_short =
        let json = "config_" ^ commit_id_short ^ ".json" in
        List.fold_until ~init:None
          (Cache_dir.possible_paths json)
          ~f:(fun _acc f ->
            match Core.Sys.file_exists f with
            | `Yes ->
                Stop (Some (f, `Must_exist))
            | _ ->
                Continue None )
          ~finish:Fn.id
      in
      Option.(commit_id_short >>= f)
    in
    let config_file_envvar =
      match Sys.getenv "MINA_CONFIG_FILE" with
      | Some config_file ->
          Some (config_file, `Must_exist)
      | None ->
          None
    in
    List.filter_opt
      [ config_file_installed; config_file_configdir; config_file_envvar ]

  let read_files ~logger config_files : Yojson.Safe.t list Deferred.t =
    let module T = Monad_lib.Make_ext (Deferred) in
    let f (config_file, s) =
      let%bind e_contents =
        Monitor.try_with_or_error (fun () -> Reader.file_contents config_file)
      in
      match e_contents with
      | Ok a ->
          Deferred.return (Some (Yojson.Safe.from_string a))
      | Error err -> (
          match s with
          | `Must_exist ->
              Mina_user_error.raisef ~where:"reading configuration file"
                "The configuration file %s could not be read:\n%s" config_file
                (Error.to_string_hum err)
          | `May_be_missing ->
              [%log warn] "Could not read configuration from $config_file"
                ~metadata:
                  [ ("config_file", `String config_file)
                  ; ("error", Error_json.error_to_yojson err)
                  ] ;
              return None )
    in
    Deferred.map ~f:List.filter_opt @@ T.map_m ~f config_files

  let load_config_files ?conf_dir ?commit_id_short ~logger config_files =
    let magic_config_files =
      get_magic_config_files ?conf_dir ?commit_id_short ()
    in
    let provided_files = List.map ~f:(fun f -> (f, `Must_exist)) config_files in
    let all_files = magic_config_files @ provided_files in
    let%bind fs = read_files ~logger all_files in
    match Mina_stdlib.Nonempty_list.of_list_opt fs with
    | None ->
        let all_files = List.map ~f:fst all_files in
        Mina_user_error.raisef ~where:"reading configuration files"
          "Failed to find any configuration file, searched the files: %s"
          ("[" ^ String.concat ~sep:", " all_files ^ "]")
    | Some files -> (
        let module T = Monad_lib.Make_ext2 (Result) in
        let init, rest = Mina_stdlib.Nonempty_list.uncons files in
        match T.fold_m ~f:merge_json ~init rest with
        | Ok c ->
            Deferred.Or_error.return c
        | Error err ->
            Deferred.Or_error.error_string err )
end

module type Constants_loader_intf = sig
  type t =
    { genesis_constants : Genesis_constants.t
    ; constraint_constants : Genesis_constants.Constraint_constants.t
    ; proof_level : Genesis_constants.Proof_level.t
    ; compile_config : Mina_compile_config.t
    }

  val load_constants :
       ?itn_features:bool
    -> ?cli_proof_level:Genesis_constants.Proof_level.t
    -> Yojson.Safe.t
    -> t Deferred.Or_error.t
end

module Constants_loader : Constants_loader_intf = struct
  type t =
    { genesis_constants : Genesis_constants.t
    ; constraint_constants : Genesis_constants.Constraint_constants.t
    ; proof_level : Genesis_constants.Proof_level.t
    ; compile_config : Mina_compile_config.t
    }

  (* NOTE: This 'Compiled' module is internal and will eventually be deleted.
     These values should not be referenced except for temporary usage in Runtime_config.
  *)
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

    (* TODO: We can remove this kind of step once we remove the compile time configuration and settle on a final
       json schema.
    *)
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

  let load_constants ?(itn_features = false)
      ?(cli_proof_level : Genesis_constants.Proof_level.t option) json :
      t Deferred.Or_error.t =
    match Runtime_config_v1.Json_layout.of_yojson json with
    | Ok config ->
        let a = Compiled.combine Compiled.constants config in
        Deferred.Or_error.return
          { genesis_constants = Genesis_constants.make a.genesis_constants
          ; compile_config =
              { (Mina_compile_config.make a.compile_config) with itn_features }
          ; constraint_constants =
              Genesis_constants.Constraint_constants.make a.constraint_constants
          ; proof_level =
              Option.value
                ~default:(Genesis_constants.Proof_level.of_string a.proof_level)
                cli_proof_level
          }
    | Error e ->
        Deferred.Or_error.error_string e
end

module type Config_loader = sig
  val load_config : Constants_loader.t -> Yojson.Safe.t -> (t, string) result
end

module Config_loader : Config_loader = struct
  let load_config (constants : Constants_loader.t) (json : Yojson.Safe.t) :
      (t, string) result =
    let open Result.Let_syntax in
    let%bind json_layout = Runtime_config_v1.Json_layout.of_yojson json in
    let%bind ledger =
      match json_layout.ledger with
      | Some ledger ->
          Ledger.of_json_layout ledger
      | None ->
          Error "ledger field is missing in config json"
    in
    let%map epoch_data =
      match json_layout.epoch_data with
      | None ->
          Ok None
      | Some conf ->
          Epoch_data.of_json_layout conf |> Result.map ~f:Option.some
    in
    { genesis_constants = constants.genesis_constants
    ; proof =
        { constraint_constants = constants.constraint_constants
        ; proof_level = constants.proof_level
        }
    ; daemon =
        { compile_config = constants.compile_config
        ; peer_list_url =
            Option.(json_layout.daemon >>= fun a -> a.peer_list_url)
        }
    ; ledger
    ; epoch_data
    }
end

(* Use this function if you don't need/want the ledger configuration *)
let load_constants ?conf_dir ?commit_id_short ?itn_features ?cli_proof_level
    ~logger config_files =
  Deferred.Or_error.ok_exn
  @@
  let open Deferred.Or_error.Let_syntax in
  let%bind json =
    Json_loader.load_config_files ?conf_dir ?commit_id_short ~logger
      config_files
  in
  Constants_loader.load_constants ?itn_features ?cli_proof_level json

(* Use this function if you need the ledger configuration. NOTE: this function simply loads the json,
   see Genesis_ledger_helper.Config_initializer to initialize the ledger with this config.
*)
let load_config ?conf_dir ?commit_id_short ?itn_features ?cli_proof_level
    ~logger config_files =
  Deferred.Or_error.ok_exn
  @@
  let open Deferred.Or_error.Let_syntax in
  let%bind json =
    Json_loader.load_config_files ?conf_dir ?commit_id_short ~logger
      config_files
  in
  let%bind constants =
    Constants_loader.load_constants ?itn_features ?cli_proof_level json
  in
  let e_res = Config_loader.load_config constants json in
  match e_res with
  | Ok res ->
      return res
  | Error e ->
      Deferred.Or_error.error_string @@ "Error loading runtime config: " ^ e
