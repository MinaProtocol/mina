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

      let computation i16 () =
        let open Field in

        for j = 0 to 1 do

          let i4 = sqrt i16 in
          let i_16 = inv i16 in
          let i_4 = inv i4 in

          let j1 = i4 * i16 in
          let j_1 = i_4 * i_16 in

          let k1 = j1 * j_1 in
          let k2 = k1 - one in

          assert_r1cs j1 j_1 one;
          assert_ (Snarky.Constraint.boolean k1);
          assert_ (Snarky.Constraint.equal k2 zero);

        done;

        ()

      let input () = Impl.Data_spec.[Impl.Field.typ]
      let keys = Impl.generate_keypair ~exposing:(input ()) computation
      let statement = Impl.Field.Constant.of_int 256
      let proof = Impl.prove (Impl.Keypair.pk keys) (input ()) computation () statement
      let%test_unit "check backend ComputationExample proof" =
        assert (Impl.verify proof (Impl.Keypair.vk keys) (input ()) statement)
    end

    module Impl = Snarky.Snark.Run.Make(Zexe_backend.Tweedle.Dee_based_plonk) (Core.Unit)
    module Params = struct let params = Sponge.Params.(map tweedle_p ~f:Impl.Field.Constant.of_string) end
    include ComputationExample (Impl) (Params) 
  end )
