open Core
open Async
open Coda_base
open Coda_state
open Signature_lib
open Coda_inputs
open Signature_lib
open Pipe_lib

module Snark_worker_config = struct
  (* TODO : version *)
  type t = {port: int; public_key: Public_key.Compressed.Stable.V1.t}
  [@@deriving bin_io]
end

module Input = struct
  type t =
    { addrs_and_ports: Kademlia.Node_addrs_and_ports.t
    ; env: (string * string) list
    ; proposer: int option
    ; snark_worker_config: Snark_worker_config.t option
    ; work_selection: Cli_lib.Arg_type.work_selection
    ; conf_dir: string
    ; trace_dir: string option
    ; program_dir: string
    ; acceptable_delay: Time.Span.t
    ; peers: Host_and_port.t list
    ; max_concurrent_connections: int option }
  [@@deriving bin_io]
end

open Input

module Send_payment_input = struct
  (* TODO : version *)
  type t =
    Private_key.Stable.V1.t
    * Public_key.Compressed.Stable.V1.t
    * Currency.Amount.Stable.V1.t
    * Currency.Fee.Stable.V1.t
    * User_command_memo.Stable.V1.t
  [@@deriving bin_io]
end

module T = struct
  type state_hashes = bool list * bool list

  type 'worker functions =
    { peers: ('worker, unit, Network_peer.Peer.t list) Rpc_parallel.Function.t
    ; start: ('worker, unit, unit) Rpc_parallel.Function.t
    ; get_balance:
        ( 'worker
        , Public_key.Compressed.t
        , Currency.Balance.t option )
        Rpc_parallel.Function.t
    ; get_nonce:
        ( 'worker
        , Public_key.Compressed.t
        , Coda_numbers.Account_nonce.t option )
        Rpc_parallel.Function.t
    ; root_length: ('worker, unit, int) Rpc_parallel.Function.t
    ; send_user_command:
        ( 'worker
        , Send_payment_input.t
        , Receipt.Chain_hash.t Or_error.t )
        Rpc_parallel.Function.t
    ; process_user_command:
        ( 'worker
        , User_command.t
        , Receipt.Chain_hash.t Or_error.t )
        Rpc_parallel.Function.t
    ; verified_transitions:
        ('worker, unit, state_hashes Pipe.Reader.t) Rpc_parallel.Function.t
    ; sync_status:
        ('worker, unit, Sync_status.t Pipe.Reader.t) Rpc_parallel.Function.t
    ; get_all_user_commands:
        ( 'worker
        , Public_key.Compressed.t
        , User_command.t list )
        Rpc_parallel.Function.t
    ; new_user_command:
        ( 'worker
        , Public_key.Compressed.t
        , User_command.t Pipe.Reader.t )
        Rpc_parallel.Function.t
    ; root_diff:
        ( 'worker
        , unit
        , ([`User_commands of User_command.t list] * [`New_length of int])
          Pipe.Reader.t )
        Rpc_parallel.Function.t
    ; prove_receipt:
        ( 'worker
        , Receipt.Chain_hash.t * Receipt.Chain_hash.t
        , Payment_proof.t )
        Rpc_parallel.Function.t
    ; new_block:
        ( 'worker
        , Account.key
        , ( Auxiliary_database.Filtered_external_transition.t
          , State_hash.t )
          With_hash.t
          Pipe.Reader.t )
        Rpc_parallel.Function.t
    ; dump_tf: ('worker, unit, string) Rpc_parallel.Function.t
    ; best_path:
        ( 'worker
        , unit
        , State_hash.Stable.Latest.t list )
        Rpc_parallel.Function.t }

  type coda_functions =
    { coda_peers: unit -> Network_peer.Peer.t list Deferred.t
    ; coda_start: unit -> unit Deferred.t
    ; coda_get_balance:
           Public_key.Compressed.t
        -> Currency.Balance.Stable.V1.t option Deferred.t
    ; coda_get_nonce:
           Public_key.Compressed.t
        -> Coda_numbers.Account_nonce.t option Deferred.t
    ; coda_root_length: unit -> int Deferred.t
    ; coda_send_payment:
        Send_payment_input.t -> Receipt.Chain_hash.t Or_error.t Deferred.t
    ; coda_process_user_command:
        User_command.t -> Receipt.Chain_hash.t Or_error.t Deferred.t
    ; coda_verified_transitions: unit -> state_hashes Pipe.Reader.t Deferred.t
    ; coda_sync_status:
        unit -> Sync_status.Stable.V1.t Pipe.Reader.t Deferred.t
    ; coda_new_user_command:
           Public_key.Compressed.Stable.V1.t
        -> User_command.Stable.V1.t Pipe.Reader.t Deferred.t
    ; coda_get_all_user_commands:
           Public_key.Compressed.Stable.V1.t
        -> User_command.Stable.V1.t list Deferred.t
    ; coda_root_diff:
           unit
        -> ([`User_commands of User_command.t list] * [`New_length of int])
           Pipe.Reader.t
           Deferred.t
    ; coda_prove_receipt:
           Receipt.Chain_hash.t * Receipt.Chain_hash.t
        -> Payment_proof.t Deferred.t
    ; coda_new_block:
           Account.key
        -> ( Auxiliary_database.Filtered_external_transition.t
           , State_hash.t )
           With_hash.t
           Pipe.Reader.t
           Deferred.t
    ; coda_dump_tf: unit -> string Deferred.t
    ; coda_best_path: unit -> State_hash.Stable.Latest.t list Deferred.t }

  module Worker_state = struct
    type init_arg = Input.t [@@deriving bin_io]

    type t = coda_functions
  end

  module Connection_state = struct
    type init_arg = unit [@@deriving bin_io]

    type t = unit
  end

  module Functions
      (C : Rpc_parallel.Creator
           with type worker_state := Worker_state.t
            and type connection_state := Connection_state.t) =
  struct
    let peers_impl ~worker_state ~conn_state:() () = worker_state.coda_peers ()

    let verified_transitions_impl ~worker_state ~conn_state:() () =
      worker_state.coda_verified_transitions ()

    let sync_status_impl ~worker_state ~conn_state:() () =
      worker_state.coda_sync_status ()

    let new_user_command_impl ~worker_state ~conn_state:() pk =
      worker_state.coda_new_user_command pk

    let get_all_user_commands_impl ~worker_state ~conn_state:() pk =
      worker_state.coda_get_all_user_commands pk

    let root_diff_impl ~worker_state ~conn_state:() () =
      worker_state.coda_root_diff ()

    let get_balance_impl ~worker_state ~conn_state:() pk =
      worker_state.coda_get_balance pk

    let root_length_impl ~worker_state ~conn_state:() () =
      worker_state.coda_root_length ()

    let get_nonce_impl ~worker_state ~conn_state:() pk =
      worker_state.coda_get_nonce pk

    let send_payment_impl ~worker_state ~conn_state:() input =
      worker_state.coda_send_payment input

    let process_user_command_impl ~worker_state ~conn_state:() cmd =
      worker_state.coda_process_user_command cmd

    let prove_receipt_impl ~worker_state ~conn_state:() input =
      worker_state.coda_prove_receipt input

    let new_block_impl ~worker_state ~conn_state:() key =
      worker_state.coda_new_block key

    let start_impl ~worker_state ~conn_state:() () = worker_state.coda_start ()

    let dump_tf_impl ~worker_state ~conn_state:() () =
      worker_state.coda_dump_tf ()

    let best_path_impl ~worker_state ~conn_state:() () =
      worker_state.coda_best_path ()

    let peers =
      C.create_rpc ~f:peers_impl ~bin_input:Unit.bin_t
        ~bin_output:[%bin_type_class: Network_peer.Peer.Stable.V1.t list] ()

    let start =
      C.create_rpc ~f:start_impl ~bin_input:Unit.bin_t ~bin_output:Unit.bin_t
        ()

    let get_balance =
      C.create_rpc ~f:get_balance_impl
        ~bin_input:Public_key.Compressed.Stable.V1.bin_t
        ~bin_output:[%bin_type_class: Currency.Balance.Stable.V1.t option] ()

    let get_nonce =
      C.create_rpc ~f:get_nonce_impl
        ~bin_input:Public_key.Compressed.Stable.V1.bin_t
        ~bin_output:
          [%bin_type_class: Coda_numbers.Account_nonce.Stable.V1.t option] ()

    let root_length =
      C.create_rpc ~f:root_length_impl ~bin_input:Unit.bin_t
        ~bin_output:Int.bin_t ()

    let prove_receipt =
      C.create_rpc ~f:prove_receipt_impl
        ~bin_input:
          [%bin_type_class:
            Receipt.Chain_hash.Stable.V1.t * Receipt.Chain_hash.Stable.V1.t]
        ~bin_output:Payment_proof.bin_t ()

    let new_block =
      C.create_pipe ~f:new_block_impl
        ~bin_input:[%bin_type_class: Account.Stable.V1.key]
        ~bin_output:
          [%bin_type_class:
            ( Auxiliary_database.Filtered_external_transition.Stable.V1.t
            , State_hash.Stable.V1.t )
            With_hash.Stable.V1.t] ()

    let send_user_command =
      C.create_rpc ~f:send_payment_impl ~bin_input:Send_payment_input.bin_t
        ~bin_output:
          [%bin_type_class: Receipt.Chain_hash.Stable.V1.t Or_error.t] ()

    let process_user_command =
      C.create_rpc ~f:process_user_command_impl
        ~bin_input:User_command.Stable.Latest.bin_t
        ~bin_output:
          [%bin_type_class: Receipt.Chain_hash.Stable.V1.t Or_error.t] ()

    let verified_transitions =
      C.create_pipe ~f:verified_transitions_impl ~bin_input:Unit.bin_t
        ~bin_output:[%bin_type_class: bool list * bool list] ()

    let root_diff =
      C.create_pipe ~f:root_diff_impl ~bin_input:Unit.bin_t
        ~bin_output:
          [%bin_type_class:
            [`User_commands of User_command.Stable.V1.t list]
            * [`New_length of int]] ()

    let sync_status =
      C.create_pipe ~f:sync_status_impl ~bin_input:Unit.bin_t
        ~bin_output:Sync_status.Stable.V1.bin_t ()

    let new_user_command =
      C.create_pipe ~f:new_user_command_impl
        ~bin_input:Public_key.Compressed.Stable.V1.bin_t
        ~bin_output:User_command.Stable.V1.bin_t ()

    let get_all_user_commands =
      C.create_rpc ~f:get_all_user_commands_impl
        ~bin_input:Public_key.Compressed.Stable.V1.bin_t
        ~bin_output:[%bin_type_class: User_command.Stable.V1.t list] ()

    let dump_tf =
      C.create_rpc ~f:dump_tf_impl ~bin_input:Unit.bin_t
        ~bin_output:String.bin_t ()

    let best_path =
      C.create_rpc ~f:best_path_impl ~bin_input:Unit.bin_t
        ~bin_output:[%bin_type_class: State_hash.Stable.Latest.t list] ()

    let functions =
      { peers
      ; start
      ; verified_transitions
      ; root_diff
      ; get_balance
      ; get_nonce
      ; root_length
      ; send_user_command
      ; process_user_command
      ; prove_receipt
      ; new_block
      ; dump_tf
      ; best_path
      ; sync_status
      ; new_user_command
      ; get_all_user_commands }

    let init_worker_state
        { addrs_and_ports
        ; proposer
        ; snark_worker_config
        ; work_selection
        ; conf_dir
        ; trace_dir
        ; program_dir
        ; peers
        ; max_concurrent_connections } =
      let logger =
        Logger.create
          ~metadata:
            [ ( "host"
              , `String (Unix.Inet_addr.to_string addrs_and_ports.external_ip)
              )
            ; ("port", `Int addrs_and_ports.communication_port) ]
          ()
      in
      let%bind () =
        Option.value_map trace_dir
          ~f:(fun d ->
            let%bind () = Async.Unix.mkdir ~p:() d in
            Coda_tracing.start d )
          ~default:Deferred.unit
      in
      let%bind () = File_system.create_dir conf_dir in
      let module Config = struct
        let logger = logger

        let conf_dir = conf_dir

        let lbc_tree_max_depth = `Finite 50

        let propose_keypair =
          Option.map proposer ~f:(fun i ->
              List.nth_exn Genesis_ledger.accounts i
              |> Genesis_ledger.keypair_of_account_record_exn )

        let genesis_proof = Precomputed_values.base_proof

        let transaction_capacity_log_2 = 3

        let work_delay_factor = 2

        let commit_id = None

        let work_selection = work_selection

        let max_concurrent_connections = max_concurrent_connections
      end in
      O1trace.trace_task "worker_main" (fun () ->
          let%bind (module Init) = make_init (module Config) in
          let module Main = Coda_inputs.Make_coda (Init) in
          let module Run = Coda_run.Make (Config) (Main) in
          let%bind receipt_chain_dir_name =
            Unix.mkdtemp @@ conf_dir ^/ "receipt_chain"
          in
          let%bind trust_dir = Unix.mkdtemp (conf_dir ^/ "trust") in
          let%bind transaction_database_dir =
            Unix.mkdtemp @@ conf_dir ^/ "transaction"
          in
          let%bind external_transition_database_dir =
            Unix.mkdtemp @@ conf_dir ^/ "external_transition"
          in
          let trace_database_initialization typ location =
            Logger.trace logger "Creating %s at %s" ~module_:__MODULE__
              ~location typ
          in
          let receipt_chain_database =
            Coda_base.Receipt_chain_database.create
              ~directory:receipt_chain_dir_name
          in
          trace_database_initialization "receipt_chain_database" __LOC__
            receipt_chain_dir_name ;
          let trust_system = Trust_system.create ~db_dir:trust_dir in
          trace_database_initialization "trust_system" __LOC__ trust_dir ;
          let transaction_database =
            Auxiliary_database.Transaction_database.create ~logger
              transaction_database_dir
          in
          trace_database_initialization "transaction_database" __LOC__
            transaction_database_dir ;
          let external_transition_database =
            Auxiliary_database.External_transition_database.create ~logger
              external_transition_database_dir
          in
          trace_database_initialization "external_transition_database" __LOC__
            external_transition_database_dir ;
          let time_controller =
            Block_time.Controller.create Block_time.Controller.basic
          in
          let initial_propose_keypairs =
            Keypair.Set.of_list (Config.propose_keypair |> Option.to_list)
          in
          let initial_propose_keys =
            Public_key.Compressed.Set.of_list
              ( Option.map Config.propose_keypair ~f:(fun keypair ->
                    let open Keypair in
                    Public_key.compress keypair.public_key )
              |> Option.to_list )
          in
          let consensus_local_state =
            Consensus.Data.Local_state.create initial_propose_keys
          in
          let net_config =
            { Main.Inputs.Net.Config.logger
            ; trust_system
            ; time_controller
            ; consensus_local_state
            ; gossip_net_params=
                { Main.Inputs.Net.Gossip_net.Config.timeout= Time.Span.of_sec 3.
                ; target_peer_count= 8
                ; conf_dir
                ; initial_peers= peers
                ; addrs_and_ports
                ; logger
                ; trust_system
                ; max_concurrent_connections } }
          in
          let monitor = Async.Monitor.create ~name:"coda" () in
          let with_monitor f input =
            Async.Scheduler.within' ~monitor (fun () -> f input)
          in
          let%bind coda =
            Main.create
              (Main.Config.make ~logger ~trust_system ~verifier:Init.verifier
                 ~net_config
                 ?snark_worker_key:
                   (Option.map snark_worker_config ~f:(fun c -> c.public_key))
                 ~transaction_pool_disk_location:
                   (conf_dir ^/ "transaction_pool")
                 ~snark_pool_disk_location:(conf_dir ^/ "snark_pool")
                 ~persistent_root_location:(conf_dir ^/ "root")
                 ~persistent_frontier_location:(conf_dir ^/ "frontier")
                 ~wallets_disk_location:(conf_dir ^/ "wallets")
                 ~time_controller ~receipt_chain_database
                 ~snark_work_fee:(Currency.Fee.of_int 0)
                 ~initial_propose_keypairs ~monitor ~consensus_local_state
                 ~transaction_database ~external_transition_database ())
          in
          Run.handle_shutdown ~monitor ~conf_dir coda ;
          let%map () =
            with_monitor
              (fun () ->
                return
                @@ Option.iter snark_worker_config ~f:(fun config ->
                       let run_snark_worker =
                         `With_public_key config.public_key
                       in
                       Run.setup_local_server ~client_port:config.port ~coda () ;
                       Run.run_snark_worker ~client_port:config.port
                         run_snark_worker ) )
              ()
          in
          let coda_peers () = return (Main.peers coda) in
          let coda_start () = return (Main.start coda) in
          let coda_get_balance pk =
            return
              ( Run.Commands.get_balance coda pk
              |> Participating_state.active_exn )
          in
          let coda_get_nonce pk =
            return
              (Run.Commands.get_nonce coda pk |> Participating_state.active_exn)
          in
          let coda_root_length () =
            return (Main.root_length coda |> Participating_state.active_exn)
          in
          let coda_send_payment (sk, pk, amount, fee, memo) =
            let pk_of_sk sk =
              Public_key.of_private_key_exn sk |> Public_key.compress
            in
            let build_txn amount sender_sk receiver_pk fee =
              let nonce =
                Run.Commands.get_nonce coda (pk_of_sk sender_sk)
                |> Participating_state.active_exn
                |> Option.value_exn ?here:None ?message:None ?error:None
              in
              let payload : User_command.Payload.t =
                User_command.Payload.create ~fee ~nonce ~memo
                  ~body:(Payment {receiver= receiver_pk; amount})
              in
              User_command.sign (Keypair.of_private_key_exn sender_sk) payload
            in
            let payment = build_txn amount sk pk fee in
            let%map receipt =
              Run.Commands.send_user_command coda (payment :> User_command.t)
            in
            receipt |> Participating_state.active_exn
          in
          let coda_process_user_command cmd =
            let%map receipt =
              Run.Commands.send_user_command coda (cmd :> User_command.t)
            in
            receipt |> Participating_state.active_exn
          in
          let coda_prove_receipt (proving_receipt, resulting_receipt) =
            match%map
              Run.Commands.prove_receipt coda ~proving_receipt
                ~resulting_receipt
            with
            | Ok proof ->
                Logger.info logger ~module_:__MODULE__ ~location:__LOC__
                  !"Constructed proof for receipt: %{sexp:Receipt.Chain_hash.t}"
                  proving_receipt ;
                proof
            | Error e ->
                failwithf
                  !"Failed to construct payment proof: %{sexp:Error.t}"
                  e ()
          in
          let coda_new_block key =
            Deferred.return @@ Run.Commands.Subscriptions.new_block coda key
          in
          let coda_verified_transitions () =
            let r, w = Linear_pipe.create () in
            don't_wait_for
              (Strict_pipe.Reader.iter (Main.validated_transitions coda)
                 ~f:(fun t ->
                   let open Main.Inputs in
                   let p =
                     External_transition.Validated.protocol_state
                       (With_hash.data t)
                   in
                   let prev_state_hash =
                     Protocol_state.previous_state_hash p
                   in
                   let state_hash = With_hash.hash t in
                   let prev_state_hash = State_hash.to_bits prev_state_hash in
                   let state_hash = State_hash.to_bits state_hash in
                   if Pipe.is_closed w then
                     Logger.error logger ~module_:__MODULE__ ~location:__LOC__
                       "why is this w pipe closed? did someone close the \
                        reader end? dropping this write..." ;
                   Linear_pipe.write_without_pushback_if_open w
                     (prev_state_hash, state_hash) ;
                   Deferred.unit )) ;
            return r.pipe
          in
          let coda_root_diff () =
            let r, w = Linear_pipe.create () in
            don't_wait_for
              (Strict_pipe.Reader.iter (Main.root_diff coda) ~f:(fun diff ->
                   Linear_pipe.write w diff )) ;
            return r.pipe
          in
          let coda_dump_tf () =
            Deferred.return
              ( Main.dump_tf coda |> Or_error.ok
              |> Option.value ~default:"<failed to visualize>" )
          in
          let coda_best_path () =
            let path = Main.best_path coda in
            Deferred.return (Option.value ~default:[] path)
          in
          let parse_sync_status_exn = function
            | `Assoc [("data", `Assoc [("newSyncUpdate", `String status)])] ->
                Sync_status.of_string status |> Or_error.ok_exn
            | unexpected_json ->
                failwithf
                  !"could not parse sync status from json. Got: %s"
                  (Yojson.Basic.to_string unexpected_json)
                  ()
          in
          let coda_sync_status () =
            let schema = Run.Graphql.schema in
            match Graphql_parser.parse "subscription { newSyncUpdate }" with
            | Ok query -> (
                match%map Graphql_async.Schema.execute schema coda query with
                | Ok (`Stream pipe) ->
                    Async.Pipe.map pipe ~f:(function
                      | Ok json ->
                          parse_sync_status_exn json
                      | Error e ->
                          failwith "Receiving sync status error: " )
                | _ ->
                    failwith "Expected to get a stream of sync updates" )
            | Error e ->
                failwithf
                  !"unable to retrieve sync update subscription: %s"
                  e ()
          in
          let coda_new_user_command =
            Fn.compose Deferred.return
            @@ Run.Commands.For_tests.Subscriptions.new_user_commands coda
          in
          let coda_get_all_user_commands =
            Fn.compose Deferred.return
            @@ Run.Commands.For_tests.get_all_user_commands coda
          in
          { coda_peers= with_monitor coda_peers
          ; coda_verified_transitions= with_monitor coda_verified_transitions
          ; coda_root_diff= with_monitor coda_root_diff
          ; coda_get_balance= with_monitor coda_get_balance
          ; coda_get_nonce= with_monitor coda_get_nonce
          ; coda_root_length= with_monitor coda_root_length
          ; coda_send_payment= with_monitor coda_send_payment
          ; coda_process_user_command= with_monitor coda_process_user_command
          ; coda_prove_receipt= with_monitor coda_prove_receipt
          ; coda_new_block= with_monitor coda_new_block
          ; coda_start= with_monitor coda_start
          ; coda_dump_tf= with_monitor coda_dump_tf
          ; coda_best_path= with_monitor coda_best_path
          ; coda_sync_status= with_monitor coda_sync_status
          ; coda_new_user_command= with_monitor coda_new_user_command
          ; coda_get_all_user_commands= with_monitor coda_get_all_user_commands
          } )

    let init_connection_state ~connection:_ ~worker_state:_ = return
  end
end

include Rpc_parallel.Make (T)
