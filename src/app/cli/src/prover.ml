[%%import
"../../../config.mlh"]

open Core
open Async
open Coda_base
open Util
open Blockchain_snark
open Cli_lib

module type S = sig
  module Consensus_mechanism : Consensus.Mechanism.S

  module Blockchain :
    Blockchain.S with module Consensus_mechanism = Consensus_mechanism

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
    -> Consensus_mechanism.Protocol_state.value
    -> Consensus_mechanism.Snark_transition.value
    -> Blockchain.t Deferred.Or_error.t
end

module Make
    (Consensus_mechanism : Consensus.Mechanism.S)
    (Blockchain : Blockchain.S
                  with module Consensus_mechanism = Consensus_mechanism) =
struct
  module Consensus_mechanism = Consensus_mechanism
  module Blockchain = Blockchain

  module Worker_state = struct
    module type S = sig
      module Transaction_snark : Transaction_snark.Verification.S

      val extend_blockchain :
           Blockchain.t
        -> Consensus_mechanism.Protocol_state.value
        -> Consensus_mechanism.Snark_transition.value
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
              (block : Keys.Consensus_mechanism.Snark_transition.value) =
            let next_state_top_hash = Keys.Step.instance_hash next_state in
            let prover_state =
              { Keys.Step.Prover_state.prev_proof= chain.proof
              ; wrap_vk= Tock.Keypair.vk Keys.Wrap.keys
              ; prev_state= chain.state
              ; update= block }
            in
            let prev_proof =
              Tick.prove
                (Tick.Keypair.pk Keys.Step.keys)
                (Keys.Step.input ()) prover_state Keys.Step.main
                next_state_top_hash
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

    let initialized =
      create bin_unit [%bin_type_class: [`Initialized]] (fun w () ->
          let%map (module W) = Worker_state.get w in
          `Initialized )

    [%%if
    with_snark]

    let extend_blockchain =
      create
        [%bin_type_class:
          Blockchain.t
          * Consensus_mechanism.Protocol_state.value
          * Consensus_mechanism.Snark_transition.value] Blockchain.bin_t
        (fun w
        ( ({Blockchain.state= prev_state; proof= prev_proof} as chain)
        , next_state
        , transition )
        ->
          let%map (module W) = Worker_state.get w in
          W.extend_blockchain chain next_state transition )

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
          * Consensus_mechanism.Snark_transition.value] Blockchain.bin_t
        (fun w
        ( {Blockchain.state= prev_state; proof= prev_proof}
        , next_state
        , transition )
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
        { initialized: ('w, unit, [`Initialized]) F.t
        ; extend_blockchain:
            ( 'w
            , Blockchain.t
              * Consensus_mechanism.Protocol_state.value
              * Consensus_mechanism.Snark_transition.value
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

  let extend_blockchain {connection; _} chain next_state block =
    Worker.Connection.run connection ~f:Worker.functions.extend_blockchain
      ~arg:(chain, next_state, block)

  let verify_blockchain {connection; _} chain =
    Worker.Connection.run connection ~f:Worker.functions.verify_blockchain
      ~arg:chain
end
