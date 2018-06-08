open Core
open Async
open Nanobit_base
open Util
open Blockchain_snark
open Cli_common

module Transition_utils
    (Keys : Keys.S)
    (Transaction_snark : Transaction_snark.S) = struct
  open Snark_params
  open Keys

  let instance_hash =
    let self =
      Step.Verifier.Verification_key.to_bool_list Wrap.verification_key
    in
    fun state ->
      Tick.Pedersen.digest_fold Hash_prefix.transition_system_snark
        (List.fold self +> State_hash.fold (Blockchain_state.hash state))

  let embed (x : Tick.Field.t) : Tock.Field.t =
    let n = Tick.Bigint.of_field x in
    let rec go pt acc i =
      if i = Tick.Field.size_in_bits
      then acc
      else
        go (Tock.Field.add pt pt)
          (if Tick.Bigint.test_bit n i
          then Tock.Field.add pt acc
          else acc)
          (i + 1)
    in
    go Tock.Field.one Tock.Field.zero 0

  let wrap : Tick.Pedersen.Digest.t -> Tick.Proof.t -> Tock.Proof.t =
    fun hash proof ->
      Tock.prove Wrap.proving_key (Wrap.input ())
        { Wrap.Prover_state.proof }
        Wrap.main
        (embed hash)

  module State = Blockchain_state.Make_update(Transaction_snark)

  let update = State.update

  let step ~prev_proof ~prev_state block =
    let open Or_error.Let_syntax in
    let%map next_state = update prev_state block in
    let next_state_top_hash = instance_hash next_state in
    let prev_proof =
      Tick.prove Step.proving_key (Step.input ())
        { Step.Prover_state.prev_proof
        ; wrap_vk = Wrap.verification_key
        ; prev_state
        ; update = block
        }
        Step.main
        next_state_top_hash
    in
    { Blockchain.state = next_state
    ; proof = wrap next_state_top_hash prev_proof
    }

  let verify state proof =
    Tock.verify proof
      (Wrap.verification_key) (Wrap.input ()) (embed (instance_hash state))

  (* TODO: Hard code base_hash, or in any case make it not depend on
  transition *)
  let base_hash =
    lazy begin
      if Insecure.compute_base_hash
      then Tick.Field.zero
      else instance_hash Blockchain.State.zero
    end

  let base_proof =
    if Insecure.compute_base_proof
    then begin
      Tock.Proof.dummy
    end else lazy begin
      let dummy_proof = Lazy.force Tock.Proof.dummy in
      let base_hash = Lazy.force base_hash in
      let tick =
        Tick.prove (Keys.Step.proving_key) (Keys.Step.input ())
          { Keys.Step.Prover_state.prev_proof = dummy_proof
          ; wrap_vk  = Keys.Wrap.verification_key
          ; prev_state = Blockchain.State.negative_one
          ; update = Block.genesis
          }
          Keys.Step.main
          base_hash
      in
      wrap base_hash tick
    end
end

module Worker_state = struct
  module type S = sig
    module Transaction_snark : Transaction_snark.S
    val base_proof : Proof.t Lazy.t

    val step
      : prev_proof:Proof.t
      -> prev_state:Blockchain_state.t
      -> Block.t
      -> Blockchain.t Or_error.t

    val verify : Blockchain_state.t -> Proof.t -> bool

    val update
      : Blockchain_state.t -> Block.t -> Blockchain_state.t Or_error.t
  end

  type init_arg = unit [@@deriving bin_io]
  type t = (module S)

  let create () : t =
    let module M = struct
      open Snark_params

      module Keys = Keys.Make()
      module Transaction_snark = Transaction_snark.Make(struct let keys = Keys.transaction_snark_keys end)
      include Transition_utils(Keys)(Transaction_snark)
    end
    in
    (module M : S)
end

open Snark_params

