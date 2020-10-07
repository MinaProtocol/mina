open Snarky_bn382.Tweedle
let%test_module "backend test" =

  ( module struct
    let () =
      Zexe_backend.Tweedle.Dee_based_plonk.Keypair.set_urs_info
        [On_disk {directory= "/tmp/"; should_write= true}]

    module ComputationExample
        (Impl : Snarky.Snark_intf.Run with type prover_state = unit and type field = Dee.Field.t)
        (Params : sig val params : Impl.field Sponge.Params.t end)
    = struct
      open Core
      open Impl

      let computation x () =
        let open Field in

        for j = 0 to 111 do

          let scalar = [|one; one; zero; one; zero; one; one; zero; one; zero; one; one; zero; one; zero|] in
          let y = sqrt (x*x*x + (Impl.Field.of_int 5)) in

          let module Ecc = Plonk.Ecc.Constraints (Impl) in
  
          let rec double (x, y) n = if n < 1 then (x, y) else double (Ecc.double (x, y)) Int.(n - 1) in
          let xd, yd = double (x, y) (Array.length scalar) in

          let x1, y1 = Ecc.add (Ecc.scale (x, y) scalar) (xd, negate yd) in
          assert_ (Snarky.Constraint.equal (y1*y1) (x1*x1*x1 + (Impl.Field.of_int 5)));

          let x2, y2 = Ecc.endoscale (x, y) scalar in
          assert_ (Snarky.Constraint.equal (y2*y2) (x2*x2*x2 + (Impl.Field.of_int 5)));

          let module Poseidon = Plonk.Poseidon.Constraints (Impl) (Params) in
  
          let perm = Poseidon.permute [|x; y; x*y|] 62 in
          assert_ (Snarky.Constraint.equal perm.(0) perm.(0));

        done;

        ()

      let input () = Impl.Data_spec.[Impl.Field.typ]
      let keys = Impl.generate_keypair ~exposing:(input ()) computation
      let statement = Impl.Field.Constant.of_int 2
      let proof = Impl.prove (Impl.Keypair.pk keys) (input ()) computation () statement
      let%test_unit "check backend ComputationExample proof" =
        assert (Impl.verify proof (Impl.Keypair.vk keys) (input ()) statement)
    end

    module Impl = Snarky.Snark.Run.Make(Zexe_backend.Tweedle.Dee_based_plonk) (Core.Unit)
    module Params = struct let params = Sponge.Params.(map tweedle_p ~f:Impl.Field.Constant.of_string) end
    include ComputationExample (Impl) (Params) 
  end )
