open Transaction_snark_tests.Util
open Core_kernel
open Signature_lib
module Impl = Pickles.Impls.Step
module Inner_curve = Snark_params.Tick.Inner_curve
module Nat = Pickles_types.Nat
module Local_state = Mina_state.Local_state
module Zkapp_command_segment = Transaction_snark.Zkapp_command_segment

let sk = Private_key.create ()

let pk = Public_key.of_private_key_exn sk

let pk_compressed = Public_key.compress pk

(* we want to create a circuit with a domain of size 2^16 *)
let num_constraints = 1 lsl 16

let expected_err =
  "polynomial segment size has to be not smaller than that of the circuit!"

let () =
  let f _ =
    Zkapps_examples.compile () ~cache:Cache_dir.cache
      ~auxiliary_typ:Impl.Typ.unit
      ~branches:(module Nat.N1)
      ~max_proofs_verified:(module Nat.N0)
      ~name:"big_circuit"
      ~constraint_constants:
        (Genesis_constants.Constraint_constants.to_snark_keys_header
           constraint_constants )
      ~choices:(fun ~self:_ ->
        [ Zkapps_big_circuit.rule ~num_constraints pk_compressed ] )
  in
  match f () with
  | exception Failure err when String.(err = expected_err) ->
      ()
  | _ ->
      failwith "Expected exception"