module Functions = struct
  type ('i, 'o) t =
    'i Bin_prot.Type_class.t
    * 'o Bin_prot.Type_class.t
    * (Worker_state.t -> 'i -> 'o Deferred.t)

  let create input output f : ('i, 'o) t = (input, output, f)

  let initialized =
    create bin_unit [%bin_type_class: [ `Initialized ]] (fun (module W) () ->
      ignore (Lazy.force W.base_proof);
      return `Initialized)

  let genesis_proof =
    create bin_unit Proof.Stable.V1.bin_t (fun (module W) () ->
      return (Lazy.force W.base_proof))

  let extend_blockchain =
    create
      [%bin_type_class: Blockchain.Stable.V1.t * Block.Stable.V1.t]
      Blockchain.Stable.V1.bin_t
      (fun (module W) ({ Blockchain.state=prev_state; proof=prev_proof }, block) ->
         return (
           if Insecure.extend_blockchain
           then
             let proof = Lazy.force W.base_proof in
             { Blockchain.proof; state = Or_error.ok_exn (W.update prev_state block) }
           else Or_error.ok_exn (W.step ~prev_proof ~prev_state block)))

  let verify_blockchain =
    create Blockchain.Stable.V1.bin_t bin_bool
      (fun (module W) ({ Blockchain.state; proof }) ->
        if Insecure.verify_blockchain
        then return true
        else return (W.verify state proof))

  let verify_transaction_snark =
    create Transaction_snark.bin_t bin_bool (fun (module W) proof ->
      return (W.Transaction_snark.verify proof))
end

module Worker = struct
  module T = struct
    module F = Rpc_parallel.Function
    type 'w functions =
      { initialized              : ('w, unit, [`Initialized]) F.t
      ; genesis_proof            : ('w, unit, Proof.t) F.t
      ; extend_blockchain        : ('w, Blockchain.t * Block.t, Blockchain.t) F.t
      ; verify_blockchain        : ('w, Blockchain.t, bool) F.t
      ; verify_transaction_snark : ('w, Transaction_snark.t, bool) F.t
      }

    module Worker_state = Worker_state

    module Connection_state = struct
      type init_arg = unit [@@deriving bin_io]
      type t = unit
    end

    module Functions
        (C : Rpc_parallel.Creator
          with type worker_state := Worker_state.t
          and type connection_state := Connection_state.t) = struct
      let functions =
        let f (i, o, f) =
          C.create_rpc ~f:(fun ~worker_state ~conn_state i -> f worker_state i)
            ~bin_input:i ~bin_output:o ()
        in
        let open Functions in
        { initialized = f initialized
        ; genesis_proof = f genesis_proof
        ; extend_blockchain = f extend_blockchain
        ; verify_blockchain = f verify_blockchain
        ; verify_transaction_snark = f verify_transaction_snark
        }

      let init_worker_state () = return (Worker_state.create ())
      let init_connection_state ~connection:_ ~worker_state:_ = return
    end
  end
  include Rpc_parallel.Make(T)
end

type t = Worker.Connection.t

let create =
  fun ~conf_dir ->
    Parallel.init_master ();
    Worker.spawn_exn ~on_failure:Error.raise
      ~shutdown_on:Disconnect
      ~redirect_stdout:(`File_append (conf_dir ^/ "prover-stdout"))
      ~redirect_stderr:(`File_append (conf_dir ^/ "prover-stderr"))
      ~connection_state_init_arg:()
      ()
;;

let initialized t =
  Worker.Connection.run t ~f:Worker.functions.initialized ~arg:()

let genesis_proof t =
  Worker.Connection.run t ~f:Worker.functions.genesis_proof ~arg:()

let extend_blockchain t chain block =
  Worker.Connection.run t ~f:Worker.functions.extend_blockchain ~arg:(chain, block)

let verify_blockchain t chain =
  Worker.Connection.run t ~f:Worker.functions.verify_blockchain ~arg:chain

let verify_transaction_snark t snark =
  Worker.Connection.run t ~f:Worker.functions.verify_transaction_snark ~arg:snark

