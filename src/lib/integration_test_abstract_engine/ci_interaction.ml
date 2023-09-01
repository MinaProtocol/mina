open Core_kernel
open Async
open Currency
open Signature_lib
open Mina_base
open Integration_test_lib

(* [alias] is instantiated when command line args are parsed *)
let alias = ref None

(* [archive_image] is instantiated when command line args are parsed *)
let archive_image : string option ref = ref None

(* [config_path] is instantiated when command line args are parsed *)
let config_path = ref ""

(* [keypairs_path] is instantiated when command line args are parsed *)
let keypairs_path = ref ""

(* [mina_image] is instantiated when command line args are parsed *)
let mina_image = ref ""

module Network_config = struct
  module Cli_inputs = Cli_inputs

  type block_producer_config =
    { name : string; keypair : Network_keypair.t; libp2p_secret : string }
  [@@deriving to_yojson]

  type snark_coordinator_config =
    { name : string; public_key : string; worker_nodes : int }
  [@@deriving to_yojson]

  type config =
    { network_id : string
    ; config_dir : string
    ; deploy_graphql_ingress : bool
    ; mina_image : string
    ; mina_agent_image : string
    ; mina_bots_image : string
    ; mina_points_image : string
    ; mina_archive_image : string
    ; runtime_config : Yojson.Safe.t
          [@to_yojson fun j -> `String (Yojson.Safe.to_string j)]
    ; block_producer_configs : block_producer_config list
    ; log_precomputed_blocks : bool
    ; archive_node_count : int
    ; mina_archive_schema : string
    ; mina_archive_schema_aux_files : string list
    ; snark_coordinator_config : snark_coordinator_config option
    ; snark_worker_fee : string
    }
  [@@deriving to_yojson]

  type t =
    { debug_arg : bool
    ; genesis_keypairs :
        (Network_keypair.t Core.String.Map.t
        [@to_yojson
          fun map ->
            `Assoc
              (Core.Map.fold_right ~init:[]
                 ~f:(fun ~key:k ~data:v accum ->
                   (k, Network_keypair.to_yojson v) :: accum )
                 map )] )
    ; constants : Test_config.constants
    ; config : config
    }
  [@@deriving to_yojson]

  let testnet_log_filter t = t.config.network_id

  let pull_keypairs num_keypairs =
    let int_list = List.range ~stop:`inclusive 1 10_000 in
    let random_nums =
      Quickcheck.Generator.(of_list int_list |> list_with_length num_keypairs)
      |> Quickcheck.random_value
    in
    let normalize_path path =
      if String.(suffix path 1 = "/") then String.drop_suffix path 1 else path
    in
    (* network keypairs + private keys *)
    let keypairs_path = normalize_path !keypairs_path in
    let base_filename n =
      sprintf "%s/network-keypairs/sender-account-%d.json" keypairs_path n
    in
    let read_sk n = In_channel.read_all (base_filename n ^ ".sk") in
    let read_keypair n =
      let open Yojson.Safe in
      let json = from_file (base_filename n) in
      let sk = read_sk n |> Private_key.of_base58_check_exn in
      { Network_keypair.keypair = Keypair.of_private_key_exn sk
      ; keypair_name = Util.member "keypair_name" json |> to_string
      ; privkey_password = Util.member "privkey_password" json |> to_string
      ; public_key = Util.member "public_key" json |> to_string
      ; private_key = Util.member "private_key" json |> to_string
      }
    in
    (* libp2p keypairs *)
    let libp2p_base_filename n =
      sprintf "%s/libp2p-keypairs/libp2p-keypair-%d.json" keypairs_path n
    in
    let read_peerid n =
      In_channel.read_all (libp2p_base_filename n ^ ".peerid")
    in
    let read_libp2p n = Yojson.Safe.from_file (libp2p_base_filename n) in
    ( List.map random_nums ~f:read_keypair
    , List.map random_nums ~f:read_sk
    , List.map random_nums ~f:read_libp2p
    , List.map random_nums ~f:read_peerid )

  let expand ~logger ~test_name ~(cli_inputs : Cli_inputs.t) ~(debug : bool)
      ~(test_config : Test_config.t) ~(images : Test_config.Container_images.t)
      =
    let { requires_graphql
        ; genesis_ledger
        ; archive_nodes
        ; block_producers
        ; snark_coordinator
        ; snark_worker_fee
        ; log_precomputed_blocks
        ; proof_config
        ; Test_config.k
        ; delta
        ; slots_per_epoch
        ; slots_per_sub_window
        ; txpool_max_size
        ; _
        } =
      test_config
    in
    let user_from_env = Option.value (Unix.getenv "USER") ~default:"auto" in
    let user_sanitized =
      Str.global_replace (Str.regexp "\\W|_-") "" user_from_env
    in
    let user_len = Int.min 5 (String.length user_sanitized) in
    let user = String.sub user_sanitized ~pos:0 ~len:user_len in
    let git_commit = Mina_version.commit_id_short in
    let network_id = sprintf "it-%s-%s-%s" user git_commit test_name in
    (* check to make sure the test writer hasn't accidentally created duplicate names of accounts and keys *)
    let key_names_list =
      List.map genesis_ledger ~f:(fun acct -> acct.account_name)
    in
    if List.contains_dup ~compare:String.compare key_names_list then
      failwith
        "All accounts in genesis ledger must have unique names.  Check to make \
         sure you are not using the same account_name more than once" ;
    let all_nodes_names_list =
      List.map block_producers ~f:(fun acct -> acct.node_name)
      @ match snark_coordinator with None -> [] | Some n -> [ n.node_name ]
    in
    if List.contains_dup ~compare:String.compare all_nodes_names_list then
      failwith
        "All nodes in testnet must have unique names.  Check to make sure you \
         are not using the same node_name more than once" ;
    (* ACCOUNTS AND KEYPAIRS *)
    let before = Time.now () in
    let num_keypairs = List.length genesis_ledger in
    let network_keypairs, private_keys, _libp2p_keypairs, _libp2p_peerids =
      pull_keypairs (List.length genesis_ledger)
    in
    [%log trace] "Pulled %d keypairs from %s in %s" num_keypairs !keypairs_path
      Time.(abs_diff before @@ now () |> Span.to_string) ;
    let labeled_accounts :
        (Runtime_config.Accounts.single * (Network_keypair.t * Private_key.t))
        String.Map.t =
      String.Map.empty
    in
    let rec add_accounts acc = function
      | [] ->
          acc
      | hd :: tl ->
          let ( { Test_config.Test_Account.balance; account_name; timing; _ }
              , (network_keypair, sk) ) =
            hd
          in
          let timing =
            match timing with
            | Account.Timing.Untimed ->
                None
            | Timed t ->
                Some
                  { Runtime_config.Accounts.Single.Timed.initial_minimum_balance =
                      t.initial_minimum_balance
                  ; cliff_time = t.cliff_time
                  ; cliff_amount = t.cliff_amount
                  ; vesting_period = t.vesting_period
                  ; vesting_increment = t.vesting_increment
                  }
          in
          let default = Runtime_config.Accounts.Single.default in
          let sk = Private_key.of_base58_check_exn sk in
          let pk = Public_key.(of_private_key_exn sk |> compress) in
          let acct =
            { default with
              pk = Public_key.Compressed.to_string pk
            ; sk = Some (Private_key.to_base58_check sk)
            ; balance =
                Balance.of_mina_string_exn balance
                (* delegation currently unsupported *)
            ; delegate = None
            ; timing
            }
          in
          add_accounts
            (String.Map.add_exn acc ~key:account_name
               ~data:(acct, (network_keypair, sk)) )
            tl
    in
    let genesis_ledger_accounts =
      let network_keypairs =
        List.mapi network_keypairs ~f:(fun n kp ->
            { kp with
              keypair_name = (List.nth_exn genesis_ledger n).account_name
            } )
      in
      let keypairs = List.zip_exn network_keypairs private_keys in
      add_accounts labeled_accounts (List.zip_exn genesis_ledger keypairs)
    in
    (* DAEMON CONFIG *)
    let constraint_constants =
      Genesis_ledger_helper.make_constraint_constants
        ~default:Genesis_constants.Constraint_constants.compiled proof_config
    in
    let runtime_config =
      { Runtime_config.daemon =
          Some
            { txpool_max_size = Some txpool_max_size
            ; peer_list_url = None
            ; zkapp_proof_update_cost = None
            ; zkapp_signed_single_update_cost = None
            ; zkapp_signed_pair_update_cost = None
            ; zkapp_transaction_cost_limit = None
            ; max_event_elements = None
            ; max_action_elements = None
            }
      ; genesis =
          Some
            { k = Some k
            ; delta = Some delta
            ; slots_per_epoch = Some slots_per_epoch
            ; slots_per_sub_window = Some slots_per_sub_window
            ; genesis_state_timestamp =
                Some Core.Time.(to_string_abs ~zone:Zone.utc @@ now ())
            }
      ; proof = Some proof_config (* TODO: prebake ledger and only set hash *)
      ; ledger =
          Some
            { base =
                Accounts
                  (String.Map.data genesis_ledger_accounts |> List.map ~f:fst)
            ; add_genesis_winner = None
            ; num_accounts = None
            ; balances = []
            ; hash = None
            ; name = None
            }
      ; epoch_data = None
      }
    in
    let genesis_constants =
      Or_error.ok_exn
        (Genesis_ledger_helper.make_genesis_constants ~logger
           ~default:Genesis_constants.compiled runtime_config )
    in
    let constants : Test_config.constants =
      { constraints = constraint_constants; genesis = genesis_constants }
    in
    (* BLOCK PRODUCER CONFIG *)
    let block_producer_config name keypair =
      { name; keypair; libp2p_secret = "" }
    in
    let block_producer_configs =
      List.mapi block_producers ~f:(fun n node ->
          let _ =
            match String.Map.find genesis_ledger_accounts node.account_name with
            | Some acct ->
                acct
            | None ->
                let failstring =
                  Format.sprintf
                    "Failing because the account key of all initial block \
                     producers must be in the genesis ledger.  name of Node: \
                     %s.  name of Account which does not exist: %s"
                    node.node_name node.account_name
                in
                failwith failstring
          in
          block_producer_config node.node_name
          @@ List.nth_exn network_keypairs n )
    in
    let mina_archive_schema = "create_schema.sql" in
    let long_commit_id =
      let open String in
      let id = Mina_version.commit_id in
      if prefix id 7 = "[DIRTY]" then suffix id (length id - 7) else id
    in
    let mina_archive_base_url =
      "https://raw.githubusercontent.com/MinaProtocol/mina/" ^ long_commit_id
      ^ "/src/app/archive/"
    in
    let mina_archive_schema_aux_files =
      [ mina_archive_base_url ^ "create_schema.sql"
      ; mina_archive_base_url ^ "zkapp_tables.sql"
      ]
    in
    let genesis_keypairs =
      String.Map.of_alist_exn
        (List.map (String.Map.to_alist genesis_ledger_accounts)
           ~f:(fun element ->
             let kp_name, (_, (keypair, _)) = element in
             (kp_name, keypair) ) )
    in
    let snark_coordinator_config =
      match snark_coordinator with
      | None ->
          None
      | Some node ->
          let network_kp =
            match String.Map.find genesis_keypairs node.account_name with
            | Some acct ->
                acct
            | None ->
                let failstring =
                  Format.sprintf
                    "Failing because the account key of all initial snark \
                     coordinators must be in the genesis ledger.  name of \
                     Node: %s.  name of Account which does not exist: %s"
                    node.node_name node.account_name
                in
                failwith failstring
          in
          Some
            { name = node.node_name
            ; public_key =
                Public_key.Compressed.to_base58_check
                  (Public_key.compress network_kp.keypair.public_key)
            ; worker_nodes = node.worker_nodes
            }
    in
    (* NETWORK CONFIG *)
    { debug_arg = debug
    ; genesis_keypairs
    ; constants
    ; config =
        { network_id
        ; config_dir = cli_inputs.mina_automation_location
        ; deploy_graphql_ingress = requires_graphql
        ; mina_image = images.mina
        ; mina_agent_image = images.user_agent
        ; mina_bots_image = images.bots
        ; mina_points_image = images.points
        ; mina_archive_image = images.archive_node
        ; runtime_config = Runtime_config.to_yojson runtime_config
        ; block_producer_configs
        ; log_precomputed_blocks
        ; archive_node_count = List.length archive_nodes
        ; mina_archive_schema
        ; mina_archive_schema_aux_files
        ; snark_coordinator_config
        ; snark_worker_fee
        }
    }
end

module Network_id = struct
  type t = string [@@deriving eq, yojson]
end

module Node_id = struct
  type t = string [@@deriving eq, yojson]
end

module Node_type = struct
  type t =
    | Archive_node
    | Block_producer_node
    | Seed_node
    | Snark_coordinator
    | Snark_worker
  [@@deriving eq, to_yojson]

  let to_string nt = to_yojson nt |> Yojson.Safe.to_string

  let of_yojson (t : Yojson.Safe.t) =
    match t with
    | `String nt -> (
        match nt with
        | "Archive_node" | "ArchiveNode" | "Archive" ->
            Ok Archive_node
        | "Block_producer_node" | "BlockProducerNode" | "BlockProducer" ->
            Ok Block_producer_node
        | "Seed_node" | "SeedNode" | "Seed" ->
            Ok Seed_node
        | "Snark_coordinator" | "SnarkCoordinator" ->
            Ok Snark_coordinator
        | "Snark_worker" | "SnarkWorker" ->
            Ok Snark_worker
        | _ ->
            Error (sprintf "Invalid node type: %s" nt) )
    | _ ->
        Error (Yojson.Safe.to_string t)

  let of_string s = of_yojson @@ `String s |> Result.ok_or_failwith

  let is_archive_node = function Archive_node -> true | _ -> false

  let is_block_producer = function Block_producer_node -> true | _ -> false

  let is_seed_node = function Seed_node -> true | _ -> false

  let is_snark_worker = function Snark_worker -> true | _ -> false

  let is_snark_coordinator = function Snark_coordinator -> true | _ -> false
end

(** Logproc takes care of these logs so we bypass them here *)
module Node_logs = struct
  type t = string [@@deriving eq]

  let to_yojson s = `String s

  let of_yojson = function
    | `String s ->
        Ok s
    | x ->
        Error (Yojson.Safe.to_string x)
end

module Network_created = struct
  type t = { network_id : Network_id.t } [@@deriving eq, of_yojson]
end

module Network_deployed = struct
  exception Invalid_entry of string

  exception Invalid_output of string

  exception Invalid_keypair of Yojson.Safe.t

  type node_info =
    { graphql_uri : string option
    ; network_id : Network_id.t
    ; network_keypair : Network_keypair.t option
    ; node_id : Node_id.t
    ; node_type : Node_type.t
    }
  [@@deriving to_yojson]

  let equal_node_info m n =
    let node_type = Node_type.equal m.node_type n.node_type in
    let network_keypair =
      Option.equal
        (fun (m : Network_keypair.t) n ->
          Public_key.equal m.keypair.public_key n.keypair.public_key
          && String.equal m.public_key n.public_key
          && String.equal m.privkey_password n.privkey_password
          && String.equal m.keypair_name n.keypair_name )
        m.network_keypair n.network_keypair
    in
    let graphql = Option.equal String.equal m.graphql_uri n.graphql_uri in
    node_type && network_keypair && graphql

  let is_archive_node node_info = Node_type.is_archive_node node_info.node_type

  let is_block_producer node_info =
    Node_type.is_block_producer node_info.node_type

  let is_seed_node node_info = Node_type.is_seed_node node_info.node_type

  let is_snark_coordinator node_info =
    Node_type.is_snark_coordinator node_info.node_type

  let is_snark_worker node_info = Node_type.is_snark_worker node_info.node_type

  let network_id { network_id; _ } = network_id

  type t = node_info Core.String.Map.t [@@deriving eq]

  let network_keypair_of_yojson node_id (private_key : Yojson.Safe.t) =
    match private_key with
    | `Null ->
        None
    | `String private_key ->
        let keypair_name = node_id ^ "_key" in
        let keypair =
          Keypair.of_private_key_exn
          @@ Private_key.of_base58_check_exn private_key
        in
        Some (Network_keypair.create_network_keypair ~keypair_name ~keypair)
    | _ ->
        raise @@ Invalid_keypair private_key

  let graphql_uri_of_yojson (uri : Yojson.Safe.t) =
    match uri with
    | `Null ->
        None
    | `String uri ->
        Some uri
    | _ ->
        raise @@ Invalid_argument (Yojson.Safe.to_string uri)

  let of_yojson =
    let node_info_helper network_id accum : string * Yojson.Safe.t -> t =
      function
      | ( node_id
        , `Assoc
            [ ("graphql_uri", graphql_uri)
            ; ("node_type", `String nt)
            ; ("private_key", private_key)
            ] ) ->
          Core.String.Map.set accum ~key:node_id
            ~data:
              { node_id
              ; network_id
              ; node_type = Node_type.of_string nt
              ; network_keypair = network_keypair_of_yojson node_id private_key
              ; graphql_uri = graphql_uri_of_yojson graphql_uri
              }
      | node_id, t ->
          raise
          @@ Invalid_entry (sprintf "%s: %s" node_id @@ Yojson.Safe.to_string t)
    in
    function
    | `Assoc [ ("network_id", `String network_id); ("nodes", `Assoc nodes) ] ->
        Ok
          (List.fold nodes ~init:Core.String.Map.empty
             ~f:(node_info_helper network_id) )
    | t ->
        print_endline @@ Yojson.Safe.pretty_to_string t ;
        raise @@ Invalid_output (Yojson.Safe.to_string t)
end

module Node_started = struct
  type t = { network_id : Network_id.t; node_id : Node_id.t }
  [@@deriving eq, of_yojson]

  exception Invalid_response of string
end

module Node_stopped = struct
  type t = { network_id : Network_id.t; node_id : Node_id.t }
  [@@deriving eq, of_yojson]

  exception Invalid_response of string
end

module Archive_data_dump = struct
  type t = { data : string; network_id : Network_id.t; node_id : Node_id.t }
  [@@deriving eq, of_yojson]

  exception Invalid_response of string
end

module Mina_logs_dump = struct
  type t =
    { logs : Node_logs.t; network_id : Network_id.t; node_id : Node_id.t }
  [@@deriving eq, of_yojson]

  exception Invalid_response of string
end

module Precomputed_block_dump = struct
  type t = { blocks : string; network_id : Network_id.t; node_id : Node_id.t }
  [@@deriving eq, of_yojson]

  exception Invalid_response of string
end

module Replayer_run = struct
  type t =
    { logs : Node_logs.t; network_id : Network_id.t; node_id : Node_id.t }
  [@@deriving eq, of_yojson]

  exception Invalid_response of string
end

module Network_status = struct
  type t = Deploy_error of string | Status of Node_id.t Core.String.Map.t
  [@@deriving eq]

  exception Invalid_status of string * string

  let of_yojson (t : Yojson.Safe.t) =
    match t with
    | `Assoc [ ("deploy_error", `String error) ] ->
        Ok (Deploy_error error)
    | `Assoc statuses ->
        let status_map =
          let open Core.String.Map in
          List.fold statuses ~init:empty ~f:(fun acc -> function
            | node_id, `String status ->
                set acc ~key:node_id ~data:status
            | node_id, error ->
                raise @@ Invalid_status (node_id, Yojson.Safe.to_string error) )
        in
        Ok (Status status_map)
    | _ ->
        Error (Yojson.Safe.to_string t)
