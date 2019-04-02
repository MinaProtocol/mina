[%%import
"../../../config.mlh"]

open Core
open Async
open Coda_base
open Signature_lib
open Coda_main
open Signature_lib
open Pipe_lib

module Snark_worker_config = struct
  (* TODO : version *)
  type t = {port: int; public_key: Public_key.Compressed.Stable.V1.t}
  [@@deriving bin_io]
end

module Input = struct
  type t =
    { host: string
    ; env: (string * string) list
    ; proposer: int option
    ; snark_worker_config: Snark_worker_config.t option
    ; work_selection: Protocols.Coda_pow.Work_selection.t
    ; conf_dir: string
    ; trace_dir: string option
    ; program_dir: string
    ; external_port: int
    ; discovery_port: int
    ; acceptable_delay: Time.Span.t
    ; peers: Host_and_port.t list }
  [@@deriving bin_io]
end

open Input

module Send_payment_input = struct
  (* TODO : version *)
  type t =
    Private_key.t
    * Public_key.Compressed.Stable.V1.t
    * Currency.Amount.Stable.V1.t
    * Currency.Fee.Stable.V1.t
    * User_command_memo.Stable.V1.t
  [@@deriving bin_io]
end

module T = struct
  module Peers = struct
    (* TODO: version *)
    type t = Network_peer.Peer.Stable.V1.t List.t [@@deriving bin_io]
  end

  module State_hashes = struct
    type t = bool list * bool list [@@deriving bin_io]
  end

  module Maybe_currency = struct
    (* TODO: version *)
    type t = Currency.Balance.Stable.V1.t option [@@deriving bin_io]
  end

  module Prove_receipt = struct
    (* TODO : version *)
    module Input = struct
      type t = Receipt.Chain_hash.Stable.V1.t * Receipt.Chain_hash.Stable.V1.t
      [@@deriving bin_io]
    end

    module Output = struct
      type t = Payment_proof.t [@@deriving bin_io]
    end
  end

  type 'worker functions =
    { peers: ('worker, unit, Peers.t) Rpc_parallel.Function.t
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
    ; send_payment:
        ( 'worker
        , Send_payment_input.t
        , Receipt.Chain_hash.t Or_error.t )
        Rpc_parallel.Function.t
    ; process_payment:
        ( 'worker
        , User_command.t
        , Receipt.Chain_hash.t Or_error.t )
        Rpc_parallel.Function.t
    ; verified_transitions:
        ('worker, unit, State_hashes.t Pipe.Reader.t) Rpc_parallel.Function.t
    ; root_diff:
        ( 'worker
        , unit
        , User_command.t Protocols.Coda_transition_frontier.Root_diff_view.t
          Pipe.Reader.t )
        Rpc_parallel.Function.t
    ; prove_receipt:
        ( 'worker
        , Prove_receipt.Input.t
        , Prove_receipt.Output.t )
        Rpc_parallel.Function.t
    ; dump_tf: ('worker, unit, string) Rpc_parallel.Function.t
    ; best_path:
        ( 'worker
        , unit
        , State_hash.Stable.Latest.t list )
        Rpc_parallel.Function.t }

  type coda_functions =
    { coda_peers: unit -> Peers.t Deferred.t
    ; coda_start: unit -> unit Deferred.t
    ; coda_get_balance: Public_key.Compressed.t -> Maybe_currency.t Deferred.t
    ; coda_get_nonce:
           Public_key.Compressed.t
        -> Coda_numbers.Account_nonce.t option Deferred.t
    ; coda_root_length: unit -> int Deferred.t
    ; coda_send_payment:
        Send_payment_input.t -> Receipt.Chain_hash.t Or_error.t Deferred.t
    ; coda_process_payment:
        User_command.t -> Receipt.Chain_hash.t Or_error.t Deferred.t
    ; coda_verified_transitions:
        unit -> State_hashes.t Pipe.Reader.t Deferred.t
    ; coda_root_diff:
           unit
        -> User_command.t Protocols.Coda_transition_frontier.Root_diff_view.t
           Pipe.Reader.t
           Deferred.t
    ; coda_prove_receipt:
        Prove_receipt.Input.t -> Prove_receipt.Output.t Deferred.t
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

    let process_payment_impl ~worker_state ~conn_state:() cmd =
      worker_state.coda_process_payment cmd

    let prove_receipt_impl ~worker_state ~conn_state:() input =
      worker_state.coda_prove_receipt input

    let start_impl ~worker_state ~conn_state:() () = worker_state.coda_start ()

    let dump_tf_impl ~worker_state ~conn_state:() () =
      worker_state.coda_dump_tf ()

    let best_path_impl ~worker_state ~conn_state:() () =
      worker_state.coda_best_path ()

    let peers =
      C.create_rpc ~f:peers_impl ~bin_input:Unit.bin_t ~bin_output:Peers.bin_t
        ()

    let start =
      C.create_rpc ~f:start_impl ~bin_input:Unit.bin_t ~bin_output:Unit.bin_t
        ()

    let get_balance =
      C.create_rpc ~f:get_balance_impl
        ~bin_input:Public_key.Compressed.Stable.V1.bin_t
        ~bin_output:Maybe_currency.bin_t ()

    let get_nonce =
      C.create_rpc ~f:get_nonce_impl
        ~bin_input:Public_key.Compressed.Stable.V1.bin_t
        ~bin_output:
          [%bin_type_class: Coda_numbers.Account_nonce.Stable.V1.t option] ()

    let root_length =
      C.create_rpc ~f:root_length_impl ~bin_input:Unit.bin_t
        ~bin_output:Int.bin_t ()

    let prove_receipt =
      C.create_rpc ~f:prove_receipt_impl ~bin_input:Prove_receipt.Input.bin_t
        ~bin_output:Prove_receipt.Output.bin_t ()

    let send_payment =
      C.create_rpc ~f:send_payment_impl ~bin_input:Send_payment_input.bin_t
        ~bin_output:
          [%bin_type_class: Receipt.Chain_hash.Stable.V1.t Or_error.t] ()

    let process_payment =
      C.create_rpc ~f:process_payment_impl ~bin_input:User_command.bin_t
        ~bin_output:
          [%bin_type_class: Receipt.Chain_hash.Stable.V1.t Or_error.t] ()

    let verified_transitions =
      C.create_pipe ~f:verified_transitions_impl ~bin_input:Unit.bin_t
        ~bin_output:State_hashes.bin_t ()

    let root_diff =
      C.create_pipe ~f:root_diff_impl ~bin_input:Unit.bin_t
        ~bin_output:
          [%bin_type_class:
            User_command.t Protocols.Coda_transition_frontier.Root_diff_view.t]
        ()

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
      ; send_payment
      ; process_payment
      ; prove_receipt
      ; dump_tf
      ; best_path }

    let init_worker_state
        { host
        ; proposer
        ; snark_worker_config
        ; work_selection
        ; conf_dir
        ; trace_dir
        ; program_dir
        ; external_port
        ; peers
        ; discovery_port } =
      let logger =
        Logger.create
          ~metadata:[("host", `String host); ("port", `Int external_port)]
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
      end in
      O1trace.trace_task "worker_main" (fun () ->
          let%bind (module Init) =
            make_init ~should_propose:(Option.is_some proposer) (module Config)
          in
          let module Main = Coda_main.Make_coda (Init) in
          let module Run = Run (Config) (Main) in
          let%bind trust_dir = Unix.mkdtemp (conf_dir ^/ "trust") in
          let receipt_chain_dir_name = conf_dir ^/ "receipt_chain" in
          let%bind () = File_system.create_dir receipt_chain_dir_name in
          let receipt_chain_database =
            Coda_base.Receipt_chain_database.create
              ~directory:receipt_chain_dir_name
          in
          let trust_system = Coda_base.Trust_system.create ~db_dir:trust_dir in
          let time_controller =
            Run.Inputs.Time.Controller.create Run.Inputs.Time.Controller.basic
          in
          let net_config =
            { Main.Inputs.Net.Config.logger
            ; time_controller
            ; gossip_net_params=
                { Main.Inputs.Net.Gossip_net.Config.timeout= Time.Span.of_sec 3.
                ; target_peer_count= 8
                ; conf_dir
                ; initial_peers= peers
                ; me=
                    Network_peer.Peer.create
                      (Unix.Inet_addr.of_string host)
                      ~discovery_port ~communication_port:external_port
                ; logger
                ; trust_system } }
          in
          let monitor = Async.Monitor.create ~name:"coda" () in
          let with_monitor f input =
            Async.Scheduler.within' ~monitor (fun () -> f input)
          in
          let%bind coda =
            Main.create
              (Main.Config.make ~logger ~net_config
                 ~run_snark_worker:(Option.is_some snark_worker_config)
                 ~staged_ledger_persistant_location:
                   (conf_dir ^/ "staged_ledger")
                 ~transaction_pool_disk_location:
                   (conf_dir ^/ "transaction_pool")
                 ~snark_pool_disk_location:(conf_dir ^/ "snark_pool")
                 ~time_controller ~receipt_chain_database
                 ~snark_work_fee:(Currency.Fee.of_int 0)
                 ?propose_keypair:Config.propose_keypair () ~monitor)
          in
          Run.handle_shutdown ~monitor ~conf_dir ~logger coda ;
          let%map () =
            with_monitor
              (fun () ->
                return
                @@ Option.iter snark_worker_config ~f:(fun config ->
                       let run_snark_worker =
                         `With_public_key config.public_key
                       in
                       Run.setup_local_server ~client_port:config.port ~coda
                         ~logger () ;
                       Run.run_snark_worker ~logger ~client_port:config.port
                         run_snark_worker ) )
              ()
          in
          let coda_peers () = return (Main.peers coda) in
          let coda_start () = return (Main.start coda) in
          let coda_get_balance pk =
            return (Run.get_balance coda pk |> Participating_state.active_exn)
          in
          let coda_get_nonce pk =
            return (Run.get_nonce coda pk |> Participating_state.active_exn)
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
                Run.get_nonce coda (pk_of_sk sender_sk)
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
              Run.send_payment logger coda (payment :> User_command.t)
            in
            receipt |> Participating_state.active_exn
          in
          let coda_process_payment cmd =
            let%map receipt =
              Run.send_payment logger coda (cmd :> User_command.t)
            in
            receipt |> Participating_state.active_exn
          in
          let coda_prove_receipt (proving_receipt, resulting_receipt) =
            match%map
              Run.prove_receipt coda ~proving_receipt ~resulting_receipt
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
          let coda_verified_transitions () =
            let r, w = Linear_pipe.create () in
            don't_wait_for
              (Strict_pipe.Reader.iter (Main.verified_transitions coda)
                 ~f:(fun t ->
                   let open Main.Inputs in
                   let p =
                     External_transition.Verified.protocol_state
                       (With_hash.data t)
                   in
                   let prev_state_hash =
                     Main.Inputs.Consensus_mechanism.Protocol_state
                     .previous_state_hash p
                   in
                   let state_hash = With_hash.hash t in
                   let prev_state_hash = State_hash.to_bits prev_state_hash in
                   let state_hash = State_hash.to_bits state_hash in
                   if Pipe.is_closed w then
                     Logger.error logger ~module_:__MODULE__ ~location:__LOC__
                       "why is this w pipe closed? did someone close the \
                        reader end? dropping this write..." ;
                   Linear_pipe.write_if_open w (prev_state_hash, state_hash) )) ;
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
          { coda_peers= with_monitor coda_peers
          ; coda_verified_transitions= with_monitor coda_verified_transitions
          ; coda_root_diff= with_monitor coda_root_diff
          ; coda_get_balance= with_monitor coda_get_balance
          ; coda_get_nonce= with_monitor coda_get_nonce
          ; coda_root_length= with_monitor coda_root_length
          ; coda_send_payment= with_monitor coda_send_payment
          ; coda_process_payment= with_monitor coda_process_payment
          ; coda_prove_receipt= with_monitor coda_prove_receipt
          ; coda_start= with_monitor coda_start
          ; coda_dump_tf= with_monitor coda_dump_tf
          ; coda_best_path= with_monitor coda_best_path } )

    let init_connection_state ~connection:_ ~worker_state:_ = return
  end
end

include Rpc_parallel.Make (T)
