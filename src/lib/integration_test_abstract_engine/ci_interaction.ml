open Core_kernel
open Async
open Currency
open Signature_lib
open Mina_base
open Integration_test_lib

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

  (* TODO: replace with t' *)
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

  (* TODO: remove *)
  type t' =
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
    }
  [@@deriving to_yojson]

  let testnet_log_filter t = t.config.network_id

  let expand ~logger ~test_name ~(cli_inputs : Cli_inputs.t) ~(debug : bool)
      ~(test_config : Test_config.t) ~(images : Test_config.Container_images.t)
      =
    let { requires_graphql
        ; genesis_ledger
        ; block_producers
        ; snark_coordinator
        ; snark_worker_fee
        ; num_archive_nodes
        ; log_precomputed_blocks
        ; proof_config
        ; Test_config.k
        ; delta
        ; slots_per_epoch
        ; slots_per_sub_window
        ; txpool_max_size
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
    let network_id = "it-" ^ user ^ "-" ^ git_commit ^ "-" ^ test_name in
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

    (* GENERATE ACCOUNTS AND KEYPAIRS *)
    let keypairs =
      List.take
        (* the first keypair is the genesis winner and is assumed to be untimed. Therefore dropping it, and not assigning it to any block producer *)
        (List.drop
           (Array.to_list (Lazy.force Key_gen.Sample_keypairs.keypairs))
           1 )
        (List.length genesis_ledger)
    in
    let labeled_accounts :
        ( Runtime_config.Accounts.single
        * (Public_key.Compressed.t * Private_key.t) )
        String.Map.t =
      String.Map.empty
    in
    let rec add_accounts mp zip =
      match zip with
      | [] ->
          mp
      | hd :: tl ->
          let ( { Test_config.Test_Account.balance; account_name; timing }
              , (pk, sk) ) =
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
            (String.Map.add_exn mp ~key:account_name ~data:(acct, (pk, sk)))
            tl
    in
    let genesis_ledger_accounts =
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
                Some Core.Time.(to_string_abs ~zone:Zone.utc (now ()))
            }
      ; proof = Some proof_config (* TODO: prebake ledger and only set hash *)
      ; ledger =
          Some
            { base =
                Accounts
                  (let tuplist = String.Map.data genesis_ledger_accounts in
                   List.map tuplist ~f:(fun tup ->
                       let acct, _ = tup in
                       acct ) )
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
    let mk_net_keypair keypair_name (pk, sk) =
      let keypair =
        { Keypair.public_key = Public_key.decompress_exn pk; private_key = sk }
      in
      Network_keypair.create_network_keypair ~keypair_name ~keypair
    in
    let block_producer_config name keypair =
      { name; keypair; libp2p_secret = "" }
    in
    let block_producer_configs =
      List.map block_producers ~f:(fun node ->
          let _, key_tup =
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
            (mk_net_keypair node.account_name key_tup) )
    in
    let mina_archive_schema = "create_schema.sql" in
    let long_commit_id =
      if String.is_substring Mina_version.commit_id ~substring:"[DIRTY]" then
        String.sub Mina_version.commit_id ~pos:7
          ~len:(String.length Mina_version.commit_id - 7)
      else Mina_version.commit_id
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
             let kp_name, (_, (pk, sk)) = element in
             (kp_name, mk_net_keypair kp_name (pk, sk)) ) )
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
        ; archive_node_count = num_archive_nodes
        ; mina_archive_schema
        ; mina_archive_schema_aux_files
        ; snark_coordinator_config
        ; snark_worker_fee
        }
    }
end

