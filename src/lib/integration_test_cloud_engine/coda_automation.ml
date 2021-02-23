open Core
open Async
open Currency
open Signature_lib
open Mina_base
open Cmd_util
open Integration_test_lib
open Unix

let aws_region = "us-west-2"

let project_id = "o1labs-192920"

let cluster_id = "gke_o1labs-192920_us-west1_mina-integration-west1"

let cluster_name = "mina-integration-west1"

let cluster_region = "us-west1"

let cluster_zone = "us-west1a"

type network_keypair =
  { keypair: Keypair.t
  ; secret_name: string
  ; public_key_file: string
  ; private_key_file: string }
[@@deriving to_yojson]

let create_network_keypair ~keypair ~secret_name =
  let open Keypair in
  let public_key_file =
    Public_key.Compressed.to_base58_check
      (Public_key.compress keypair.public_key)
    ^ "\n"
  in
  let private_key_file =
    let plaintext =
      Bigstring.to_bytes (Private_key.to_bigstring keypair.private_key)
    in
    let password = Bytes.of_string "naughty blue worm" in
    Secrets.Secret_box.encrypt ~plaintext ~password
    |> Secrets.Secret_box.to_yojson |> Yojson.Safe.to_string
  in
  {keypair; secret_name; public_key_file; private_key_file}

