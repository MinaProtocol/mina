open Core
open Async
open Coda_base
open Coda_state
open Coda_transition
open Blockchain_snark

module type S = Intf.S

module Extend_blockchain_input = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { chain: Blockchain.Stable.V1.t
        ; next_state: Protocol_state.Value.Stable.V1.t
        ; block: Snark_transition.Value.Stable.V1.t
        ; prover_state: Consensus.Data.Prover_state.Stable.V1.t
        ; pending_coinbase: Pending_coinbase_witness.Stable.V1.t }

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t =
    { chain: Blockchain.t
    ; next_state: Protocol_state.Value.t
    ; block: Snark_transition.Value.t
    ; prover_state: Consensus.Data.Prover_state.t
    ; pending_coinbase: Pending_coinbase_witness.t }
  [@@deriving sexp]
end

module Consensus_mechanism = Consensus
module Blockchain = Blockchain

module Worker_state = struct
  module type S = sig
    module Transaction_snark : Transaction_snark.Verification.S

    val extend_blockchain :
         Blockchain.t
      -> Protocol_state.Value.t
      -> Snark_transition.value
      -> Consensus.Data.Prover_state.t
      -> Pending_coinbase_witness.t
      -> Blockchain.t Or_error.t

    val verify : Protocol_state.Value.t -> Proof.t -> bool
  end

  (* bin_io required by rpc_parallel *)
  type init_arg =
    { conf_dir: string
    ; logger: Logger.Stable.Latest.t
    ; proof_level: Genesis_constants.Proof_level.Stable.Latest.t
    ; constraint_constants:
        Genesis_constants.Constraint_constants.Stable.Latest.t }
  [@@deriving bin_io_unversioned]

  type t = (module S) Deferred.t

  let create {logger; proof_level; constraint_constants; _} : t Deferred.t =
    Deferred.return
      (let%map (module Keys) = Keys_lib.Keys.create () in
       let module Transaction_snark =
       Transaction_snark.Verification.Make (struct
         let keys = Keys.transaction_snark_keys
       end) in
       let m =
         match proof_level with
         | Genesis_constants.Proof_level.Full ->
             ( module struct
               open Snark_params
               open Keys
               module Transaction_snark = Transaction_snark

               let wrap hash proof =
                 let module Wrap = Keys.Wrap in
                 Tock.prove
                   (Tock.Keypair.pk Wrap.keys)
                   Wrap.input {Wrap.Prover_state.proof} Wrap.main
                   (Wrap_input.of_tick_field hash)

               let extend_blockchain (chain : Blockchain.t)
                   (next_state : Protocol_state.Value.t)
                   (block : Snark_transition.value) state_for_handler
                   pending_coinbase =
                 let next_state_top_hash =
                   Keys.Step.instance_hash next_state
                 in
                 let prover_state =
                   { Keys.Step.Prover_state.prev_proof= chain.proof
                   ; wrap_vk= Tock.Keypair.vk Keys.Wrap.keys
                   ; prev_state= chain.state
                   ; genesis_state_hash=
                       Coda_state.Protocol_state.genesis_state_hash chain.state
                   ; expected_next_state= Some next_state
                   ; update= block }
                 in
                 let main x =
                   Tick.handle
                     (Keys.Step.main ~logger ~proof_level ~constraint_constants
                        x)
                     (Consensus.Data.Prover_state.handler ~constraint_constants
                        state_for_handler ~pending_coinbase)
                 in
                 let res =
                   Or_error.try_with (fun () ->
                       let prev_proof =
                         Tick.prove
                           (Tick.Keypair.pk Keys.Step.keys)
                           (Keys.Step.input ()) prover_state main
                           next_state_top_hash
                       in
                       { Blockchain.state= next_state
                       ; proof= wrap next_state_top_hash prev_proof } )
                 in
                 Or_error.iter_error res ~f:(fun e ->
                     Logger.error logger ~module_:__MODULE__ ~location:__LOC__
                       ~metadata:[("error", `String (Error.to_string_hum e))]
                       "Prover threw an error while extending block: $error" ) ;
                 res

               let verify state proof =
                 Tock.verify proof
                   (Tock.Keypair.vk Wrap.keys)
                   Wrap.input
                   (Wrap_input.of_tick_field (Keys.Step.instance_hash state))
             end
             : S )
         | Check ->
             ( module struct
               open Snark_params
               module Transaction_snark = Transaction_snark

               let extend_blockchain (chain : Blockchain.t)
                   (next_state : Protocol_state.Value.t)
                   (block : Snark_transition.value) state_for_handler
                   pending_coinbase =
                 let next_state_top_hash =
                   Keys.Step.instance_hash next_state
                 in
                 let prover_state =
                   { Keys.Step.Prover_state.prev_proof= chain.proof
                   ; wrap_vk= Tock.Keypair.vk Keys.Wrap.keys
                   ; prev_state= chain.state
                   ; genesis_state_hash=
                       Coda_state.Protocol_state.genesis_state_hash chain.state
                   ; expected_next_state= Some next_state
                   ; update= block }
                 in
                 let main x =
                   Tick.handle
                     (Keys.Step.main ~logger ~proof_level ~constraint_constants
                        x)
                     (Consensus.Data.Prover_state.handler ~constraint_constants
                        state_for_handler ~pending_coinbase)
                 in
                 let res =
                   Or_error.map
                     (Tick.check
                        (main @@ Tick.Field.Var.constant next_state_top_hash)
                        prover_state)
                     ~f:(fun () ->
                       { Blockchain.state= next_state
                       ; proof= Dummy_values.Tock.Bowe_gabizon18.proof } )
                 in
                 Or_error.iter_error res ~f:(fun e ->
                     Logger.error logger ~module_:__MODULE__ ~location:__LOC__
                       ~metadata:[("error", `String (Error.to_string_hum e))]
                       "Prover threw an error while extending block: $error" ) ;
                 res

               let verify _state _proof = true
             end
             : S )
         | None ->
             ( module struct
               module Transaction_snark = Transaction_snark

               let extend_blockchain _chain next_state _block
                   _state_for_handler _pending_coinbase =
                 Ok
                   { Blockchain.proof= Dummy_values.Tock.Bowe_gabizon18.proof
                   ; state= next_state }

               let verify _ _ = true
             end
             : S )
       in
       Memory_stats.log_memory_stats logger ~process:"prover" ;
       m)

  let get = Fn.id
