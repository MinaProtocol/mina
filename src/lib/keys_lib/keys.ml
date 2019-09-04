open Core
open Snark_params
open Coda_state

module type S = sig
  val transaction_snark_keys : Transaction_snark.Keys.Verification.t

  val create_state_proof :
       Tick.Handler.t
    -> Protocol_state.value
    -> ( Protocol_state.value
       , Snark_transition.value )
       Transition_system.Step.Witness.t
    -> Tock.Proof.t Or_error.t

  val check_constraints :
       Tick.Handler.t
    -> Protocol_state.value
    -> ( Protocol_state.value
       , Snark_transition.value )
       Transition_system.Step.Witness.t
    -> unit Or_error.t

  val verify_state_proof : Protocol_state.value -> Tock.Proof.t -> bool
end

let tx_vk = lazy (Snark_keys.transaction_verification ())

let bc_pk = lazy (Snark_keys.blockchain_proving ())

let bc_vk = lazy (Snark_keys.blockchain_verification ())

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
      let module M = struct
        let transaction_snark_keys = tx_vk

        open Transition_system

        let vks =
          Step.Verification_keys.create ~wrap_vk:bc_vk.wrap ~step_vk:bc_vk.step

        let check_constraints handler state witness =
          B.Step.check_constraints ~handler vks state witness

        let create_state_proof =
          let wrap =
            unstage (Transition_system.Wrap.prove bc_vk.step bc_pk.wrap)
          in
          fun handler next_state witness ->
            let open Or_error.Let_syntax in
            let%bind top_hash, proof =
              B.Step.prove ~handler vks bc_pk.step next_state witness
            in
            wrap top_hash proof

        let verify_state_proof =
          let verify = unstage (Wrap.verify bc_vk.step bc_vk.wrap) in
          fun protocol_state wrapped_proof ->
            verify (B.Step.instance_hash vks protocol_state) wrapped_proof
      end in
      Set_once.set_exn keys Lexing.dummy_pos (module M : S) ;
      (module M : S)
