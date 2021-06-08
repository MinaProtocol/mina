open Core
open Async
open Currency
open Signature_lib
open Mina_base
open Integration_test_lib

let version = "3.9"

module Network_config = struct
  module Cli_inputs = Cli_inputs

  type docker_volume_configs = {name: string; data: string}
  [@@deriving to_yojson]

  type block_producer_config =
    { name: string
    ; id: string
    ; keypair: Network_keypair.t
    ; public_key: string
    ; private_key: string
    ; keypair_secret: string
    ; libp2p_secret: string }
  [@@deriving to_yojson]

  type docker_config =
    { version: string
    ; stack_name: string
    ; coda_image: string
    ; docker_volume_configs: docker_volume_configs list
    ; block_producer_configs: block_producer_config list
    ; log_precomputed_blocks: bool
    ; archive_node_count: int
    ; mina_archive_schema: string
    ; snark_worker_replicas: int
    ; snark_worker_fee: string
    ; snark_worker_public_key: string
    ; runtime_config: Yojson.Safe.t
          [@to_yojson fun j -> `String (Yojson.Safe.to_string j)] }
  [@@deriving to_yojson]

  type t =
    { mina_automation_location: string
    ; keypairs: Network_keypair.t list
    ; debug_arg: bool
    ; constants: Test_config.constants
    ; docker: docker_config }
  [@@deriving to_yojson]

  let expand ~logger ~test_name ~(cli_inputs : Cli_inputs.t) ~(debug : bool)
      ~(test_config : Test_config.t) ~(images : Test_config.Container_images.t)
      =
    let { Test_config.k
        ; delta
        ; slots_per_epoch
        ; slots_per_sub_window
        ; proof_level
        ; txpool_max_size
        ; requires_graphql= _
        ; block_producers
        ; num_snark_workers
        ; num_archive_nodes
        ; log_precomputed_blocks
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
    (* see ./src/app/test_executive/README.md for information regarding the namespace name format and length restrictions *)
    let stack_name = "it-" ^ user ^ "-" ^ git_commit ^ "-" ^ test_name in
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
        ( Network_keypair.create_network_keypair ~keypair ~secret_name
        , runtime_account )
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
      { Runtime_config.daemon=
          Some {txpool_max_size= Some txpool_max_size; peer_list_url= None}
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
      ; proof=
          None
          (* was: Some proof_config; TODO: prebake ledger and only set hash *)
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
      ; keypair
      ; keypair_secret= keypair.secret_name
      ; public_key= keypair.public_key_file
      ; private_key= keypair.private_key_file
      ; libp2p_secret= "" }
    in
    let block_producer_configs =
      List.mapi block_producer_keypairs ~f:block_producer_config
    in
    (* Combine configs for block producer configs and runtime config to be a docker bind volume *)
    let docker_volume_configs =
      List.map block_producer_configs ~f:(fun config ->
          {name= "sk_" ^ config.name; data= config.private_key} )
      @ [ { name= "runtime_config"
          ; data=
              Yojson.Safe.to_string (Runtime_config.to_yojson runtime_config)
          } ]
    in
    let mina_archive_schema =
      "https://raw.githubusercontent.com/MinaProtocol/mina/develop/src/app/archive/create_schema.sql"
    in
    { mina_automation_location= cli_inputs.coda_automation_location
    ; debug_arg= debug
    ; keypairs= block_producer_keypairs
    ; constants
    ; docker=
        { version
        ; stack_name
        ; coda_image= images.coda
        ; docker_volume_configs
        ; runtime_config= Runtime_config.to_yojson runtime_config
        ; block_producer_configs
        ; log_precomputed_blocks
        ; archive_node_count= num_archive_nodes
        ; mina_archive_schema
        ; snark_worker_replicas= num_snark_workers
        ; snark_worker_public_key
        ; snark_worker_fee } }

  let to_docker network_config =
    let default_seed_envs =
      [ ("DAEMON_REST_PORT", "3085")
      ; ("DAEMON_CLIENT_PORT", "8301")
      ; ("DAEMON_METRICS_PORT", "10001")
      ; ("CODA_LIBP2P_PASS", "") ]
    in
    let default_block_producer_envs =
      [ ("DAEMON_REST_PORT", "3085")
      ; ("DAEMON_CLIENT_PORT", "8301")
      ; ("DAEMON_METRICS_PORT", "10001")
      ; ("CODA_PRIVKEY_PASS", "naughty blue worm")
      ; ("CODA_LIBP2P_PASS", "") ]
    in
    let default_seed_command ~runtime_config =
      [ "daemon"
      ; "-log-level"
      ; "Debug"
      ; "-log-json"
      ; "-log-snark-work-gossip"
      ; "true"
      ; "-client-port"
      ; "8301"
      ; "-generate-genesis-proof"
      ; "true"
      ; "-peer"
      ; "/dns4/mina_seed-node/tcp/10401/p2p/12D3KooWCoGWacXE4FRwAX8VqhnWVKhz5TTEecWEuGmiNrDt2XLf"
      ; "-seed"
      ; "-config-file"
      ; runtime_config ]
    in
    let default_block_producer_command ~runtime_config ~private_key_config =
      [ "daemon"
      ; "-log-level"
      ; "Debug"
      ; "-log-json"
      ; "-log-snark-work-gossip"
      ; "true"
      ; "-log-txn-pool-gossip"
      ; "true"
      ; "-enable-peer-exchange"
      ; "true"
      ; "-enable-flooding"
      ; "true"
      ; "-peer"
      ; "/dns4/mina_seed-node/tcp/10401/p2p/12D3KooWCoGWacXE4FRwAX8VqhnWVKhz5TTEecWEuGmiNrDt2XLf"
      ; "-client-port"
      ; "8301"
      ; "-generate-genesis-proof"
      ; "true"
      ; "-block-producer-key"
      ; private_key_config
      ; "-config-file"
      ; runtime_config ]
    in
    let default_snark_coord_command ~runtime_config ~snark_coordinator_key
        ~snark_worker_fee =
      [ "daemon"
      ; "-log-level"
      ; "Debug"
      ; "-log-json"
      ; "-log-snark-work-gossip"
      ; "true"
      ; "-log-txn-pool-gossip"
      ; "true"
      ; "-external-port"
      ; "10909"
      ; "-rest-port"
      ; "3085"
      ; "-client-port"
      ; "8301"
      ; "-work-selection"
      ; "seq"
      ; "-peer"
      ; "/dns4/mina_seed-node/tcp/10401/p2p/12D3KooWCoGWacXE4FRwAX8VqhnWVKhz5TTEecWEuGmiNrDt2XLf"
      ; "-run-snark-coordinator"
      ; snark_coordinator_key
      ; "-snark-worker-fee"
      ; snark_worker_fee
      ; "-config-file"
      ; runtime_config ]
    in
    let open Docker_compose.Compose in
    let runtime_config = Service.Volume.create "runtime_config" in
    let service_map =
      List.fold network_config.docker.block_producer_configs
        ~init:DockerMap.empty ~f:(fun accum config ->
          let private_key_config =
            Service.Volume.create ("sk_" ^ config.name)
          in
          Map.set accum ~key:config.name
            ~data:
              { Service.image= network_config.docker.coda_image
              ; volumes= [private_key_config; runtime_config]
              ; deploy= {replicas= 1}
              ; command=
                  default_block_producer_command
                    ~runtime_config:runtime_config.target
                    ~private_key_config:private_key_config.target
              ; environment=
                  Service.Environment.create default_block_producer_envs } )
      |> Map.set ~key:"seed"
           ~data:
             { Service.image= network_config.docker.coda_image
             ; volumes= [runtime_config]
             ; deploy= {replicas= 1}
             ; command=
                 default_seed_command ~runtime_config:runtime_config.target
             ; environment= Service.Environment.create default_seed_envs }
    in
    let service_map =
      if network_config.docker.snark_worker_replicas > 0 then
        Map.set service_map ~key:"snark_worker"
          ~data:
            { Service.image= network_config.docker.coda_image
            ; volumes= [runtime_config]
            ; deploy= {replicas= network_config.docker.snark_worker_replicas}
            ; command=
                default_snark_coord_command
                  ~runtime_config:runtime_config.target
                  ~snark_coordinator_key:
                    network_config.docker.snark_worker_public_key
                  ~snark_worker_fee:network_config.docker.snark_worker_fee
            ; environment= Service.Environment.create default_seed_envs }
      else service_map
    in
    {version; services= service_map}
end

module Network_manager = struct
  type t =
    { stack_name: string
    ; logger: Logger.t
    ; testnet_dir: string
    ; testnet_log_filter: string
    ; constants: Test_config.constants
    ; seed_nodes: Swarm_network.Node.t list
    ; nodes_by_app_id: Swarm_network.Node.t String.Map.t
    ; block_producer_nodes: Swarm_network.Node.t list
    ; mutable deployed: bool
    ; keypairs: Keypair.t list }

  let run_cmd t prog args = Util.run_cmd t.testnet_dir prog args

  let run_cmd_exn t prog args = Util.run_cmd_exn t.testnet_dir prog args

  let create ~logger (network_config : Network_config.t) =
    let%bind all_stacks_str =
      Util.run_cmd_exn "/" "docker" ["stack"; "ls"; "--format"; "{{.Name}}"]
    in
    let all_stacks = String.split ~on:'\n' all_stacks_str in
    let testnet_dir =
      network_config.mina_automation_location
      ^/ network_config.docker.stack_name
    in
    let%bind () =
      if
        List.mem all_stacks network_config.docker.stack_name
          ~equal:String.equal
      then
        let%bind () =
          if network_config.debug_arg then
            Util.prompt_continue
              "Existing stack name of same name detected, pausing startup. \
               Enter [y/Y] to continue on and remove existing stack name, \
               start clean, and run the test; press Ctrl-C to quit out: "
          else
            Deferred.return
              ([%log info]
                 "Existing namespace of same name detected; removing to start \
                  clean")
        in
        Util.run_cmd_exn "/" "docker"
          ["stack"; "rm"; network_config.docker.stack_name]
        >>| Fn.const ()
      else return ()
    in
    let%bind () =
      if%bind File_system.dir_exists testnet_dir then (
        [%log info] "Old docker stack directory found; removing to start clean" ;
        File_system.remove_dir testnet_dir )
      else return ()
    in
    let%bind () = Unix.mkdir testnet_dir in
    [%log info] "Writing network configuration" ;
    Out_channel.with_file ~fail_if_exists:true (testnet_dir ^/ "compose.json")
      ~f:(fun ch ->
        Network_config.to_docker network_config
        |> Docker_compose.to_string
        |> Out_channel.output_string ch ) ;
    List.iter network_config.docker.docker_volume_configs ~f:(fun config ->
        [%log info] "Writing volume config: %s" (testnet_dir ^/ config.name) ;
        Out_channel.with_file ~fail_if_exists:false
          (testnet_dir ^/ config.name) ~f:(fun ch ->
            config.data |> Out_channel.output_string ch ) ;
        ignore (Util.run_cmd_exn testnet_dir "chmod" ["600"; config.name]) ) ;
    let cons_node swarm_name service_id network_keypair_opt =
      { Swarm_network.Node.swarm_name
      ; service_id
      ; graphql_enabled= true
      ; network_keypair= network_keypair_opt }
    in
    let seed_nodes =
      [cons_node network_config.docker.stack_name "seed" None]
    in
    let block_producer_nodes =
      List.map network_config.docker.block_producer_configs
        ~f:(fun bp_config ->
          cons_node network_config.docker.stack_name
            (network_config.docker.stack_name ^ "_" ^ bp_config.name)
            (Some bp_config.keypair) )
    in
    let nodes_by_app_id =
      let all_nodes = seed_nodes @ block_producer_nodes in
      all_nodes
      |> List.map ~f:(fun node -> (node.service_id, node))
      |> String.Map.of_alist_exn
    in
    let t =
      { stack_name= network_config.docker.stack_name
      ; logger
      ; testnet_dir
      ; constants= network_config.constants
      ; seed_nodes
      ; block_producer_nodes
      ; nodes_by_app_id
      ; deployed= false
      ; testnet_log_filter= ""
      ; keypairs=
          List.map network_config.keypairs ~f:(fun {keypair; _} -> keypair) }
    in
    Deferred.return t

  let deploy t =
    if t.deployed then failwith "network already deployed" ;
    [%log' info t.logger] "Deploying network" ;
    [%log' info t.logger] "Stack_name in deploy: %s" t.stack_name ;
    let%map _ =
      run_cmd_exn t "docker"
        ["stack"; "deploy"; "-c"; "compose.json"; t.stack_name]
    in
    t.deployed <- true ;
    let result =
      { Swarm_network.namespace= t.stack_name
      ; constants= t.constants
      ; seeds= t.seed_nodes
      ; block_producers= t.block_producer_nodes
      ; snark_coordinators= []
      ; archive_nodes= []
      ; nodes_by_app_id= t.nodes_by_app_id
      ; testnet_log_filter= t.testnet_log_filter
      ; keypairs= t.keypairs }
    in
    let nodes_to_string =
      Fn.compose (String.concat ~sep:", ") (List.map ~f:Swarm_network.Node.id)
    in
    [%log' info t.logger] "Network deployed" ;
    [%log' info t.logger] "testnet swarm: %s" t.stack_name ;
    [%log' info t.logger] "snark coordinators: %s"
      (nodes_to_string result.snark_coordinators) ;
    [%log' info t.logger] "block producers: %s"
      (nodes_to_string result.block_producers) ;
    [%log' info t.logger] "archive nodes: %s"
      (nodes_to_string result.archive_nodes) ;
    result

  let destroy t =
    [%log' info t.logger] "Destroying network" ;
    if not t.deployed then failwith "network not deployed" ;
    let%bind _ = run_cmd_exn t "docker" ["stack"; "rm"; t.stack_name] in
    t.deployed <- false ;
    Deferred.unit

  let cleanup t =
    let%bind () = if t.deployed then destroy t else return () in
    [%log' info t.logger] "Cleaning up network configuration" ;
    let%bind () = File_system.remove_dir t.testnet_dir in
    Deferred.unit
end