end

module Functions = struct
  type ('i, 'o) t =
    'i Bin_prot.Type_class.t
    * 'o Bin_prot.Type_class.t
    * (Worker_state.t -> 'i -> 'o Deferred.t)

  let create input output f : ('i, 'o) t = (input, output, f)

  let initialized =
    create bin_unit [%bin_type_class: [`Initialized]] (fun w () ->
        let%map (module W) = Worker_state.get w in
        `Initialized )

  let extend_blockchain =
    create Extend_blockchain_input.Stable.Latest.bin_t
      [%bin_type_class: Blockchain.Stable.Latest.t Or_error.t]
      (fun w {chain; next_state; block; prover_state; pending_coinbase} ->
        let%map (module W) = Worker_state.get w in
        W.extend_blockchain chain next_state block prover_state
          pending_coinbase )

  let verify_blockchain =
    create Blockchain.Stable.Latest.bin_t bin_bool
      (fun w {Blockchain.state; proof} ->
        let%map (module W) = Worker_state.get w in
        W.verify state proof )
end

module Worker = struct
  module T = struct
    module F = Rpc_parallel.Function

    type 'w functions =
      { initialized: ('w, unit, [`Initialized]) F.t
      ; extend_blockchain:
          ('w, Extend_blockchain_input.t, Blockchain.t Or_error.t) F.t
      ; verify_blockchain: ('w, Blockchain.t, bool) F.t }

    module Worker_state = Worker_state

    module Connection_state = struct
      (* bin_io required by rpc_parallel *)
      type init_arg = unit [@@deriving bin_io_unversioned]

      type t = unit
    end

    module Functions
        (C : Rpc_parallel.Creator
             with type worker_state := Worker_state.t
              and type connection_state := Connection_state.t) =
    struct
      let functions =
        let f (i, o, f) =
          C.create_rpc
            ~f:(fun ~worker_state ~conn_state:_ i -> f worker_state i)
            ~bin_input:i ~bin_output:o ()
        in
        let open Functions in
        { initialized= f initialized
        ; extend_blockchain= f extend_blockchain
        ; verify_blockchain= f verify_blockchain }

      let init_worker_state
          Worker_state.{conf_dir; logger; proof_level; constraint_constants} =
        let max_size = 256 * 1024 * 512 in
        Logger.Consumer_registry.register ~id:"default"
          ~processor:(Logger.Processor.raw ())
          ~transport:
            (Logger.Transport.File_system.dumb_logrotate ~directory:conf_dir
               ~log_filename:"coda-prover.log" ~max_size) ;
        Logger.info logger ~module_:__MODULE__ ~location:__LOC__
          "Prover started" ;
        Worker_state.create
          {conf_dir; logger; proof_level; constraint_constants}

      let init_connection_state ~connection:_ ~worker_state:_ () =
        Deferred.unit
    end
  end

  include Rpc_parallel.Make (T)
end

type t = {connection: Worker.Connection.t; process: Process.t; logger: Logger.t}

let create ~logger ~pids ~conf_dir ~proof_level ~constraint_constants =
  let on_failure err =
    Logger.error logger ~module_:__MODULE__ ~location:__LOC__
      "Prover process failed with error $err"
      ~metadata:[("err", `String (Error.to_string_hum err))] ;
    Error.raise err
  in
  let%map connection, process =
    (* HACK: Need to make connection_timeout long since creating a prover can take a long time*)
    Worker.spawn_in_foreground_exn ~connection_timeout:(Time.Span.of_min 1.)
      ~on_failure ~shutdown_on:Disconnect ~connection_state_init_arg:()
      {conf_dir; logger; proof_level; constraint_constants}
  in
  Logger.info logger ~module_:__MODULE__ ~location:__LOC__
    "Daemon started process of kind $process_kind with pid $prover_pid"
    ~metadata:
      [ ("prover_pid", `Int (Process.pid process |> Pid.to_int))
      ; ( "process_kind"
        , `String Child_processes.Termination.(show_process_kind Prover) ) ] ;
  Child_processes.Termination.register_process pids process
    Child_processes.Termination.Prover ;
  don't_wait_for
  @@ Pipe.iter
       (Process.stdout process |> Reader.pipe)
       ~f:(fun stdout ->
         return
         @@ Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
              "Prover stdout: $stdout"
              ~metadata:[("stdout", `String stdout)] ) ;
  don't_wait_for
  @@ Pipe.iter
       (Process.stderr process |> Reader.pipe)
       ~f:(fun stderr ->
         return
         @@ Logger.error logger ~module_:__MODULE__ ~location:__LOC__
              "Prover stderr: $stderr"
              ~metadata:[("stderr", `String stderr)] ) ;
  {connection; process; logger}

let initialized {connection; _} =
  Worker.Connection.run connection ~f:Worker.functions.initialized ~arg:()

let prove_from_input_sexp {connection; logger; _} sexp =
  let input = Extend_blockchain_input.t_of_sexp sexp in
  match%map
    Worker.Connection.run connection ~f:Worker.functions.extend_blockchain
      ~arg:input
    >>| Or_error.join
  with
  | Ok _ ->
      Logger.info logger ~module_:__MODULE__ ~location:__LOC__
        "prover succeeded :)" ;
      true
  | Error e ->
      Logger.error logger ~module_:__MODULE__ ~location:__LOC__
        "prover errored :("
        ~metadata:[("error", `String (Error.to_string_hum e))] ;
      false

let extend_blockchain {connection; logger; _} chain next_state block
    prover_state pending_coinbase =
  let input =
    { Extend_blockchain_input.chain
    ; next_state
    ; block
    ; prover_state
    ; pending_coinbase }
  in
  match%map
    Worker.Connection.run connection ~f:Worker.functions.extend_blockchain
      ~arg:input
    >>| Or_error.join
  with
  | Ok x ->
      Ok x
  | Error e ->
      Logger.error logger ~module_:__MODULE__ ~location:__LOC__
        ~metadata:
          [ ( "input-sexp"
            , `String
                (Sexp.to_string (Extend_blockchain_input.sexp_of_t input)) )
          ; ( "input-bin-io"
            , `String
                (Binable.to_string
                   (module Extend_blockchain_input.Stable.Latest)
                   input) )
          ; ("error", `String (Error.to_string_hum e)) ]
        "Prover failed: $error" ;
      Error e

let prove t ~prev_state ~prev_state_proof ~next_state
    (transition : Internal_transition.t) pending_coinbase =
  let open Deferred.Or_error.Let_syntax in
  let start_time = Core.Time.now () in
  let%map {Blockchain.proof; _} =
    extend_blockchain t
      (Blockchain.create ~proof:prev_state_proof ~state:prev_state)
      next_state
      (Internal_transition.snark_transition transition)
      (Internal_transition.prover_state transition)
      pending_coinbase
  in
  Coda_metrics.(
    Gauge.set Cryptography.blockchain_proving_time_ms
      (Core.Time.Span.to_ms @@ Core.Time.diff (Core.Time.now ()) start_time)) ;
  proof
