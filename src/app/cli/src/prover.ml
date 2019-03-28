[%%import
"../../../config.mlh"]

open Core
open Async
open Coda_base
open Util
open Blockchain_snark
open Cli_lib

module type S = sig
  module Worker_state : sig
    type t

    val create : unit -> t Deferred.t
  end

  type t

  val create : conf_dir:string -> t Deferred.t

  val initialized : t -> [`Initialized] Deferred.Or_error.t

  val extend_blockchain :
       t
    -> Blockchain.t
    -> Consensus.Protocol_state.Value.t
    -> Consensus.Snark_transition.value
    -> Consensus.Prover_state.t
    -> Blockchain.t Deferred.Or_error.t
end

module Consensus_mechanism = Consensus
module Blockchain = Blockchain

module Worker_state = struct
  module type S = sig
    module Transaction_snark : Transaction_snark.Verification.S

    val extend_blockchain :
         Blockchain.t
      -> Consensus_mechanism.Protocol_state.Value.t
      -> Consensus_mechanism.Snark_transition.value
      -> Consensus_mechanism.Prover_state.t
      -> Blockchain.t

    val verify : Consensus_mechanism.Protocol_state.Value.t -> Proof.t -> bool
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
         match Coda_compile_config.proof_level with
         | "full" ->
             ( module struct
               open Snark_params
               open Keys
               module Consensus_mechanism = Consensus
               module Transaction_snark = Transaction_snark
               module Blockchain_state = Blockchain_state.Make (Consensus)
               module State = Blockchain_state.Make_update (Transaction_snark)

               let wrap hash proof =
                 let module Wrap = Keys.Wrap in
                 Tock.prove
                   (Tock.Keypair.pk Wrap.keys)
                   Wrap.input {Wrap.Prover_state.proof} Wrap.main
                   (Wrap_input.of_tick_field hash)

               let extend_blockchain (chain : Blockchain.t)
                   (next_state : Consensus.Protocol_state.Value.t)
                   (block : Consensus.Snark_transition.value) state_for_handler
                   =
                 let next_state_top_hash =
                   Keys.Step.instance_hash next_state
                 in
                 let prover_state =
                   { Keys.Step.Prover_state.prev_proof= chain.proof
                   ; wrap_vk= Tock.Keypair.vk Keys.Wrap.keys
                   ; prev_state= chain.state
                   ; update= block }
                 in
                 let main x =
                   Tick.handle (Keys.Step.main x)
                     (Consensus_mechanism.Prover_state.handler
                        state_for_handler)
                 in
                 let prev_proof =
                   Tick.Groth16.prove
                     (Tick.Groth16.Keypair.pk Keys.Step.keys)
                     (Keys.Step.input ()) prover_state main next_state_top_hash
                 in
                 { Blockchain.state= next_state
                 ; proof= wrap next_state_top_hash prev_proof }

               let verify state proof =
                 Tock.verify proof
                   (Tock.Keypair.vk Wrap.keys)
                   Wrap.input
                   (Wrap_input.of_tick_field (Keys.Step.instance_hash state))
             end
             : S )
         | "check" ->
             ( module struct
               open Snark_params
               open Keys
               module Consensus_mechanism = Consensus
               module Transaction_snark = Transaction_snark
               module Blockchain_state = Blockchain_state.Make (Consensus)
               module State = Blockchain_state.Make_update (Transaction_snark)

               let extend_blockchain (chain : Blockchain.t)
                   (next_state : Consensus.Protocol_state.Value.t)
                   (block : Consensus.Snark_transition.value) state_for_handler
                   =
                 let next_state_top_hash =
                   Keys.Step.instance_hash next_state
                 in
                 let prover_state =
                   { Keys.Step.Prover_state.prev_proof= chain.proof
                   ; wrap_vk= Tock.Keypair.vk Keys.Wrap.keys
                   ; prev_state= chain.state
                   ; update= block }
                 in
                 let main x =
                   Tick.handle (Keys.Step.main x)
                     (Consensus_mechanism.Prover_state.handler
                        state_for_handler)
                 in
                 match
                   Tick.Groth16.check
                     (main @@ Tick.Field.Var.constant next_state_top_hash)
                     prover_state
                 with
                 | Ok () ->
                     { Blockchain.state= next_state
                     ; proof= Precomputed_values.base_proof }
                 | Error e -> Error.raise e

               let verify state proof = true
             end
             : S )
         | "none" ->
             ( module struct
               module Transaction_snark = Transaction_snark

               let extend_blockchain chain next_state block state_for_handler =
                 { Blockchain.proof= Precomputed_values.base_proof
                 ; state= next_state }

               let verify _ _ = true
             end
             : S )
         | _ -> failwith "unknown proof_level set in compile config"
       in
       m)

  let get = Fn.id
end

open Snark_params

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
    create
      [%bin_type_class:
        Blockchain.t
        * Consensus_mechanism.Protocol_state.Value.Stable.V1.t
        * Consensus_mechanism.Snark_transition.value
        * Consensus_mechanism.Prover_state.t] Blockchain.bin_t
      (fun w
      ( ({Blockchain.state= prev_state; proof= prev_proof} as chain)
      , next_state
      , transition
      , prover_state )
      ->
        let%map (module W) = Worker_state.get w in
        W.extend_blockchain chain next_state transition prover_state )

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
          ( 'w
          , Blockchain.t
            * Consensus_mechanism.Protocol_state.Value.t
            * Consensus_mechanism.Snark_transition.value
            * Consensus_mechanism.Prover_state.t
          , Blockchain.t )
          F.t
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
            ~f:(fun ~worker_state ~conn_state i -> f worker_state i)
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

let create ~conf_dir =
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

let extend_blockchain {connection; _} chain next_state block prover_state =
  Worker.Connection.run connection ~f:Worker.functions.extend_blockchain
    ~arg:(chain, next_state, block, prover_state)

let verify_blockchain {connection; _} chain =
  Worker.Connection.run connection ~f:Worker.functions.verify_blockchain
    ~arg:chain
