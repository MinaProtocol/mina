open Core_kernel
open Async
open Currency
open Signature_lib
open Mina_base
open Integration_test_lib

let aws_region = "us-west-2"

let aws_route53_zone_id = "ZJPR9NA6W9M7F"

let project_id = "o1labs-192920"

let cluster_id = "gke_o1labs-192920_us-west1_mina-integration-west1"

let cluster_name = "mina-integration-west1"

let cluster_region = "us-west1"

let cluster_zone = "us-west1a"

module Network_config = struct
  module Cli_inputs = Cli_inputs

  type block_producer_config =
    { name : string; keypair : Network_keypair.t; libp2p_secret : string }
  [@@deriving to_yojson]

  type snark_coordinator_config =
    { name : string; public_key : string; worker_nodes : int }
  [@@deriving to_yojson]

  type terraform_config =
    { k8s_context : string
    ; cluster_name : string
    ; cluster_region : string
    ; aws_route53_zone_id : string
    ; testnet_name : string
    ; deploy_graphql_ingress : bool
    ; mina_image : string
    ; mina_agent_image : string
    ; mina_bots_image : string
    ; mina_points_image : string
    ; mina_archive_image : string
          (* this field needs to be sent as a string to terraform, even though it's a json encoded value *)
    ; runtime_config : Yojson.Safe.t
          [@to_yojson fun j -> `String (Yojson.Safe.to_string j)]
    ; block_producer_configs : block_producer_config list
    ; log_precomputed_blocks : bool
    ; archive_node_count : int
    ; mina_archive_schema : string
    ; mina_archive_schema_aux_files : string list
    ; snark_coordinator_config : snark_coordinator_config option
    ; snark_worker_fee : string
    ; cpu_request : int
    ; mem_request : string
    ; worker_cpu_request : int
    ; worker_mem_request : string
    }
  [@@deriving to_yojson]

  type t =
    { mina_automation_location : string
    ; debug_arg : bool
    ; check_capacity : bool
    ; check_capacity_delay : int
    ; check_capacity_retries : int
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
    ; terraform : terraform_config
    }
  [@@deriving to_yojson]

  let terraform_config_to_assoc t =
    let[@warning "-8"] (`Assoc assoc : Yojson.Safe.t) =
      terraform_config_to_yojson t
    in
    assoc

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
    (* see ./src/app/test_executive/README.md for information regarding the namespace name format and length restrictions *)
    let testnet_name = "it-" ^ user ^ "-" ^ git_commit ^ "-" ^ test_name in
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
    { mina_automation_location = cli_inputs.mina_automation_location
    ; debug_arg = debug
    ; check_capacity = cli_inputs.check_capacity
    ; check_capacity_delay = cli_inputs.check_capacity_delay
    ; check_capacity_retries = cli_inputs.check_capacity_retries
    ; genesis_keypairs
    ; constants
    ; terraform =
        { cluster_name
        ; cluster_region
        ; k8s_context = cluster_id
        ; testnet_name
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
        ; aws_route53_zone_id
        ; cpu_request = 6
        ; mem_request = "12Gi"
        ; worker_cpu_request = 6
        ; worker_mem_request = "8Gi"
        }
    }

  let to_terraform network_config =
    let open Terraform in
    [ Block.Terraform
        { Block.Terraform.required_version = ">= 0.12.0"
        ; backend =
            Backend.Local
              { path =
                  "terraform-" ^ network_config.terraform.testnet_name
                  ^ ".tfstate"
              }
        }
    ; Block.Provider
        { Block.Provider.provider = "google"
        ; region = cluster_region
        ; zone = Some cluster_zone
        ; project = Some project_id
        ; alias = None
        }
    ; Block.Module
        { Block.Module.local_name = "integration_testnet"
        ; providers = [ ("google.gke", "google") ]
        ; source = "../../modules/o1-integration"
        ; args = terraform_config_to_assoc network_config.terraform
        }
    ]

  let testnet_log_filter network_config =
    Printf.sprintf
      {|
        resource.labels.project_id="%s"
        resource.labels.location="%s"
        resource.labels.cluster_name="%s"
        resource.labels.namespace_name="%s"
      |}
      project_id cluster_region cluster_name
      network_config.terraform.testnet_name
end

module Network_id = struct
  type t = string [@@deriving eq, yojson]
end

module Node_id = struct
  type t = string [@@deriving eq, yojson]
end

module Request = struct
  type t =
    | Access_token
    | Create_network of Network_config.t
    | Deploy_network of Network_id.t
    | Destroy_network of Network_id.t
    | Get_node_logs of Node_id.t
  [@@deriving to_yojson]
end

module Node_type = struct
  type t =
    | Archive_node
    | Block_producer_node
    | Non_seed_node
    | Seed_node
    | Snark_coordinator
  [@@deriving eq, yojson]

  let to_string nt = to_yojson nt |> Yojson.Safe.to_string

  let of_string s = of_yojson @@ `List [ `String s ] |> Result.ok_or_failwith
end

module Network_deploy_response = struct
  module Map = Map.Make (String)
  include Map

  type t = (Node_type.t * string) Map.t [@@deriving eq]

  let of_yojson =
    let f accum = function
      | node_id, `Tuple [ `String nt; `String gql_uri ] ->
          Map.set accum ~key:node_id ~data:(Node_type.of_string nt, gql_uri)
      | _ ->
          failwith "invalid network_deploy_response yojson entry"
    in
    function
    | `Assoc a_list ->
        Ok (List.fold a_list ~init:(Map.empty : t) ~f)
    | _ ->
        Error "invalid network_deploy_response yojson"
end

module Access_token = struct
  type t = string [@@deriving eq, yojson]
end

module Response = struct
  type t =
    | Access_token of Access_token.t
    | Network_created of Network_id.t
    | Network_deployed of Network_deploy_response.t
    | Network_destroyed
    | Node_logs of Node_id.t * string
  [@@deriving eq, of_yojson]
end

(**
  The general workflow could look something like this:
  https://www.notion.so/minafoundation/Lucy-CI-Interactions-e36b48ac52994cafbe1367548e02241d?pvs=4
  *)

let request_ci_access_token () : Response.t Deferred.Or_error.t =
  failwith "request_ci_access_token"

(* for example, we can communicate with the CI via https and test-specific access token *)
let[@warning "-27"] send_ci_http_request ~(access_token : Access_token.t)
    ~(request_body : Request.t) : Response.t Deferred.Or_error.t =
  let req_str = request_body |> Request.to_yojson |> Yojson.Safe.to_string in
  failwithf "send_ci_http_request: %s\n" req_str ()

module Request_unit_tests = struct
  let%test_unit "Create network request" = assert true
  (* TODO: too complicated for now *)

  let%test_unit "Deploy network request" =
    let open Request in
    let result =
      Deploy_network "network0" |> to_yojson |> Yojson.Safe.to_string
    in
    let ( = ) = String.equal in
    assert (result = {|["Deploy_network","network0"]|})

  let%test_unit "Destroy network request" =
    let open Request in
    let result =
      Destroy_network "network0" |> to_yojson |> Yojson.Safe.to_string
    in
    let ( = ) = String.equal in
    assert (result = {|["Destroy_network","network0"]|})

  let%test_unit "Get node logs request" =
    let open Request in
    let result = Get_node_logs "node0" |> to_yojson |> Yojson.Safe.to_string in
    let ( = ) = String.equal in
    assert (result = {|["Get_node_logs","node0"]|})
end

module Response_unit_tests = struct
  let%test_unit "Parse network created response" =
    let open Response in
    let result =
      `List [ `String "Network_created"; `String "node0" ]
      |> of_yojson |> Result.ok_or_failwith
    in
    let ( = ) = equal in
    assert (result = Network_created "node0")

  let%test_unit "Parse network deployed response" =
    let open Node_type in
    let open Network_deploy_response in
    let result =
      {|
        { "node0": ("Archive_node", "gql0")
        , "node1": ("Block_producer_node", "gql1")
        , "node2": ("Non_seed_node", "gql2")
        , "node3": ("Seed_node", "gql3")
        , "node4": ("Snark_coordinator", "gql4")
        }
      |}
      |> Yojson.Safe.from_string |> of_yojson |> Result.ok_or_failwith
    in
    let ( = ) = equal in
    assert (
      result
      = of_alist_exn
          [ ("node0", (Archive_node, "gql0"))
          ; ("node1", (Block_producer_node, "gql1"))
          ; ("node2", (Non_seed_node, "gql2"))
          ; ("node3", (Seed_node, "gql3"))
          ; ("node4", (Snark_coordinator, "gql4"))
          ] )

  let%test_unit "Parse network destroyed response" =
    let open Response in
    let result =
      `List [ `String "Network_destroyed" ]
      |> of_yojson |> Result.ok_or_failwith
    in
    assert (equal result Network_destroyed)

  let%test_unit "Parse node logs response" =
    let open Response in
    let result =
      `List [ `String "Node_logs"; `String "node0"; `String "node0_logs" ]
      |> of_yojson |> Result.ok_or_failwith
    in
    let ( = ) = equal in
    assert (result = Node_logs ("node0", "node0_logs"))
end
