open Core
open Async
open Currency
open Signature_lib
open Coda_base
open Integration_test_lib

module Network_config = struct
  type block_producer_config =
    { name: string
    ; class_: string [@key "class"]
    ; id: string
    ; private_key_secret: string
    ; enable_gossip_flooding: bool
    ; run_with_user_agent: bool
    ; run_with_bots: bool }
  [@@deriving to_yojson]

  type terraform_config =
    { cluster_name: string
    ; cluster_region: string
    ; testnet_name: string
    ; coda_image: string
    ; coda_agent_image: string
    ; coda_bots_image: string
    ; coda_points_image: string
          (* this field needs to be sent as a string to terraform, even though it's a json encoded value *)
    ; runtime_config: Yojson.Safe.t
          [@to_yojson fun j -> `String (Yojson.Safe.to_string j)]
    ; coda_faucet_amount: string
    ; coda_faucet_fee: string
    ; seed_zone: string
    ; seed_region: string
    ; log_level: string
    ; log_txn_pool_gossip: bool
    ; block_producer_key_pass: string
    ; block_producer_starting_host_port: int
    ; block_producer_configs: block_producer_config list
    ; snark_worker_replicas: int
    ; snark_worker_fee: string
    ; snark_worker_public_key: string
    ; snark_worker_host_port: int
    ; agent_min_fee: string
    ; agent_max_fee: string
    ; agent_min_tx: string
    ; agent_max_tx: string }
  [@@deriving to_yojson]

  type t =
    { coda_automation_location: string
    ; project_id: string
    ; cluster_id: string
    ; keypairs: (string * Keypair.t) list
    ; constraint_constants: Genesis_constants.Constraint_constants.t
    ; genesis_constants: Genesis_constants.t
    ; terraform: terraform_config }
  [@@deriving to_yojson]

  let terraform_config_to_assoc t =
    let[@warning "-8"] (`Assoc assoc : Yojson.Safe.t) =
      terraform_config_to_yojson t
    in
    assoc

  let expand ~logger ~test_name ~(test_config : Test_config.t)
      ~(images : Container_images.t) =
    let { Test_config.k
        ; delta
        ; proof_level
        ; txpool_max_size
        ; block_producers
        ; num_snark_workers
        ; snark_worker_fee
        ; snark_worker_public_key } =
      test_config
    in
    let testnet_name = "integration-test-" ^ test_name in
    (* HARD CODED NETWORK VALUES *)
    let coda_automation_location = "coda-automation" in
    let project_id = "o1labs-192920" in
    let cluster_id = "gke_o1labs-192920_us-east1_coda-infra-east" in
    let cluster_name = "coda-infra-east" in
    let cluster_region = "us-east1" in
    let seed_zone = "us-east1-b" in
    let seed_region = "us-east1" in
    (* GENERATE ACCOUNTS AND KEYPAIRS *)
    let num_block_producers = List.length block_producers in
    let block_producer_keypairs, runtime_accounts =
      let keypairs = Array.to_list (Lazy.force Sample_keypairs.keypairs) in
      if List.length block_producers > List.length keypairs then
        failwith
          "not enough sample keypairs for specified number of block producers" ;
      let f index ({Test_config.Block_producer.balance}, (pk, sk)) =
        let runtime_account =
          { Runtime_config.Accounts.pk=
              Some (Public_key.Compressed.to_string pk)
          ; sk= None
          ; balance=
              Balance.of_formatted_string balance
              (* delegation currently unsupported *)
          ; delegate= None
          ; timing= None }
        in
        let secret_name = "test-keypair-" ^ Int.to_string index in
        let keypair =
          {Keypair.public_key= Public_key.decompress_exn pk; private_key= sk}
        in
        ((secret_name, keypair), runtime_account)
      in
      List.mapi ~f
        (List.zip_exn block_producers
           (List.take keypairs (List.length block_producers)))
      |> List.unzip
    in
    (* DEAMON CONFIG *)
    let proof_config =
      (* TODO: lift configuration of these up Test_config.t *)
      { Runtime_config.Proof_keys.level= Some proof_level
      ; c= None
      ; ledger_depth= None
      ; work_delay= None
      ; block_window_duration_ms= None
      ; transaction_capacity= None
      ; coinbase_amount= None
      ; account_creation_fee= None }
    in
    let runtime_config =
      { Runtime_config.daemon= Some {txpool_max_size= Some txpool_max_size}
      ; genesis=
          Some
            { k= Some k
            ; delta= Some delta
            ; genesis_state_timestamp=
                Some Core.Time.(to_string_abs ~zone:Zone.utc (now ())) }
      ; proof= Some proof_config (* TODO: prebake ledger and only set hash *)
      ; ledger=
          Some
            { base= Accounts runtime_accounts
            ; add_genesis_winner= None
            ; num_accounts= None
            ; hash= None
            ; name= None } }
    in
    let constraint_constants =
      Genesis_ledger_helper.make_constraint_constants
        ~default:Genesis_constants.Constraint_constants.compiled proof_config
    in
    let genesis_constants =
      Or_error.ok_exn
        (Genesis_ledger_helper.make_genesis_constants ~logger
           ~default:Genesis_constants.compiled runtime_config)
    in
    (* BLOCK PRODUCER CONFIG *)
    let base_port = 10001 in
    let block_producer_config index (secret_name, _) =
      { name= "test-block-producer-" ^ Int.to_string (index + 1)
      ; class_= "test"
      ; id= Int.to_string index
      ; private_key_secret= secret_name
      ; enable_gossip_flooding= false
      ; run_with_user_agent= false
      ; run_with_bots= false }
    in
    (* NETWORK CONFIG *)
    { coda_automation_location
    ; project_id
    ; cluster_id
    ; keypairs= block_producer_keypairs
    ; constraint_constants
    ; genesis_constants
    ; terraform=
        { cluster_name
        ; cluster_region
        ; testnet_name
        ; seed_zone
        ; seed_region
        ; coda_image= images.coda
        ; coda_agent_image= images.user_agent
        ; coda_bots_image= images.bots
        ; coda_points_image= images.points
        ; runtime_config= Runtime_config.to_yojson runtime_config
        ; block_producer_key_pass= "naughty blue worm"
        ; block_producer_starting_host_port= base_port
        ; block_producer_configs=
            List.mapi block_producer_keypairs ~f:block_producer_config
        ; snark_worker_replicas= num_snark_workers
        ; snark_worker_host_port= base_port + num_block_producers
        ; snark_worker_public_key
        ; snark_worker_fee
            (* log level is currently statically set and not directly configurable *)
        ; log_level= "Trace"
        ; log_txn_pool_gossip=
            true
            (* these currently aren't used for testnets, so we just give them defaults *)
        ; coda_faucet_amount= "10000000000"
        ; coda_faucet_fee= "100000000"
        ; agent_min_fee= "0.06"
        ; agent_max_fee= "0.1"
        ; agent_min_tx= "0.0015"
        ; agent_max_tx= "0.0015" } }

  let to_terraform network_config =
    let open Terraform in
    [ Block.Terraform
        { Block.Terraform.required_version= "~> 0.12.0"
        ; backend=
            Backend.S3
              { Backend.S3.key=
                  "terraform-" ^ network_config.terraform.testnet_name
                  ^ ".tfstate"
              ; encrypt= true
              ; region= "us-west-2"
              ; bucket= "o1labs-terraform-state"
              ; acl= "bucket-owner-full-control" } }
    ; Block.Provider
        { Block.Provider.provider= "aws"
        ; region= "us-west-2"
        ; zone= None
        ; alias= None
        ; project= None }
    ; Block.Provider
        { Block.Provider.provider= "google"
        ; region= network_config.terraform.cluster_region
        ; zone= Some "us-east1b"
        ; alias= Some "google-us-east1"
        ; project= Some network_config.project_id }
    ; Block.Module
        { Block.Module.local_name= "testnet_east"
        ; providers= [("google", ("google", "google-us-east1"))]
        ; source= "../../modules/kubernetes/testnet"
        ; args= terraform_config_to_assoc network_config.terraform } ]

  let testnet_log_filter network_config =
    Printf.sprintf
      {|
        resource.labels.project_id="%s"
        resource.labels.location="%s"
        resource.labels.cluster_name="%s"
        resource.labels.namespace_name="%s"
      |}
      network_config.project_id network_config.terraform.cluster_region
      network_config.terraform.cluster_name
      network_config.terraform.testnet_name
end

module Network_manager = struct
  type t =
    { cluster: string
    ; namespace: string
    ; keypair_secrets: string list
    ; testnet_dir: string
    ; testnet_log_filter: string
    ; constraint_constants: Genesis_constants.Constraint_constants.t
    ; genesis_constants: Genesis_constants.t
    ; block_producer_pod_names: string list
    ; snark_coordinator_pod_names: string list
    ; mutable deployed: bool }

  let run_cmd' testnet_dir prog args =
    Process.create_exn ~working_dir:testnet_dir ~prog ~args ()
    >>= Process.collect_output_and_wait

  let run_cmd_exn' testnet_dir prog args =
    let open Process.Output in
    let%bind output = run_cmd' testnet_dir prog args in
    let print_output () =
      let indent str =
        String.split str ~on:'\n'
        |> List.map ~f:(fun s -> "    " ^ s)
        |> String.concat ~sep:"\n"
      in
      print_endline "=== COMMAND ===" ;
      print_endline
        (indent
           ( prog ^ " "
           ^ String.concat ~sep:" "
               (List.map args ~f:(fun arg -> "\"" ^ arg ^ "\"")) )) ;
      print_endline "=== STDOUT ===" ;
      print_endline (indent output.stdout) ;
      print_endline "=== STDERR ===" ;
      print_endline (indent output.stderr) ;
      Writer.(flushed (Lazy.force stdout))
    in
    match output.exit_status with
    | Ok () ->
        return ()
    | Error (`Exit_non_zero status) ->
        let%map () = print_output () in
        failwithf "command exited with status code %d" status ()
    | Error (`Signal signal) ->
        let%map () = print_output () in
        failwithf "command exited prematurely due to signal %d"
          (Signal.to_system_int signal)
          ()

  let run_cmd t prog args = run_cmd' t.testnet_dir prog args

  let run_cmd_exn t prog args = run_cmd_exn' t.testnet_dir prog args

  let create (network_config : Network_config.t) =
    let testnet_dir =
      network_config.coda_automation_location ^/ "terraform/testnets"
      ^/ network_config.terraform.testnet_name
    in
    (* cleanup old deployment, if it exists; we will need to take good care of this logic when we put this in CI *)
    let%bind () =
      if%bind File_system.dir_exists testnet_dir then
        let%bind () = run_cmd_exn' testnet_dir "terraform" ["refresh"] in
        let%bind () =
          let open Process.Output in
          let%bind state_output =
            run_cmd' testnet_dir "terraform" ["state"; "list"]
          in
          if not (String.is_empty state_output.stdout) then
            run_cmd_exn' testnet_dir "terraform" ["destroy"; "-auto-approve"]
          else return ()
        in
        File_system.remove_dir testnet_dir
      else return ()
    in
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
    let%bind () =
      Deferred.List.iter network_config.keypairs
        ~f:(fun (secret_name, keypair) ->
          Secrets.Keypair.write_exn keypair
            ~privkey_path:(testnet_dir ^/ secret_name)
            ~password:(lazy (return (Bytes.of_string "naughty blue worm"))) )
    in
    let testnet_log_filter =
      Network_config.testnet_log_filter network_config
    in
    let block_producer_pod_names =
      List.init (List.length network_config.terraform.block_producer_configs)
        ~f:(fun i -> Printf.sprintf "test-block-producer-%d" (i + 1))
    in
    (* we currently only deploy 1 coordinator per deploy (will be configurable later) *)
    let snark_coordinator_pod_names = ["snark-coordinator-1"] in
    let t =
      { cluster= network_config.cluster_id
      ; namespace= network_config.terraform.testnet_name
      ; testnet_dir
      ; testnet_log_filter
      ; constraint_constants= network_config.constraint_constants
      ; genesis_constants= network_config.genesis_constants
      ; keypair_secrets= List.map network_config.keypairs ~f:fst
      ; block_producer_pod_names
      ; snark_coordinator_pod_names
      ; deployed= false }
    in
    let%bind () = run_cmd_exn t "terraform" ["init"] in
    let%map () = run_cmd_exn t "terraform" ["validate"] in
    t

  let deploy t =
    if t.deployed then failwith "network already deployed" ;
    let testnet_dir =
      t.network_config.coda_automation_location ^/ "terraform/testnets"
      ^/ network_config.terraform.testnet_name
    let%bind () = run_cmd_exn t "terraform" ["apply"; "-auto-approve"] in
    let%map () =
      Deferred.List.iter t.keypair_secrets ~f:(fun secret ->
          run_cmd_exn t "kubectl"
            [ "create"
            ; "secret"
            ; "generic"
            ; secret
            ; "--cluster=" ^ t.cluster
            ; "--namespace=" ^ t.namespace
            ; "--from-file=key=" ^ (testnet_dir ^/ secret)
            ; "--from-file=pub=" ^ (testnet_dir ^/ secret) ^ ".pub" ] )
    in
    t.deployed <- true ;
    { Kubernetes_network.constraint_constants= t.constraint_constants
    ; genesis_constants= t.genesis_constants
    ; block_producers= t.block_producer_pod_names
    ; snark_coordinators= t.snark_coordinator_pod_names
    ; archive_nodes= []
    ; testnet_log_filter= t.testnet_log_filter }

  let destroy t =
    print_endline "destroying network" ;
    if not t.deployed then failwith "network not deployed" ;
    let%map () = run_cmd_exn t "terraform" ["destroy"; "-auto-approve"] in
    t.deployed <- false

  let cleanup t =
    let%bind () = if t.deployed then destroy t else return () in
    File_system.remove_dir t.testnet_dir
end
