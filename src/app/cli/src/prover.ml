[%%import
"../../../config.mlh"]

open Core
open Async
open Coda_base
open Util
open Blockchain_snark
open Cli_lib

module type S = sig
  type t

  val create : conf_dir:string -> logger:Logger.t -> t Deferred.t

  val extend_blockchain :
       t
    -> Blockchain.t
    -> Consensus.Mechanism.Protocol_state.value
    -> Consensus.Mechanism.Snark_transition.value
    -> Consensus.Mechanism.Prover_state.t
    -> Blockchain.t Deferred.t
end

module Consensus_mechanism = Consensus.Mechanism
module Blockchain = Blockchain

module Worker_state = struct
  module type S = sig
    module Transaction_snark : Transaction_snark.Verification.S

    val extend_blockchain :
         Blockchain.t
      -> Consensus_mechanism.Protocol_state.value
      -> Consensus_mechanism.Snark_transition.value
      -> Consensus_mechanism.Prover_state.t
      -> Blockchain.t

    val verify : Consensus_mechanism.Protocol_state.value -> Proof.t -> bool
  end

  type init_arg = unit [@@deriving bin_io]

  type t = (module S) Deferred.t

  let create () : t Deferred.t =
    Deferred.return
      (let module Keys = Keys_lib.Keys.Make (Consensus_mechanism) in
      let%map (module Keys) = Keys.create () in
      let module Transaction_snark =
      Transaction_snark.Verification.Make (struct
        let keys = Keys.transaction_snark_keys
      end) in
      let module M = struct
        open Snark_params
        open Keys
        module Consensus_mechanism = Keys.Consensus_mechanism
        module Transaction_snark = Transaction_snark
        module Blockchain_state =
          Blockchain_state.Make (Keys.Consensus_mechanism)
        module State = Blockchain_state.Make_update (Transaction_snark)

        let wrap hash proof =
          let module Wrap = Keys.Wrap in
          Tock.prove
            (Tock.Keypair.pk Wrap.keys)
            Wrap.input {Wrap.Prover_state.proof} Wrap.main
            (Wrap_input.of_tick_field hash)

        let extend_blockchain (chain : Blockchain.t)
            (next_state : Keys.Consensus_mechanism.Protocol_state.value)
            (block : Keys.Consensus_mechanism.Snark_transition.value)
            state_for_handler =
          let next_state_top_hash = Keys.Step.instance_hash next_state in
          let prover_state =
            { Keys.Step.Prover_state.prev_proof= chain.proof
            ; wrap_vk= Tock.Keypair.vk Keys.Wrap.keys
            ; prev_state= chain.state
            ; update= block }
          in
          let main x =
            Tick.handle (Keys.Step.main x)
              (Consensus_mechanism.Prover_state.handler state_for_handler)
          in
          let prev_proof =
            Tick.prove
              (Tick.Keypair.pk Keys.Step.keys)
              (Keys.Step.input ()) prover_state main next_state_top_hash
          in
          { Blockchain.state= next_state
          ; proof= wrap next_state_top_hash prev_proof }

        let verify state proof =
          Tock.verify proof
            (Tock.Keypair.vk Wrap.keys)
            Wrap.input
            (Wrap_input.of_tick_field (Keys.Step.instance_hash state))
      end in
      (module M : S))

  let get = Fn.id
end

open Snark_params

module Functions = struct
  type ('i, 'o) t =
    'i Bin_prot.Type_class.t
    * 'o Bin_prot.Type_class.t
    * (Worker_state.t -> 'i -> 'o Deferred.t)

  let create input output f : ('i, 'o) t = (input, output, f)

  [%%if
  with_snark]

  let extend_blockchain =
    create
      [%bin_type_class:
        Blockchain.t
        * Consensus_mechanism.Protocol_state.value
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

  [%%else]

  let extend_blockchain =
    create
      [%bin_type_class:
        Blockchain.t
        * Consensus_mechanism.Protocol_state.value
        * Consensus_mechanism.Snark_transition.value
        * Consensus_mechanism.Prover_state.t] Blockchain.bin_t
      (fun w
      ( {Blockchain.state= prev_state; proof= prev_proof}
      , next_state
      , transition
      , prover_state )
      ->
        let proof = Precomputed_values.base_proof in
        Deferred.return {Blockchain.proof; state= next_state} )

  let verify_blockchain =
    create Blockchain.bin_t bin_bool (fun w {Blockchain.state; proof} ->
        Deferred.return true )

  [%%endif]
end

module Worker = struct
  module T = struct
    module F = Rpc_parallel.Function

    type 'w functions =
      { extend_blockchain:
          ( 'w
          , Blockchain.t
            * Consensus_mechanism.Protocol_state.value
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
        { extend_blockchain= f extend_blockchain
        ; verify_blockchain= f verify_blockchain }

      let init_worker_state () = Worker_state.create ()

      let init_connection_state ~connection:_ ~worker_state:_ = return
    end
  end

  include Rpc_parallel.Make (T)
end

type t = {connection: Worker.Connection.t; logger: Logger.t}

let create ~conf_dir ~logger =
  (* HACK: Need to make connection_timeout long since creating a prover can take a long time*)
  Parallel.run_connection ~logger ~error_message:"Cannot create prover process"
    (Worker.spawn_in_foreground ~connection_timeout:(Time.Span.of_min 1.)
       ~on_failure:Error.raise ~shutdown_on:Disconnect
       ~connection_state_init_arg:() ())
    ~on_success:(fun (connection, process) ->
      File_system.dup_stdout process ;
      File_system.dup_stderr process ;
      {connection; logger} )

let extend_blockchain {connection; logger} chain next_state block prover_state
    =
  Parallel.run_connection ~logger ~error_message:"Cannot connect to prover"
    ~on_success:Fn.id
    (Worker.Connection.run connection ~f:Worker.functions.extend_blockchain
       ~arg:(chain, next_state, block, prover_state))

let verify_blockchain {connection; logger} chain =
  Parallel.run_connection ~logger ~error_message:"Cannot connect to prover"
    ~on_success:Fn.id
    (Worker.Connection.run connection ~f:Worker.functions.verify_blockchain
       ~arg:chain)
