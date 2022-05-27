module Setup_test (Backend : Snarky_backendless.Backend_intf.S) = struct
  module Impl = Snarky_backendless.Snark.Run.Make (Backend)
  open Impl

  let main x () =
    let y =
      exists Field.typ ~compute:(fun () ->
          Field.Constant.sqrt (As_prover.read_var x) )
    in
    assert_r1cs y y x ;
    let z =
      exists Field.typ ~compute:(fun () ->
          Field.Constant.square (As_prover.read_var x) )
    in
    assert_r1cs x x z
end

let%test_unit "of_affine" =
  let one = Pasta_bindings.Pallas.one () in
  let x, y =
    match Pasta_bindings.Pallas.to_affine one with
    | Finite (x, y) ->
        (x, y)
    | Infinity ->
        assert false
  in
  Pasta_bindings.Fp.print x ;
  Pasta_bindings.Fp.print y ;
  Pasta_bindings.Pallas.(ignore (of_affine_coordinates x y : t))

let%test_unit "vector test" =
  let elt1 = Pasta_bindings.Fp.of_int 1231 in
  let elt2 = Pasta_bindings.Fp.of_int 893234 in
  let v = Kimchi_bindings.FieldVectors.Fp.create () in
  Kimchi_bindings.FieldVectors.Fp.emplace_back v elt1 ;
  Kimchi_bindings.FieldVectors.Fp.emplace_back v elt2 ;
  Kimchi_bindings.FieldVectors.Fp.emplace_back v elt1 ;
  let x0 = Kimchi_bindings.FieldVectors.Fp.get v 0 in
  Pasta_bindings.Fp.mut_mul x0 x0 ;
  assert (Pasta_bindings.Fp.equal elt1 (Kimchi_bindings.FieldVectors.Fp.get v 0)) ;
  assert (Pasta_bindings.Fp.equal elt2 (Kimchi_bindings.FieldVectors.Fp.get v 1)) ;
  assert (Pasta_bindings.Fp.equal elt1 (Kimchi_bindings.FieldVectors.Fp.get v 2))

let%test_module "pallas" =
  ( module struct
    include Setup_test (Kimchi_pasta.Pallas_based_plonk)
    open Impl

    let%test_unit "test snarky instance" =
      Kimchi_pasta.Pallas_based_plonk.Keypair.set_urs_info [] ;
      let _cs = Impl.constraint_system ~exposing:[ Field.typ ] main in
      let _witness =
        Impl.generate_witness [ Field.typ ] main (Field.Constant.of_int 4)
      in
      ()
  end )

let%test_module "vesta" =
  ( module struct
    include Setup_test (Kimchi_pasta.Vesta_based_plonk)
    open Impl

    let%test_unit "test snarky instance" =
      Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] ;
      let _cs = Impl.constraint_system ~exposing:[ Field.typ ] main in
      let _witness =
        Impl.generate_witness [ Field.typ ] main (Field.Constant.of_int 4)
      in
      ()
  end )
