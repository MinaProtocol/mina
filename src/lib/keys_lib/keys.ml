open Core
open Snark_params
open Coda_state

module Step_prover_state = struct
  type t =
    { wrap_vk: Tock.Verification_key.t
    ; prev_proof: Tock.Proof.t
    ; prev_state: Protocol_state.value
    ; genesis_state_hash: Coda_base.State_hash.t
    ; expected_next_state: Protocol_state.value option
    ; update: Snark_transition.value }
end

module Wrap_prover_state = struct
  type t = {proof: Tick.Proof.t}
end

module type S = sig
  val transaction_snark_keys : Transaction_snark.Keys.Verification.t

  module Step : sig
    val keys : Tick.Keypair.t

    val input :
         unit
      -> ('a, 'b, Tick.Field.Var.t -> 'a, Tick.Field.t -> 'b) Tick.Data_spec.t

    module Verification_key : sig
      val to_bool_list : Tock.Verification_key.t -> bool list
    end

    module Prover_state : module type of Step_prover_state

    val instance_hash : Protocol_state.value -> Tick.Field.t

    val main :
         logger:Logger.t
      -> proof_level:Genesis_constants.Proof_level.t
      -> constraint_constants:Genesis_constants.Constraint_constants.t
      -> Tick.Field.Var.t
      -> (unit, Prover_state.t) Tick.Checked.t
  end

  module Wrap : sig
    val keys : Tock.Keypair.t

    val input :
      ('a, 'b, Wrap_input.var -> 'a, Wrap_input.t -> 'b) Tock.Data_spec.t

    module Prover_state : module type of Wrap_prover_state

    val main : Wrap_input.var -> (unit, Prover_state.t) Tock.Checked.t
  end
end

let tx_vk = lazy (Snark_keys.transaction_verification ())

let bc_pk = lazy (Snark_keys.blockchain_proving ())

let bc_vk = lazy (Snark_keys.blockchain_verification ())

let step_instance_hash protocol_state =
  let open Async in
  let%map bc_vk = Lazy.force bc_vk in
  unstage
    (Blockchain_snark.Blockchain_transition.instance_hash bc_vk.wrap)
    protocol_state

let keys = Set_once.create ()

let create () : (module S) Async.Deferred.t =
  match Set_once.get keys with
  | Some x ->
      Async.Deferred.return x
  | None ->
      let open Async in
      let%map tx_vk = Lazy.force tx_vk
      and bc_pk = Lazy.force bc_pk
      and bc_vk = Lazy.force bc_vk in
      let module T = Transaction_snark.Verification.Make (struct
        let keys = tx_vk
      end) in
      let module B = Blockchain_snark.Blockchain_transition.Make (T) in
      let module Step = B.Step (struct
        let keys = Tick.Keypair.create ~pk:bc_pk.step ~vk:bc_vk.step
      end) in
      let module Wrap =
        B.Wrap (struct
            let verification_key = bc_vk.step
          end)
          (struct
            let keys = Tock.Keypair.create ~pk:bc_pk.wrap ~vk:bc_vk.wrap
          end)
      in
      let module M = struct
        let transaction_snark_keys = tx_vk

        module Step = struct
          include (
            Step :
              module type of Step with module Prover_state := Step.Prover_state )

          module Prover_state = Step_prover_state

          module Verification_key = struct
            let to_bool_list = Snark_params.tock_vk_to_bool_list
          end

          let instance_hash =
            unstage
              (Blockchain_snark.Blockchain_transition.instance_hash
                 (Tock.Keypair.vk Wrap.keys))

          let main ~logger ~proof_level ~constraint_constants x =
            let there
                { Prover_state.wrap_vk
                ; prev_proof
                ; prev_state
                ; genesis_state_hash
                ; update
                ; expected_next_state } =
              { Step.Prover_state.wrap_vk
              ; prev_proof
              ; prev_state
              ; genesis_state_hash
              ; update
              ; expected_next_state }
            in
            let back
                { Step.Prover_state.wrap_vk
                ; prev_proof
                ; prev_state
                ; genesis_state_hash
                ; update
                ; expected_next_state } =
              { Prover_state.wrap_vk
              ; prev_proof
              ; prev_state
              ; genesis_state_hash
              ; update
              ; expected_next_state }
            in
            let open Tick in
            with_state
              ~and_then:(fun s -> As_prover.set_state (back s))
              As_prover.(map get_state ~f:there)
              (main ~logger ~proof_level ~constraint_constants x)
        end

        module Wrap = struct
          include (
            Wrap :
              module type of Wrap with module Prover_state := Wrap.Prover_state )

          module Prover_state = Wrap_prover_state

          let main x =
            let there {Prover_state.proof} = {Wrap.Prover_state.proof} in
            let back {Wrap.Prover_state.proof} = {Prover_state.proof} in
            let open Tock in
            with_state
              ~and_then:(fun s -> As_prover.set_state (back s))
              As_prover.(map get_state ~f:there)
              (main x)
        end
      end in
      Set_once.set_exn keys Lexing.dummy_pos (module M : S) ;
      (module M : S)
