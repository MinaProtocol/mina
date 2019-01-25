[%%import
"../../../config.mlh"]

open Core
open Async
open Coda_base
open Signature_lib
open Coda_main
open Signature_lib
open Pipe_lib

[%%if
tracing]

let start_tracing () =
  Writer.open_file
    (sprintf "/tmp/coda-profile-%d" (Unix.getpid () |> Pid.to_int))
  >>| O1trace.start_tracing

[%%else]

let start_tracing () = Deferred.unit

[%%endif]

module Snark_worker_config = struct
  type t = {port: int; public_key: Public_key.Compressed.t} [@@deriving bin_io]
end

module Input = struct
  type t =
    { host: string
    ; env: (string * string) list
    ; should_propose: bool
    ; snark_worker_config: Snark_worker_config.t option
    ; work_selection: Protocols.Coda_pow.Work_selection.t
    ; conf_dir: string
    ; program_dir: string
    ; external_port: int
    ; discovery_port: int
    ; peers: Host_and_port.t list }
  [@@deriving bin_io]
end

open Input

module Send_payment_input = struct
  type t =
    Private_key.t
    * Public_key.Compressed.t
    * Currency.Amount.t
    * Currency.Fee.t
    * User_command_memo.t
  [@@deriving bin_io]
end

module T = struct
  module Peers = struct
    type t = Kademlia.Peer.t List.t [@@deriving bin_io]
  end

  module State_hashes = struct
    type t = bool list * bool list [@@deriving bin_io]
  end

  module Maybe_currency = struct
    type t = Currency.Balance.t option [@@deriving bin_io]
  end

  module Prove_receipt = struct
    module Input = struct
      type t = Receipt.Chain_hash.t * Receipt.Chain_hash.t [@@deriving bin_io]
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
    ; send_payment:
        ( 'worker
        , Send_payment_input.t
        , Receipt.Chain_hash.t Or_error.t )
        Rpc_parallel.Function.t
    ; strongest_ledgers:
        ('worker, unit, State_hashes.t Pipe.Reader.t) Rpc_parallel.Function.t
    ; prove_receipt:
        ( 'worker
        , Prove_receipt.Input.t
        , Prove_receipt.Output.t )
        Rpc_parallel.Function.t }

  type coda_functions =
    { coda_peers: unit -> Peers.t Deferred.t
    ; coda_start: unit -> unit Deferred.t
    ; coda_get_balance: Public_key.Compressed.t -> Maybe_currency.t Deferred.t
    ; coda_send_payment:
        Send_payment_input.t -> Receipt.Chain_hash.t Or_error.t Deferred.t
    ; coda_strongest_ledgers: unit -> State_hashes.t Pipe.Reader.t Deferred.t
    ; coda_prove_receipt:
        Prove_receipt.Input.t -> Prove_receipt.Output.t Deferred.t }

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

    let strongest_ledgers_impl ~worker_state ~conn_state:() () =
      worker_state.coda_strongest_ledgers ()

    let get_balance_impl ~worker_state ~conn_state:() pk =
      worker_state.coda_get_balance pk

    let send_payment_impl ~worker_state ~conn_state:() input =
      worker_state.coda_send_payment input

    let prove_receipt_impl ~worker_state ~conn_state:() input =
      worker_state.coda_prove_receipt input

    let start_impl ~worker_state ~conn_state:() () = worker_state.coda_start ()

    let peers =
      C.create_rpc ~f:peers_impl ~bin_input:Unit.bin_t ~bin_output:Peers.bin_t
        ()

    let start =
      C.create_rpc ~f:start_impl ~bin_input:Unit.bin_t ~bin_output:Unit.bin_t
        ()

    let get_balance =
      C.create_rpc ~f:get_balance_impl ~bin_input:Public_key.Compressed.bin_t
        ~bin_output:Maybe_currency.bin_t ()

    let prove_receipt =
      C.create_rpc ~f:prove_receipt_impl ~bin_input:Prove_receipt.Input.bin_t
        ~bin_output:Prove_receipt.Output.bin_t ()

    let send_payment =
      C.create_rpc ~f:send_payment_impl ~bin_input:Send_payment_input.bin_t
        ~bin_output:[%bin_type_class: Receipt.Chain_hash.t Or_error.t] ()

    let strongest_ledgers =
      C.create_pipe ~f:strongest_ledgers_impl ~bin_input:Unit.bin_t
        ~bin_output:State_hashes.bin_t ()

    let functions =
      { peers
      ; start
      ; strongest_ledgers
      ; get_balance
      ; send_payment
      ; prove_receipt }

    let init_worker_state
        { host
        ; should_propose
        ; snark_worker_config
        ; work_selection
        ; conf_dir
        ; program_dir
        ; external_port
        ; peers
        ; discovery_port } =
      let log = Logger.create () in
      let log =
        Logger.child log ("host: " ^ host ^ ":" ^ Int.to_string external_port)
      in
      let%bind () = File_system.create_dir conf_dir in
      let module Config = struct
        let logger = log

        let conf_dir = conf_dir

        let lbc_tree_max_depth = `Finite 50

        let propose_keypair =
          if should_propose then
            Some (Genesis_ledger.largest_account_keypair_exn ())
          else None

        let genesis_proof = Precomputed_values.base_proof

        let transaction_capacity_log_2 = 3

        let work_delay_factor = 1

        let commit_id = None

        let work_selection = work_selection
      end in
      let%bind (module Init) = make_init ~should_propose (module Config) in
      let module Main = Coda_main.Make_coda (Init) in
      let module Run = Run (Config) (Main) in
      let banlist_dir_name = conf_dir ^/ "banlist" in
      let%bind () = File_system.create_dir banlist_dir_name in
      let%bind suspicious_dir =
        Unix.mkdtemp (banlist_dir_name ^/ "suspicious")
      in
      let%bind punished_dir = Unix.mkdtemp (banlist_dir_name ^/ "banned") in
      let receipt_chain_dir_name = conf_dir ^/ "receipt_chain" in
      let%bind () = File_system.create_dir receipt_chain_dir_name in
      let receipt_chain_database =
        Coda_base.Receipt_chain_database.create
          ~directory:receipt_chain_dir_name
      in
      let banlist = Coda_base.Banlist.create ~suspicious_dir ~punished_dir in
      let time_controller = Main.Inputs.Time.Controller.create () in
      let net_config =
        { Main.Inputs.Net.Config.parent_log= log
        ; time_controller
        ; gossip_net_params=
            { Main.Inputs.Net.Gossip_net.Config.timeout= Time.Span.of_sec 1.
            ; target_peer_count= 8
            ; conf_dir
            ; initial_peers= peers
            ; me=
                Kademlia.Peer.create
                  (Unix.Inet_addr.of_string host)
                  ~discovery_port ~communication_port:external_port
            ; parent_log= log
            ; banlist } }
      in
      let%bind () = start_tracing () in
      let%bind coda =
        Main.create
          (Main.Config.make ~log ~net_config
             ~run_snark_worker:(Option.is_some snark_worker_config)
             ~staged_ledger_persistant_location:(conf_dir ^/ "staged_ledger")
             ~transaction_pool_disk_location:(conf_dir ^/ "transaction_pool")
             ~snark_pool_disk_location:(conf_dir ^/ "snark_pool")
             ~time_controller ~receipt_chain_database
             ~snark_work_fee:(Currency.Fee.of_int 0)
             ?propose_keypair:Config.propose_keypair () ~banlist)
      in
      Option.iter snark_worker_config ~f:(fun config ->
          let run_snark_worker = `With_public_key config.public_key in
          Run.setup_local_server ~client_port:config.port ~coda ~log () ;
          Run.run_snark_worker ~log ~client_port:config.port run_snark_worker
      ) ;
      let coda_peers () = return (Main.peers coda) in
      let coda_start () = return (Main.start coda) in
      let coda_get_balance pk =
        return (Run.get_balance coda pk |> Participating_state.active_exn)
      in
      let coda_send_payment (sk, pk, amount, fee, memo) =
        let pk_of_sk sk =
          Public_key.of_private_key_exn sk |> Public_key.compress
        in
        let build_txn amount sender_sk receiver_pk fee =
          let nonce =
            Run.get_nonce coda (pk_of_sk sender_sk)
            |> Participating_state.active_exn |> Option.value_exn
          in
          let payload : User_command.Payload.t =
            User_command.Payload.create ~fee ~nonce ~memo
              ~body:(Payment {receiver= receiver_pk; amount})
          in
          User_command.sign (Keypair.of_private_key_exn sender_sk) payload
        in
        let payment = build_txn amount sk pk fee in
        let%map receipt =
          Run.send_payment log coda (payment :> User_command.t)
        in
        receipt |> Participating_state.active_exn
      in
      let coda_prove_receipt (proving_receipt, resulting_receipt) =
        match%map
          Run.prove_receipt coda ~proving_receipt ~resulting_receipt
        with
        | Ok proof ->
            Logger.info log
              !"Constructed proof for receipt: %{sexp:Receipt.Chain_hash.t}"
              proving_receipt ;
            proof
        | Error e ->
            failwithf
              !"Failed to construct payment proof: %{sexp:Error.t}"
              e ()
      in
      let coda_strongest_ledgers () =
        let r, w = Linear_pipe.create () in
        don't_wait_for
          (Strict_pipe.Reader.iter (Main.strongest_ledgers coda) ~f:(fun t ->
               let open Main.Inputs in
               let p =
                 External_transition.Verified.protocol_state (With_hash.data t)
               in
               let prev_state_hash =
                 Main.Inputs.Consensus_mechanism.Protocol_state
                 .previous_state_hash p
               in
               let state_hash = With_hash.hash t in
               let prev_state_hash = State_hash.to_bits prev_state_hash in
               let state_hash = State_hash.to_bits state_hash in
               Linear_pipe.write w (prev_state_hash, state_hash) )) ;
        return r.pipe
      in
      return
        { coda_peers
        ; coda_strongest_ledgers
        ; coda_get_balance
        ; coda_send_payment
        ; coda_prove_receipt
        ; coda_start }

    let init_connection_state ~connection:_ ~worker_state:_ = return
  end
end

include Rpc_parallel.Make (T)