end

module Command_output = struct
  type t =
    | Network_created of Network_created.t
    | Network_deployed of Network_deployed.t
    | Network_destroyed
    | Network_status of Network_status.t
    | Node_started of Node_started.t
    | Node_stopped of Node_stopped.t
    | Archive_data_dump of Archive_data_dump.t
    | Mina_logs_dump of Mina_logs_dump.t
    | Precomputed_block_dump of Precomputed_block_dump.t
    | Replayer_run of Replayer_run.t
  [@@deriving eq, of_yojson]
end

module Arg_type = struct
  let bool = "bool"

  let int = "int"

  let string = "string"

  exception Invalid_arg_type of Yojson.Safe.t

  let arg_type (t : Yojson.Safe.t) =
    match t with
    | `Bool _ ->
        bool
    | `Int _ ->
        int
    | `String _ ->
        string
    | _ ->
        raise @@ Invalid_arg_type t
end

module Config_file = struct
  type t = { version : int; actions : action list } [@@deriving eq, yojson]

  and action = { name : string; args : Yojson.Safe.t; command : string }

  exception Invalid_version of Yojson.Safe.t

  exception Invalid_actions of Yojson.Safe.t

  exception Invalid_args of Yojson.Safe.t

  exception Invalid_arg_type_should_be_string of string * Yojson.Safe.t

  exception Invalid_list of Yojson.Safe.t list

  exception Invalid_command of Yojson.Safe.t

  exception Invalid_args_num of string * string list * string list

  exception Missing_arg of string * string * string

  exception Invalid_arg_type of string * Yojson.Safe.t * string

  let version config =
    match Yojson.Safe.Util.member "version" config with
    | `Int version ->
        version
    | t ->
        raise @@ Invalid_version t

  let action_name action =
    let open Yojson.Safe in
    Util.member "name" action |> to_string

  let action name config =
    let open Yojson.Safe in
    match Util.member "actions" config with
    | `List actions ->
        List.find_exn actions ~f:(fun action ->
            Util.member "name" action |> equal @@ `String name )
    | t ->
        raise @@ Invalid_actions t

  let args_of_action action =
    let open Yojson.Safe in
    let a_list =
      match Util.member "args" action with
      | `Assoc a_list ->
          a_list
      | t ->
          raise @@ Invalid_args t
    in
    List.map a_list ~f:(function
      | name, `String type_name ->
          (name, type_name)
      | name, t ->
          raise @@ Invalid_arg_type_should_be_string (name, t) )

  let raw_cmd action =
    match Yojson.Safe.Util.member "command" action with
    | `String raw_cmd ->
        raw_cmd
    | cmd ->
        raise @@ Invalid_command cmd

  let arg_to_flag s = "--" ^ String.substr_replace_all s ~pattern:"_" ~with_:"-"

  let validate_arg_type arg_typ arg_value =
    String.equal arg_typ @@ Arg_type.arg_type arg_value

  let validate_args ~args ~action =
    let arg_list = args_of_action action in
    let () =
      let open List in
      if not (length arg_list = length args) then
        let input_args = map args ~f:fst in
        let action_args = map ~f:fst @@ args_of_action action in
        raise @@ Invalid_args_num (action_name action, input_args, action_args)
    in
    let rec aux = function
      | [] ->
          true
      | (arg_name, arg_type) :: rest ->
          let arg_value =
            try
              List.find_map_exn args ~f:(fun (name, value) ->
                  Option.some_if (String.equal name arg_name) value )
            with Not_found_s _ ->
              raise @@ Missing_arg (action_name action, arg_name, arg_type)
          in
          if validate_arg_type arg_type arg_value then aux rest
          else raise @@ Invalid_arg_type (arg_name, arg_value, arg_type)
    in
    aux arg_list

  let eliminate_bool_arg raw_cmd pattern =
    let pattern = " " ^ pattern in
    String.substr_replace_all raw_cmd ~pattern ~with_:""

  let rec interpolate_args ~args raw_cmd =
    match args with
    | [] ->
        raw_cmd
    | (arg, value) :: args -> (
        let pattern = sprintf "{{%s}}" arg in
        match value with
        | `Bool b ->
            if b then
              interpolate_args ~args
              @@ String.substr_replace_all raw_cmd ~pattern
                   ~with_:(arg_to_flag arg)
            else eliminate_bool_arg raw_cmd pattern |> interpolate_args ~args
        | _ ->
            interpolate_args ~args
            @@ String.substr_replace_all raw_cmd ~pattern
                 ~with_:(Yojson.Safe.to_string value |> Util.drop_outer_quotes)
        )

  let prog_and_args ~args action =
    let raw_cmd = raw_cmd action in
    let cmd_list = interpolate_args ~args raw_cmd |> String.split ~on:' ' in
    (List.hd_exn cmd_list, List.tl_exn cmd_list)

  let evaluate_alias prog =
    match !alias with
    | Some (alias, value) when String.(alias = prog) ->
        value
    | _ ->
        prog

  let run_command ?(suppress_logs = false) ?(timeout_seconds = 1) ?(dir = ".")
      ~config ~args cmd_name =
    let config = Yojson.Safe.from_file config in
    let version = version config in
    let action = action cmd_name config in
    let action_args = args_of_action action in
    let () = assert (validate_args ~args ~action) in
    let prog, arg_values = prog_and_args ~args action in
    let prog = evaluate_alias prog in
    let cmd = String.concat ~sep:" " (prog :: arg_values) in
    let%map output =
      Util.run_cmd_or_error_timeout ~suppress_logs ~timeout_seconds dir prog
        arg_values
    in
    let logger = Logger.create () in
    match output with
    | Ok output ->
        if not suppress_logs then
          [%log spam] "Successful command execution\n Command: %s\n Output: %s"
            cmd output ;
        Ok output
    | Error err ->
        if not suppress_logs then [%log error] "Failed to run command: %s" cmd ;
        Error
          (sprintf
             "Failed to run command: %s\n\
             \ Config version: %d\n\
             \ Expected arg types:\n\
             \     %s\n\
             \ Attempted args:\n\
             \     %s\n\
             \ Output: %s\n"
             cmd version
             ( String.concat ~sep:", "
             @@ List.map action_args ~f:(fun (name, type_name) ->
                    name ^ ": " ^ type_name ) )
             ( String.concat ~sep:", "
             @@ List.map args ~f:(fun (name, value) ->
                    name ^ " = " ^ Yojson.Safe.to_string value ) )
             (Error.to_string_hum err) )
end
