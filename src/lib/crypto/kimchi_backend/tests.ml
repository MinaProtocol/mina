module Impl =
  Snarky_backendless.Snark.Run.Make (Kimchi_pasta.Pallas_based_plonk) (Unit)
open Impl

let main x () =
  let y =
    exists Field.typ ~compute:(fun () ->
        Field.Constant.sqrt (As_prover.read_var x))
  in
  assert_r1cs y y x

let%test_unit "thing" =
  Kimchi_pasta.Pallas_based_plonk.Keypair.set_urs_info [] ;
  let _kp = Impl.generate_keypair ~exposing:[ Field.typ ] main in
  let _witness =
    Impl.generate_witness [ Field.typ ] main () (Field.Constant.of_int 4)
  in
  ()
