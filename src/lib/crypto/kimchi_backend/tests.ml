module Setup_test (Backend : Snarky_backendless.Backend_intf.S) = struct
  module Impl = Snarky_backendless.Snark.Run.Make (Backend) (Unit)
  open Impl

  let main x () =
    let y =
      exists Field.typ ~compute:(fun () ->
          Field.Constant.sqrt (As_prover.read_var x))
    in
    assert_r1cs y y x
end

let%test_module "pallas" =
  ( module struct
    include Setup_test (Kimchi_pasta.Pallas_based_plonk)
    open Impl

    let%test_unit "test snarky instance" =
      Kimchi_pasta.Pallas_based_plonk.Keypair.set_urs_info [] ;
      let _kp = Impl.generate_keypair ~exposing:[ Field.typ ] main in
      let _witness =
        Impl.generate_witness [ Field.typ ] main () (Field.Constant.of_int 4)
      in
      ()
  end )

let%test_module "vesta" =
  ( module struct
    include Setup_test (Kimchi_pasta.Vesta_based_plonk)
    open Impl

    let%test_unit "test snarky instance" =
      Kimchi_pasta.Pallas_based_plonk.Keypair.set_urs_info [] ;
      let _kp = Impl.generate_keypair ~exposing:[ Field.typ ] main in
      let _witness =
        Impl.generate_witness [ Field.typ ] main () (Field.Constant.of_int 4)
      in
      ()
  end )
