open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

module Circuit = Kimchi_pasta_snarky_backend.Step_impl

(** Generic addition gate gadget. Constrains left_input + right_input = sum.
    Returns the sum. *)
let add (left_input : Circuit.Field.t) (right_input : Circuit.Field.t) :
    Circuit.Field.t =
  let open Circuit in
  (* Witness computation; sum = left_input + right_input *)
  let sum =
    exists Field.typ ~compute:(fun () ->
        let left_input = As_prover.read Field.typ left_input in
        let right_input = As_prover.read Field.typ right_input in
        Field.Constant.add left_input right_input )
  in

  let neg_one = Field.Constant.(negate one) in
  (* Set up generic add gate *)
  with_label "generic_add_gadget" (fun () ->
      assert_
        (Basic
           { l = (Field.Constant.one, left_input)
           ; r = (Field.Constant.one, right_input)
           ; o = (neg_one, sum)
           ; m = Field.Constant.zero
           ; c = Field.Constant.zero
           } ) ;
      sum )

(** Generic subtraction gate gadget. Constrains left_input - right_input =
    difference. Returns the difference. *)
let sub (left_input : Circuit.Field.t) (right_input : Circuit.Field.t) :
    Circuit.Field.t =
  let open Circuit in
  (* Witness computation; difference = left_input - right_input *)
  let difference =
    exists Field.typ ~compute:(fun () ->
        let left_input = As_prover.read Field.typ left_input in
        let right_input = As_prover.read Field.typ right_input in
        Field.Constant.sub left_input right_input )
  in

  (* Negative one gate coefficient *)
  let neg_one = Field.Constant.(negate one) in

  (* Set up generic sub gate *)
  with_label "generic_sub_gadget" (fun () ->
      assert_
        (Basic
           { l = (Field.Constant.one, left_input)
           ; r = (neg_one, right_input)
           ; o = (neg_one, difference)
           ; m = Field.Constant.zero
           ; c = Field.Constant.zero
           } ) ;
      difference )

(** Generic multiplication gate gadget. Constrains left_input * right_input =
    product. Returns the product. *)
let mul (left_input : Circuit.Field.t) (right_input : Circuit.Field.t) :
    Circuit.Field.t =
  let open Circuit in
  (* Witness computation: prod = left_input + right_input *)
  let prod =
    exists Field.typ ~compute:(fun () ->
        let left_input = As_prover.read Field.typ left_input in
        let right_input = As_prover.read Field.typ right_input in
        Field.Constant.mul left_input right_input )
  in

  let neg_one = Field.Constant.(negate one) in
  (* Set up generic mul gate *)
  with_label "generic_mul_gadget" (fun () ->
      assert_
        (Basic
           { l = (Field.Constant.zero, left_input)
           ; r = (Field.Constant.zero, right_input)
           ; o = (neg_one, prod)
           ; m = Field.Constant.one
           ; c = Field.Constant.zero
           } ) ;
      prod )
