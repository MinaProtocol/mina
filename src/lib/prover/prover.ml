open Core
open Async
open Coda_base
open Coda_state
open Coda_transition
open Blockchain_snark

module type S = Intf.S

module Extend_blockchain_input = struct
  type t =
    { chain: Blockchain.t
    ; next_state: Protocol_state.Value.Stable.Latest.t
    ; block: Snark_transition.Value.Stable.Latest.t
    ; prover_state: Consensus.Data.Prover_state.Stable.Latest.t
    ; pending_coinbase: Pending_coinbase_witness.Stable.Latest.t }
  [@@deriving bin_io, sexp]
end

module Blockchain = Blockchain

module Worker_state = struct
  module type S = sig
    val extend_blockchain :
         Blockchain.t
      -> Protocol_state.Value.t
      -> Snark_transition.value
      -> Consensus.Data.Prover_state.t
      -> Pending_coinbase_witness.t
      -> Blockchain.t Or_error.t

    val verify : Protocol_state.Value.t -> Proof.t -> bool
  end

  type init_arg = unit [@@deriving bin_io]

  type t = (module S) Deferred.t

  let create () : t Deferred.t =
    Deferred.return
      (let%map (module Keys) = Keys_lib.Keys.create () in
       let module Transaction_snark =
       Transaction_snark.Verification.Make (struct
         let keys = Keys.transaction_snark_keys
       end) in
       let m =
         let run k make_proof chain next_state block state_for_handler
             pending_coinbase =
           let open Or_error in
           k
             (Consensus.Data.Prover_state.handler state_for_handler
                ~pending_coinbase)
             next_state
             { Transition_system.Step.Witness.proof= chain.Blockchain.proof
             ; previous_state= chain.state
             ; update= block }
           >>| fun res -> {Blockchain.state= next_state; proof= make_proof res}
         in
         match Coda_compile_config.proof_level with
         | "full" ->
             ( module struct
               open Keys

               let extend_blockchain = run create_state_proof Fn.id

               let verify = Keys.verify_state_proof
             end
             : S )
         | "check" ->
             ( module struct
               let extend_blockchain =
                 run Keys.check_constraints (fun _ ->
                     Precomputed_values.base_proof )

               let verify _state _proof = true
             end
             : S )
         | "none" ->
             ( module struct
               let extend_blockchain _chain next_state _block
                   _state_for_handler _pending_coinbase =
                 Ok
                   { Blockchain.proof= Precomputed_values.base_proof
                   ; state= next_state }

               let verify _ _ = true
             end
             : S )
         | _ ->
             failwith "unknown proof_level set in compile config"
       in
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
    create Extend_blockchain_input.bin_t
      [%bin_type_class: Blockchain.t Or_error.t]
      (fun w {chain; next_state; block; prover_state; pending_coinbase} ->
        let%map (module W) = Worker_state.get w in
        W.extend_blockchain chain next_state block prover_state
          pending_coinbase )

  let verify_blockchain =
    create Blockchain.bin_t bin_bool (fun w {Blockchain.state; proof} ->
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
      type init_arg = unit [@@deriving bin_io]

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

      let init_worker_state () = Worker_state.create ()

      let init_connection_state ~connection:_ ~worker_state:_ = return
    end
  end

  include Rpc_parallel.Make (T)
end

type t = {connection: Worker.Connection.t; process: Process.t}

let create () =
  let%map connection, process =
    (* HACK: Need to make connection_timeout long since creating a prover can take a long time*)
    Worker.spawn_in_foreground_exn ~connection_timeout:(Time.Span.of_min 1.)
      ~on_failure:Error.raise ~shutdown_on:Disconnect
      ~connection_state_init_arg:() ()
  in
  File_system.dup_stdout process ;
  File_system.dup_stderr process ;
  {connection; process}

let initialized {connection; _} =
  Worker.Connection.run connection ~f:Worker.functions.initialized ~arg:()

let extend_blockchain {connection; _} chain next_state block prover_state
    pending_coinbase =
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
      Logger.error (Logger.create ()) ~module_:__MODULE__ ~location:__LOC__
        ~metadata:
          [ ( "input-sexp"
            , `String
                (Sexp.to_string (Extend_blockchain_input.sexp_of_t input)) )
          ; ( "input-bin-io"
            , `String
                (Binable.to_string (module Extend_blockchain_input) input) )
          ; ("error", `String (Error.to_string_hum e)) ]
        "Prover failed: $error" ;
      Error.raise e

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
    Gauge.set Proving_time.blockchain_proving_time_ms
      (Core.Time.Span.to_ms @@ Core.Time.diff (Core.Time.now ()) start_time)) ;
  proof
