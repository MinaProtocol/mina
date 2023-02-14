open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

let add (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (left_input : Circuit.Field.t) (right_input : Circuit.Field.t) : Circuit.Field.t =

    (* Witness computation *)
    let sum = exists Field.typ ~compute:(fun () ->
        let left_input = As_prover.read Field.typ left_input in
        let right_input = As_prover.read Field.typ right_input in
        Field.Constant.add left_input right_input) in

    (* Set up generic gate *)
    with_label "generic_add" (fun () ->
        assert_
          { annotation = Some __LOC__
          ; basic =
              Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (Basic
              { l = (Field.Constant.one, left_input)
              ; r = (Field.Constant.one, right_input)
              ; o = (negate Field.Constant.one, sum)
              ; m = Field.Constant.zero
              ; c = Field.Constant.zero
              } )
          } ;
        sum )