module Network_config = struct
  module Cli_inputs = Cli_inputs

  type block_producer_config =
    { name: string
    ; id: string
    ; public_key: string
    ; private_key: string
    ; keypair_secret: string
    ; libp2p_secret: string }
  [@@deriving to_yojson]

  type terraform_config =
    { k8s_context: string
    ; cluster_name: string
    ; cluster_region: string
    ; testnet_name: string
    ; coda_image: string
    ; coda_agent_image: string
    ; coda_bots_image: string
    ; coda_points_image: string
    ; coda_archive_image: string
          (* this field needs to be sent as a string to terraform, even though it's a json encoded value *)
    ; runtime_config: Yojson.Safe.t
          [@to_yojson fun j -> `String (Yojson.Safe.to_string j)]
    ; block_producer_configs: block_producer_config list
    ; snark_worker_replicas: int
    ; snark_worker_fee: string
    ; snark_worker_public_key: string }
  [@@deriving to_yojson]

  type t =
    { coda_automation_location: string
    ; keypairs: network_keypair list
    ; constants: Test_config.constants
    ; terraform: terraform_config }
  [@@deriving to_yojson]

  let terraform_config_to_assoc t =
    let[@warning "-8"] (`Assoc assoc : Yojson.Safe.t) =
      terraform_config_to_yojson t
    in
    assoc

  let expand ~logger ~test_name ~(cli_inputs : Cli_inputs.t)
      ~(test_config : Test_config.t) ~(images : Test_config.Container_images.t)
      =
    let { Test_config.k
        ; delta
        ; slots_per_epoch
        ; slots_per_sub_window
        ; proof_level
        ; txpool_max_size
        ; block_producers
        ; num_snark_workers
        ; snark_worker_fee
        ; snark_worker_public_key } =
      test_config
    in
    let user_from_env = Option.value (Unix.getenv "USER") ~default:"auto" in
    let user_sanitized =
      Str.global_replace (Str.regexp "\\W|_-") "" user_from_env
    in
    let user_len = Int.min 5 (String.length user_sanitized) in
    let user = String.sub user_sanitized ~pos:0 ~len:user_len in
    let git_commit = Mina_version.commit_id_short in
    let time_now = Unix.gmtime (Unix.gettimeofday ()) in
    let timestr =
      string_of_int time_now.tm_mday
      ^ string_of_int time_now.tm_hour
      ^ string_of_int time_now.tm_min
    in
    (* see ./src/app/test_executive/README.md for information regarding the namespace name format and length restrictions *)
    let testnet_name =
      user ^ "-" ^ git_commit ^ "-" ^ test_name ^ "-" ^ timestr
    in
    (* GENERATE ACCOUNTS AND KEYPAIRS *)
    let num_block_producers = List.length block_producers in
    let block_producer_keypairs, runtime_accounts =
      (* the first keypair is the genesis winner and is assumed to be untimed. Therefore dropping it, and not assigning it to any block producer *)
      let keypairs =
        List.drop (Array.to_list (Lazy.force Sample_keypairs.keypairs)) 1
      in
      if num_block_producers > List.length keypairs then
        failwith
          "not enough sample keypairs for specified number of block producers" ;
      let f index ({Test_config.Block_producer.balance; timing}, (pk, sk)) =
        let runtime_account =
          let timing =
            match timing with
            | Account.Timing.Untimed ->
                None
            | Timed t ->
                Some
                  { Runtime_config.Accounts.Single.Timed.initial_minimum_balance=
                      t.initial_minimum_balance
                  ; cliff_time= t.cliff_time
                  ; cliff_amount= t.cliff_amount
                  ; vesting_period= t.vesting_period
                  ; vesting_increment= t.vesting_increment }
          in
          let default = Runtime_config.Accounts.Single.default in
          { default with
            pk= Some (Public_key.Compressed.to_string pk)
          ; sk= None
          ; balance=
              Balance.of_formatted_string balance
              (* delegation currently unsupported *)
          ; delegate= None
          ; timing }
        in
        let secret_name = "test-keypair-" ^ Int.to_string index in
        let keypair =
          {Keypair.public_key= Public_key.decompress_exn pk; private_key= sk}
        in
        (create_network_keypair ~keypair ~secret_name, runtime_account)
      in
      List.mapi ~f
        (List.zip_exn block_producers
           (List.take keypairs (List.length block_producers)))
      |> List.unzip
    in
    (* DAEMON CONFIG *)
    let proof_config =
      (* TODO: lift configuration of these up Test_config.t *)
      { Runtime_config.Proof_keys.level= Some proof_level
      ; sub_windows_per_window= None
      ; ledger_depth= None
      ; work_delay= None
      ; block_window_duration_ms= None
      ; transaction_capacity= None
      ; coinbase_amount= None
      ; supercharged_coinbase_factor= None
      ; account_creation_fee= None
      ; fork= None }
    in
    let constraint_constants =
      Genesis_ledger_helper.make_constraint_constants
        ~default:Genesis_constants.Constraint_constants.compiled proof_config
    in
    let runtime_config =
      { Runtime_config.daemon= Some {txpool_max_size= Some txpool_max_size}
      ; genesis=
          Some
            { k= Some k
            ; delta= Some delta
            ; slots_per_epoch= Some slots_per_epoch
            ; sub_windows_per_window=
                Some constraint_constants.supercharged_coinbase_factor
            ; slots_per_sub_window= Some slots_per_sub_window
            ; genesis_state_timestamp=
                Some Core.Time.(to_string_abs ~zone:Zone.utc (now ())) }
      ; proof= Some proof_config (* TODO: prebake ledger and only set hash *)
      ; ledger=
          Some
            { base= Accounts runtime_accounts
            ; add_genesis_winner= None
            ; num_accounts= None
            ; balances= []
            ; hash= None
            ; name= None }
      ; epoch_data= None }
    in
    let genesis_constants =
      Or_error.ok_exn
        (Genesis_ledger_helper.make_genesis_constants ~logger
           ~default:Genesis_constants.compiled runtime_config)
    in
    let constants : Test_config.constants =
      {constraints= constraint_constants; genesis= genesis_constants}
    in
    (* BLOCK PRODUCER CONFIG *)
    let block_producer_config index keypair =
      { name= "test-block-producer-" ^ Int.to_string (index + 1)
      ; id= Int.to_string index
      ; keypair_secret= keypair.secret_name
      ; public_key= keypair.public_key_file
      ; private_key= keypair.private_key_file
      ; libp2p_secret= "" }
    in
    (* NETWORK CONFIG *)
    { coda_automation_location= cli_inputs.coda_automation_location
    ; keypairs= block_producer_keypairs
    ; constants
    ; terraform=
        { cluster_name
        ; cluster_region
        ; k8s_context= cluster_id
        ; testnet_name
        ; coda_image= images.coda
        ; coda_agent_image= images.user_agent
        ; coda_bots_image= images.bots
        ; coda_points_image= images.points
        ; coda_archive_image= ""
        ; runtime_config= Runtime_config.to_yojson runtime_config
        ; block_producer_configs=
            List.mapi block_producer_keypairs ~f:block_producer_config
        ; snark_worker_replicas= num_snark_workers
        ; snark_worker_public_key
        ; snark_worker_fee } }

  let to_terraform network_config =
    let open Terraform in
    [ Block.Terraform
        { Block.Terraform.required_version= ">= 0.12.0"
        ; backend=
            Backend.S3
              { Backend.S3.key=
                  "terraform-" ^ network_config.terraform.testnet_name
                  ^ ".tfstate"
              ; encrypt= true
              ; region= aws_region
              ; bucket= "o1labs-terraform-state"
              ; acl= "bucket-owner-full-control" } }
    ; Block.Provider
        { Block.Provider.provider= "aws"
        ; region= aws_region
        ; zone= None
        ; project= None
        ; alias= None }
    ; Block.Provider
        { Block.Provider.provider= "google"
        ; region= cluster_region
        ; zone= Some cluster_zone
        ; project= Some project_id
        ; alias= None }
    ; Block.Module
        { Block.Module.local_name= "integration_testnet"
        ; providers= [("google.gke", "google")]
        ; source= "../../modules/o1-integration"
        ; args= terraform_config_to_assoc network_config.terraform } ]

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

module Network_manager = struct
  type t =
    { logger: Logger.t
    ; cluster: string
    ; namespace: string
    ; testnet_dir: string
    ; testnet_log_filter: string
    ; constants: Test_config.constants
    ; seed_nodes: Kubernetes_network.Node.t list
    ; block_producer_nodes: Kubernetes_network.Node.t list
    ; snark_coordinator_nodes: Kubernetes_network.Node.t list
    ; nodes_by_app_id: Kubernetes_network.Node.t String.Map.t
    ; mutable deployed: bool
    ; keypairs: Keypair.t list }

  let run_cmd t prog args = run_cmd t.testnet_dir prog args

  let run_cmd_exn t prog args = run_cmd_exn t.testnet_dir prog args

  let create ~logger (network_config : Network_config.t) =
    let testnet_dir =
      network_config.coda_automation_location ^/ "terraform/testnets"
      ^/ network_config.terraform.testnet_name
    in
    (* cleanup old deployment, if it exists; we will need to take good care of this logic when we put this in CI *)
    let%bind () =
      if%bind File_system.dir_exists testnet_dir then (
        [%log warn]
          "Old network deployment found; attempting to refresh and cleanup" ;
        let%bind _ =
          Cmd_util.run_cmd_exn testnet_dir "terraform" ["refresh"]
        in
        let%bind _ =
          let open Process.Output in
          let%bind state_output =
            Cmd_util.run_cmd testnet_dir "terraform" ["state"; "list"]
          in
          if not (String.is_empty state_output.stdout) then
            let%map _ =
              Cmd_util.run_cmd_exn testnet_dir "terraform"
                ["destroy"; "-auto-approve"]
            in
            ()
          else return ()
        in
        File_system.remove_dir testnet_dir )
      else return ()
    in
    [%log info] "Writing network configuration" ;
    let%bind () = Unix.mkdir testnet_dir in
    (* TODO: prebuild genesis proof and ledger *)
    (*
    let%bind inputs =
      Genesis_ledger_helper.Genesis_proof.generate_inputs ~proof_level ~ledger
        ~constraint_constants ~genesis_constants
    in
    let%bind (_, genesis_proof_filename) =
      Genesis_ledger_helper.Genesis_proof.load_or_generate ~logger ~genesis_dir ~may_generate:true
        inputs
    in
    *)
    Out_channel.with_file ~fail_if_exists:true (testnet_dir ^/ "main.tf.json")
      ~f:(fun ch ->
        Network_config.to_terraform network_config
        |> Terraform.to_string
        |> Out_channel.output_string ch ) ;
    let testnet_log_filter =
      Network_config.testnet_log_filter network_config
    in
    let cons_node pod_id port =
      { Kubernetes_network.Node.cluster= cluster_id
      ; Kubernetes_network.Node.namespace=
          network_config.terraform.testnet_name
      ; Kubernetes_network.Node.pod_id
      ; Kubernetes_network.Node.node_graphql_port= port }
    in
    (* we currently only deploy 1 seed and coordinator per deploy (will be configurable later) *)
    let seed_nodes = [cons_node "seed" 3085] in
    let snark_coordinator_nodes = [cons_node "snark-coordinator-1" 3085] in
    let block_producer_nodes =
      List.init (List.length network_config.terraform.block_producer_configs)
        ~f:(fun i ->
          cons_node (Printf.sprintf "test-block-producer-%d" (i + 1)) (i + 3086)
      )
    in
    let nodes_by_app_id =
      let all_nodes =
        seed_nodes @ snark_coordinator_nodes @ block_producer_nodes
      in
      all_nodes
      |> List.map ~f:(fun node -> (node.pod_id, node))
      |> String.Map.of_alist_exn
    in
    let t =
      { logger
      ; cluster= cluster_id
      ; namespace= network_config.terraform.testnet_name
      ; testnet_dir
      ; testnet_log_filter
      ; constants= network_config.constants
      ; seed_nodes
      ; block_producer_nodes
      ; snark_coordinator_nodes
      ; nodes_by_app_id
      ; deployed= false
      ; keypairs=
          List.map network_config.keypairs ~f:(fun {keypair; _} -> keypair) }
    in
    [%log info] "Initializing terraform" ;
    let%bind _ = run_cmd_exn t "terraform" ["init"] in
    let%map _ = run_cmd_exn t "terraform" ["validate"] in
    t

  let deploy t =
    if t.deployed then failwith "network already deployed" ;
    [%log' info t.logger] "Deploying network" ;
    let%map _ = run_cmd_exn t "terraform" ["apply"; "-auto-approve"] in
    t.deployed <- true ;
    let result =
      { Kubernetes_network.namespace= t.namespace
      ; constants= t.constants
      ; block_producers= t.block_producer_nodes
      ; snark_coordinators= t.snark_coordinator_nodes
      ; archive_nodes= []
      ; nodes_by_app_id= t.nodes_by_app_id
      ; testnet_log_filter= t.testnet_log_filter
      ; keypairs= t.keypairs }
    in
    [%log' info t.logger] "Network deployed" ;
    [%log' info t.logger] "snark_coordinators_list: %s"
      (Kubernetes_network.Node.node_list_to_string result.snark_coordinators) ;
    [%log' info t.logger] "block_producers_list: %s"
      (Kubernetes_network.Node.node_list_to_string result.block_producers) ;
    [%log' info t.logger] "archive_nodes_list: %s"
      (Kubernetes_network.Node.node_list_to_string result.archive_nodes) ;
    result

  let destroy t =
    [%log' info t.logger] "Destroying network" ;
    if not t.deployed then failwith "network not deployed" ;
    let%bind _ = run_cmd_exn t "terraform" ["destroy"; "-auto-approve"] in
    t.deployed <- false ;
    Deferred.unit

  let cleanup t =
    let%bind () = if t.deployed then destroy t else return () in
    [%log' info t.logger] "Cleaning up network configuration" ;
    let%bind () = File_system.remove_dir t.testnet_dir in
    Deferred.unit
end