module Config_file = struct
  type t = { version : int; actions : action list } [@@deriving eq, yojson]

  and action = { name : string; args : Yojson.Safe.t; command : string }
  [@@deriving eq, yojson]

  exception Invalid_version of Yojson.Safe.t

  exception Invalid_actions of Yojson.Safe.t

  exception Invalid_args of Yojson.Safe.t

  exception Invalid_arg_type_should_be_string of string * Yojson.Safe.t

  exception Invalid_command of Yojson.Safe.t
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
    | Snark_worker
    | Snark_coordinator
  [@@deriving eq, yojson]

  let to_string nt = to_yojson nt |> Yojson.Safe.to_string

  let of_string s = of_yojson @@ `List [ `String s ] |> Result.ok_or_failwith

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
  module Map = Map.Make (String)
  include Map

  exception Invalid_entry of string * Yojson.Safe.t

  exception Invalid_output of string

  exception Invalid_keypair of Yojson.Safe.t

  type t = node_info Map.t [@@deriving eq]

  and node_info =
    { node_type : Node_type.t
    ; network_keypair : Network_keypair.t option
    ; password : string
    ; graphql_uri : string
    }
  [@@deriving yojson]

  let network_keypair_of_yojson (sk : Yojson.Safe.t) =
    match sk with
    | `Null ->
        None
    | `Assoc
        [ ("private_key", `String private_key)
        ; ("privkey_password", `String privkey_password)
        ; ("keypair_name", `String keypair_name)
        ] ->
        let keypair =
          Keypair.of_private_key_exn
          @@ Private_key.of_base58_check_exn private_key
        in
        Some
          Network_keypair.
            { keypair
            ; keypair_name
            ; privkey_password
            ; private_key
            ; public_key =
                Public_key.to_bigstring keypair.public_key
                |> Bigstring.to_string
            }
    | _ ->
        raise @@ Invalid_keypair sk

  let of_yojson =
    let f accum = function
      | ( node_id
        , `Assoc
            [ ("node_type", `String nt)
            ; ("network_keypair", keypair)
            ; ("password", `String password)
            ; ("graphql_uri", `String graphql_uri)
            ] ) ->
          Map.set accum ~key:node_id
            ~data:
              { node_type = Node_type.of_string nt
              ; network_keypair = network_keypair_of_yojson keypair
              ; password
              ; graphql_uri
              }
      | node_id, t ->
          raise @@ Invalid_entry (node_id, t)
    in
    function
    | `Assoc a_list ->
        Ok (List.fold a_list ~init:(Map.empty : t) ~f)
    | t ->
        raise @@ Invalid_output (Yojson.Safe.to_string t)
end

module Node_started = struct
  type t = { node_id : Node_id.t } [@@deriving eq, of_yojson]

  exception Invalid_response of string
end

module Node_stopped = struct
  type t = { node_id : Node_id.t } [@@deriving eq, of_yojson]

  exception Invalid_response of string
end

module Archive_data_dump = struct
  type t = { node_id : Node_id.t; data : string } [@@deriving eq, of_yojson]

  exception Invalid_response of string
end

module Mina_logs_dump = struct
  type t = { node_id : Node_id.t; logs : Node_logs.t }
  [@@deriving eq, of_yojson]

  exception Invalid_response of string
end

module Precomputed_block_dump = struct
  type t = { node_id : Node_id.t; blocks : string } [@@deriving eq, of_yojson]

  exception Invalid_response of string
end

module Replayer_run = struct
  type t = { node_id : Node_id.t; logs : Node_logs.t }
  [@@deriving eq, of_yojson]

  exception Invalid_response of string
end

module Command_output = struct
  type t =
    | Network_created of Network_created.t
    | Network_deployed of Network_deployed.t
    | Network_destroyed
    | Node_started of Node_started.t
    | Node_stopped of Node_stopped.t
    | Archive_data_dump of Archive_data_dump.t
    | Mina_logs_dump of Mina_logs_dump.t
    | Precomputed_block_dump of Precomputed_block_dump.t
    | Replayer_run of Replayer_run.t
  [@@deriving eq, of_yojson]
end

module Arg_type = struct
  (* TODO: what other arg types? *)
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

let version config =
  match Yojson.Safe.Util.member "version" config with
  | `Int version ->
      version
  | t ->
      raise @@ Config_file.Invalid_version t

let action name config =
  let open Yojson.Safe in
  match Util.member "actions" config with
  | `List actions ->
      List.find_exn actions ~f:(fun action ->
          Util.member "name" action |> equal @@ `String name )
  | t ->
      raise @@ Config_file.Invalid_actions t

let args_of_action action =
  let open Yojson.Safe in
  let a_list =
    match Util.member "args" action with
    | `Assoc a_list ->
        a_list
    | t ->
        raise @@ Config_file.Invalid_args t
  in
  List.map a_list ~f:(function
    | name, `String type_name ->
        (name, type_name)
    | name, t ->
        raise @@ Config_file.Invalid_arg_type_should_be_string (name, t) )

let raw_cmd t =
  match Yojson.Safe.Util.member "command" t with
  | `String raw_cmd ->
      raw_cmd
  | cmd ->
      raise @@ Config_file.Invalid_command cmd

let validate_arg_type arg_typ arg_value =
  String.equal arg_typ @@ Arg_type.arg_type arg_value

exception Invalid_config_args_num

exception Missing_config_arg of string * string

exception Invalid_config_arg_type of string * Yojson.Safe.t * string

let validate_args ~args ~action =
  let arg_list = args_of_action action in
  let () =
    if not List.(length arg_list = length args) then
      raise @@ Invalid_config_args_num
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
            raise @@ Missing_config_arg (arg_name, arg_type)
        in
        if validate_arg_type arg_type arg_value then aux rest
        else raise @@ Invalid_config_arg_type (arg_name, arg_value, arg_type)
  in
  aux arg_list

let rec interpolate_args ~args raw_cmd =
  match args with
  | [] ->
      raw_cmd
  | (arg, value) :: args ->
      let pattern = sprintf "{{%s}}" arg in
      interpolate_args ~args
      @@ String.substr_replace_all raw_cmd ~pattern
           ~with_:(Yojson.Safe.to_string value |> Util.drop_outer_quotes)

let prog_and_args ~args action =
  let raw_cmd = raw_cmd action in
  let cmd_list = interpolate_args ~args raw_cmd |> String.split ~on:' ' in
  (List.hd_exn cmd_list, List.tl_exn cmd_list)

let run_command ?(suppress_logs = false) ?(timeout_seconds = 1) ?(dir = ".")
    ~config ~args cmd_name =
  let config = Yojson.Safe.from_file config in
  let version = version config in
  let action = action cmd_name config in
  let action_args = args_of_action action in
  let () = assert (validate_args ~args ~action) in
  let prog, arg_values = prog_and_args ~args action in
  let cmd = String.concat ~sep:" " (prog :: arg_values) in
  let%map output =
    Util.run_cmd_or_error_timeout ~suppress_logs ~timeout_seconds dir prog
      arg_values
  in
  match output with
  | Ok output ->
      if not suppress_logs then
        [%log' spam (Logger.create ())]
          "Successful command execution\nCommand: %s\nOutput: %s" cmd output ;
      Ok output
  | _ ->
      if not suppress_logs then
        [%log' error (Logger.create ())] "Failed to run command: %s" cmd ;
      Error
        (sprintf
           "Failed to run command: %s\n\
           \ Config version: %d\n\
           \ Expected args types:\n\
           \     %s\n\
           \ Attempted args:\n\
           \     %s\n"
           cmd version
           ( String.concat ~sep:", "
           @@ List.map action_args ~f:(fun (name, type_name) ->
                  name ^ ": " ^ type_name ) )
           ( String.concat ~sep:", "
           @@ List.map args ~f:(fun (name, value) ->
                  name ^ ": " ^ Yojson.Safe.to_string value ) ) )
