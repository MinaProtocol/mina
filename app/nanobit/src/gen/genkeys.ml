open Core
open Async
open Nanobit_base
open Snark_params

module Transition = Nanobit_base.Blockchain_transition
;;

(* TODO: Enable this when we actually want it to run *)

(*let tick_kp =*)
  (*let open Transition in*)
  (*Tick.generate_keypair (Step_base.input ()) Step_base.main*)

(*let tick_vk = Tick.Keypair.vk tick_kp*)
(*let tick_pk = Tick.Keypair.pk tick_kp*)

(*module Wrap_base_applied = Transition.Wrap_base(struct*)
  (*let verification_key = tick_vk*)
(*end)*)

(*let tock_kp =*)
  (*let open Transition in*)
  (*Tock.generate_keypair (Wrap_base_applied.input ()) Wrap_base_applied.main*)
(*let tock_vk = Tock.Keypair.vk tock_kp*)
(*let tock_pk = Tock.Keypair.pk tock_kp*)

let code = Printf.sprintf
  "
  open Core
  open Async
  open Nanobit_base
  open Blockchain_transition
  open Snark_params

  module Transition = Blockchain_transition

  module Step = Transition.Step(struct
    let verification_key = Tick.Verification_key.of_string \"%s\"
    let proving_key = Tick.Proving_key.of_string \"%s\"
  end)

  module Wrap = Transition.Wrap
      (struct (* Step_vk *)
        let verification_key = Tick.Verification_key.of_string \"%s\"
      end) (struct (* Tock_keypair *)
        let verification_key = Tock.Verification_key.of_string \"%s\"
        let proving_key = Tock.Proving_key.of_string \"%s\"
      end)
  "
  (*(Tick.Verification_key.to_string tick_vk)*)
    (*(Tick.Proving_key.to_string tick_pk)*)
    (*(Tick.Verification_key.to_string tick_vk)*)
    (*(Tock.Verification_key.to_string tock_vk)*)
    (*(Tock.Proving_key.to_string tock_pk)*)
    "vk1" "pk1" "vk2" "vk3" "pk2"

let _ =
  let%map _ = Process.run_exn ~prog:"/bin/bash" ~args:[ "-c"; Printf.sprintf "echo \'%s\' > %s" code Sys.argv.(1)  ] () in
  exit 0
;;

let () = never_returns (Scheduler.go ())

