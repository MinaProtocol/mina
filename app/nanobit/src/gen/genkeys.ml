open Core
open Async
open Nanobit_base

module type Step_vk_intf = sig
  val verification_key : Tick.Verification_key.t
end

let step_kp =
  Transition.(Tick.generate_keypair (Step_base.input ()) Step_base.main)

let step_vk, step_pk =
  Transition.Tick.Keypair.(
    struct Step_vk: Step_vk_intf begin
      let verification_key = vk step_kp
    end,
    struct Step_pk: Step_pk_intf begin
      let private_key = pk step_kp
    end
  )

;;

let _ =
  let%map _ = Process.run_exn ~prog:"/bin/bash" ~args:[ "-c"; Printf.sprintf "echo \'let foo () = ()\' > %s" Sys.argv.(1)  ] () in
  exit 0
;;

let () = never_returns (Scheduler.go ())

