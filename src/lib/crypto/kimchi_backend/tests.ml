module Impl =
  Snarky_backendless.Snark.Run.Make (Kimchi_pasta.Pallas_based_plonk) (Unit)
open Impl

let main x () =
  let y =
    exists Field.typ ~compute:(fun () ->
        Field.Constant.sqrt (As_prover.read_var x))
  in
  assert_r1cs y y x

let%test_unit "of_affine" =
  let one = Kimchi.Pallas.one () in
  let x, y =
    match Kimchi.Pallas.to_affine one with
    | Finite (x, y) ->
        (x, y)
    | Infinity ->
        assert false
  in
  Kimchi.Foundations.Fp.print x ;
  Kimchi.Foundations.Fp.print y ;
  Kimchi.Pallas.(ignore (of_affine_coordinates x y : t))

let%test_unit "vector test" =
  let elt1 = Kimchi.Foundations.Fp.of_int 1231 in
  let elt2 = Kimchi.Foundations.Fp.of_int 893234 in
  let v = Kimchi.FieldVectors.Fp.create () in
  Kimchi.FieldVectors.Fp.emplace_back v elt1 ;
  Kimchi.FieldVectors.Fp.emplace_back v elt2 ;
  Kimchi.FieldVectors.Fp.emplace_back v elt1 ;
  let x0 = Kimchi.FieldVectors.Fp.get v 0 in
  Kimchi.Foundations.Fp.mut_mul x0 x0 ;
  assert (Kimchi.Foundations.Fp.equal elt1 (Kimchi.FieldVectors.Fp.get v 0)) ;
  assert (Kimchi.Foundations.Fp.equal elt2 (Kimchi.FieldVectors.Fp.get v 1)) ;
  assert (Kimchi.Foundations.Fp.equal elt1 (Kimchi.FieldVectors.Fp.get v 2))

let%test_unit "thing" =
  Kimchi_pasta.Pallas_based_plonk.Keypair.set_urs_info [] ;
  let _kp = Impl.generate_keypair ~exposing:[ Field.typ ] main in
  let _witness =
    Impl.generate_witness [ Field.typ ] main () (Field.Constant.of_int 4)
  in
  ()
