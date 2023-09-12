open Core_kernel
open Async
open Currency
open Signature_lib
open Mina_base
open Integration_test_lib
module Cli_inputs = Cli_inputs

(* [keypairs_path] is instantiated when command line args are parsed *)
let keypairs_path = ref ""

type block_producer_config =
  { name : string
  ; keypair : Network_keypair.t
  ; libp2p_pass : string
  ; libp2p_keypair : Yojson.Safe.t
  ; libp2p_peerid : string
  }
[@@deriving to_yojson]

type seed_node_config =
  { name : string
  ; libp2p_pass : string
  ; libp2p_keypair : Yojson.Safe.t
  ; libp2p_peerid : string
  }
[@@deriving to_yojson]

type snark_coordinator_config =
  { name : string
  ; public_key : string
  ; worker_nodes : int
  ; libp2p_pass : string
  ; libp2p_keypair : Yojson.Safe.t
  ; libp2p_peerid : string
  }
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
  ; seed_node_configs : seed_node_config list
  ; log_precomputed_blocks : bool
  ; archive_node_count : int
  ; mina_archive_schema : string
  ; mina_archive_schema_aux_files : string list
  ; snark_coordinator_config : snark_coordinator_config option
  ; snark_worker_fee : string
  ; topology : Yojson.Safe.t
        [@to_yojson fun j -> `String (Yojson.Safe.to_string j)]
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

let expand ~logger ~test_name ~(cli_inputs : Cli_inputs.t) ~(debug : bool)
    ~(test_config : Test_config.t) ~(images : Test_config.Container_images.t) =
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
      ; seed_nodes
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
  let network_keypairs, private_keys, libp2p_keypairs, libp2p_peerids =
    let max_num_nodes =
      List.length archive_nodes + List.length block_producers + 1
    in
    Util.pull_keypairs !keypairs_path
      (List.length genesis_ledger + max_num_nodes)
  in
  [%log trace] "Pulled %d keypairs from %s in %s" num_keypairs !keypairs_path
    Time.(abs_diff before @@ now () |> Span.to_string) ;
  let topology =
    Test_config.topology_of_test_config test_config private_keys libp2p_keypairs
      libp2p_peerids
  in
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
    let num_genesis_accounts = List.length genesis_ledger in
    let network_keypairs =
      List.mapi network_keypairs ~f:(fun n kp ->
          if n < num_genesis_accounts then
            { kp with
              keypair_name = (List.nth_exn genesis_ledger n).account_name
            }
          else kp )
    in
    let keypairs =
      List.(take (zip_exn network_keypairs private_keys) num_genesis_accounts)
    in
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
  let block_producer_config (node : Test_config.Block_producer_node.t) =
    let _, (keypair, _) =
      Core.String.Map.find_exn genesis_ledger_accounts node.account_name
    in
    let[@warning "-8"] (Test_config.Topology.Node (_, node_info)) =
      List.find_exn topology ~f:(function
        | Node (name, _) ->
            String.equal name node.node_name
        | _ ->
            false )
    in
    { name = node.node_name
    ; keypair = { keypair with keypair_name = node.node_name }
    ; libp2p_pass = "naughty blue worm"
    ; libp2p_keypair = node_info.libp2p_keypair
    ; libp2p_peerid =
        Yojson.Safe.to_string node_info.libp2p_peerid |> Util.drop_outer_quotes
    }
  in
  let block_producer_configs =
    List.map block_producers ~f:(fun node ->
        if
          Option.is_none
          @@ String.Map.find genesis_ledger_accounts node.account_name
        then
          failwith
          @@ Format.sprintf
               "Failing because the account key of all initial block producers \
                must be in the genesis ledger.  name of Node: %s.  name of \
                Account which does not exist: %s"
               node.node_name node.account_name ;
        block_producer_config node )
  in
  let seed_node_configs =
    List.map seed_nodes ~f:(fun node ->
        let[@warning "-8"] (Test_config.Topology.Node (_, node_info)) =
          List.find_exn topology ~f:(function
            | Node (name, _) ->
                String.equal name node.node_name
            | _ ->
                false )
        in
        { name = node.node_name
        ; libp2p_pass = "naughty blue worm"
        ; libp2p_keypair = node_info.libp2p_keypair
        ; libp2p_peerid =
            Yojson.Safe.to_string node_info.libp2p_peerid
            |> Util.drop_outer_quotes
        } )
  in
  let mina_archive_schema = "create_schema.sql" in
  let long_commit_id =
    let open String in
    let id = Mina_version.commit_id in
    if prefix id 7 = "[DIRTY]" then drop_prefix id 7 else id
  in
  let mina_archive_base_url =
    "https://raw.githubusercontent.com/MinaProtocol/mina/" ^ long_commit_id
    ^ "/src/app/archive/"
  in
  let schema_file = mina_archive_base_url ^ "create_schema.sql" in
  let zkapp_table = mina_archive_base_url ^ "zkapp_tables.sql" in
  let mina_archive_schema_aux_files = [ schema_file; zkapp_table ] in
  let libp2p_keyfile name =
    let open Core in
    cli_inputs.mina_automation_location ^/ "testnets" ^/ network_id
    ^/ "libp2p_keys" ^/ name ^ ".json"
  in
  let privkey_path name =
    let open Core in
    cli_inputs.mina_automation_location ^/ "testnets" ^/ network_id
    ^/ "block_producer_keys" ^/ name ^ ".json"
  in
  (* instantiate remaining topology information *)
  let topology =
    List.map topology ~f:(function
      | Archive (name, archive_info) ->
          Test_config.Topology.Archive
            ( name
            , { archive_info with schema_files = mina_archive_schema_aux_files }
            )
      | Node (name, node_info) -> (
          match node_info.role with
          | Test_config.Node_role.Block_producer ->
              Node
                ( name
                , { node_info with
                    privkey_path = Some (privkey_path name)
                  ; libp2p_keyfile = libp2p_keyfile name
                  } )
          | _ ->
              Node
                (name, { node_info with libp2p_keyfile = libp2p_keyfile name })
          )
      | Snark_coordinator (name, snark_info) ->
          Snark_coordinator
            (name, { snark_info with libp2p_keyfile = libp2p_keyfile name }) )
  in
  let genesis_keypairs =
    String.Map.of_alist_exn
      (List.map (String.Map.to_alist genesis_ledger_accounts) ~f:(fun element ->
           let kp_name, (_, (keypair, _)) = element in
           (kp_name, keypair) ) )
  in
  let snark_coordinator_config =
    match snark_coordinator with
    | None ->
        None
    | Some snark ->
        let network_kp =
          match String.Map.find genesis_keypairs snark.account_name with
          | Some acct ->
              acct
          | None ->
              let failstring =
                Format.sprintf
                  "Failing because the account key of all initial snark \
                   coordinators must be in the genesis ledger.  name of Node: \
                   %s.  name of Account which does not exist: %s"
                  snark.node_name snark.account_name
              in
              failwith failstring
        in
        Some
          (let[@warning "-8"] (Test_config.Topology.Snark_coordinator
                                (_, snark_info) ) =
             List.find_exn topology ~f:(function
               | Snark_coordinator (name, _) ->
                   String.equal name snark.node_name
               | _ ->
                   false )
           in
           { name = snark.node_name
           ; public_key =
               Public_key.Compressed.to_base58_check
                 (Public_key.compress network_kp.keypair.public_key)
           ; worker_nodes = snark.worker_nodes
           ; libp2p_pass = "naughty blue worm"
           ; libp2p_keypair = snark_info.libp2p_keypair
           ; libp2p_peerid =
               Yojson.Safe.to_string snark_info.libp2p_peerid
               |> Util.drop_outer_quotes
           } )
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
      ; seed_node_configs
      ; log_precomputed_blocks
      ; archive_node_count = List.length archive_nodes
      ; mina_archive_schema
      ; mina_archive_schema_aux_files
      ; snark_coordinator_config
      ; snark_worker_fee
      ; topology = Test_config.Topology.to_yojson topology
      }
  }
