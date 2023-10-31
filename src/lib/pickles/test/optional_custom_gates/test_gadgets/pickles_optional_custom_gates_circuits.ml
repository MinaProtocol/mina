open Core_kernel
open Pickles_types
open Pickles.Impls.Step

let add_constraint c = assert_ { basic = c; annotation = None }

let add_plonk_constraint c =
  add_constraint
    (Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T c)

let fresh_int i = exists Field.typ ~compute:(fun () -> Field.Constant.of_int i)

let main_xor () =
  add_plonk_constraint
    (Xor
       { in1 = fresh_int 0
       ; in2 = fresh_int 0
       ; out = fresh_int 0
       ; in1_0 = fresh_int 0
       ; in1_1 = fresh_int 0
       ; in1_2 = fresh_int 0
       ; in1_3 = fresh_int 0
       ; in2_0 = fresh_int 0
       ; in2_1 = fresh_int 0
       ; in2_2 = fresh_int 0
       ; in2_3 = fresh_int 0
       ; out_0 = fresh_int 0
       ; out_1 = fresh_int 0
       ; out_2 = fresh_int 0
       ; out_3 = fresh_int 0
       } ) ;
  add_plonk_constraint (Raw { kind = Zero; values = [||]; coeffs = [||] })

let main_range_check0 () =
  add_plonk_constraint
    (RangeCheck0
       { v0 = fresh_int 0
       ; v0p0 = fresh_int 0
       ; v0p1 = fresh_int 0
       ; v0p2 = fresh_int 0
       ; v0p3 = fresh_int 0
       ; v0p4 = fresh_int 0
       ; v0p5 = fresh_int 0
       ; v0c0 = fresh_int 0
       ; v0c1 = fresh_int 0
       ; v0c2 = fresh_int 0
       ; v0c3 = fresh_int 0
       ; v0c4 = fresh_int 0
       ; v0c5 = fresh_int 0
       ; v0c6 = fresh_int 0
       ; v0c7 = fresh_int 0
       ; (* Coefficients *)
         compact = Field.Constant.zero
       } )

let main_range_check1 () =
  add_plonk_constraint
    (RangeCheck1
       { v2 = fresh_int 0
       ; v12 = fresh_int 0
       ; v2c0 = fresh_int 0
       ; v2p0 = fresh_int 0
       ; v2p1 = fresh_int 0
       ; v2p2 = fresh_int 0
       ; v2p3 = fresh_int 0
       ; v2c1 = fresh_int 0
       ; v2c2 = fresh_int 0
       ; v2c3 = fresh_int 0
       ; v2c4 = fresh_int 0
       ; v2c5 = fresh_int 0
       ; v2c6 = fresh_int 0
       ; v2c7 = fresh_int 0
       ; v2c8 = fresh_int 0
       ; v2c9 = fresh_int 0
       ; v2c10 = fresh_int 0
       ; v2c11 = fresh_int 0
       ; v0p0 = fresh_int 0
       ; v0p1 = fresh_int 0
       ; v1p0 = fresh_int 0
       ; v1p1 = fresh_int 0
       ; v2c12 = fresh_int 0
       ; v2c13 = fresh_int 0
       ; v2c14 = fresh_int 0
       ; v2c15 = fresh_int 0
       ; v2c16 = fresh_int 0
       ; v2c17 = fresh_int 0
       ; v2c18 = fresh_int 0
       ; v2c19 = fresh_int 0
       } )

let main_rot () =
  add_plonk_constraint
    (Rot64
       { word = fresh_int 0
       ; rotated = fresh_int 0
       ; excess = fresh_int 0
       ; bound_limb0 = fresh_int 0xFFF
       ; bound_limb1 = fresh_int 0xFFF
       ; bound_limb2 = fresh_int 0xFFF
       ; bound_limb3 = fresh_int 0xFFF
       ; bound_crumb0 = fresh_int 3
       ; bound_crumb1 = fresh_int 3
       ; bound_crumb2 = fresh_int 3
       ; bound_crumb3 = fresh_int 3
       ; bound_crumb4 = fresh_int 3
       ; bound_crumb5 = fresh_int 3
       ; bound_crumb6 = fresh_int 3
       ; bound_crumb7 = fresh_int 3
       ; two_to_rot = Field.Constant.one
       } ) ;
  add_plonk_constraint
    (Raw { kind = Zero; values = [| fresh_int 0 |]; coeffs = [||] })

let main_foreign_field_add () =
  add_plonk_constraint
    (ForeignFieldAdd
       { left_input_lo = fresh_int 0
       ; left_input_mi = fresh_int 0
       ; left_input_hi = fresh_int 0
       ; right_input_lo = fresh_int 0
       ; right_input_mi = fresh_int 0
       ; right_input_hi = fresh_int 0
       ; field_overflow = fresh_int 0
       ; carry = fresh_int 0
       ; foreign_field_modulus0 = Field.Constant.of_int 1
       ; foreign_field_modulus1 = Field.Constant.of_int 0
       ; foreign_field_modulus2 = Field.Constant.of_int 0
       ; sign = Field.Constant.of_int 0
       } ) ;
  add_plonk_constraint
    (Raw { kind = Zero; values = [| fresh_int 0 |]; coeffs = [||] })

let main_foreign_field_mul () =
  add_plonk_constraint
    (ForeignFieldMul
       { left_input0 = fresh_int 0
       ; left_input1 = fresh_int 0
       ; left_input2 = fresh_int 0
       ; right_input0 = fresh_int 0
       ; right_input1 = fresh_int 0
       ; right_input2 = fresh_int 0
       ; remainder01 = fresh_int 0
       ; remainder2 = fresh_int 0
       ; quotient0 = fresh_int 0
       ; quotient1 = fresh_int 0
       ; quotient2 = fresh_int 0
       ; quotient_hi_bound =
           exists Field.typ ~compute:(fun () ->
               let open Field.Constant in
               let two_to_21 = of_int Int.(2 lsl 21) in
               let two_to_42 = two_to_21 * two_to_21 in
               let two_to_84 = two_to_42 * two_to_42 in
               two_to_84 - one - one )
       ; product1_lo = fresh_int 0
       ; product1_hi_0 = fresh_int 0
       ; product1_hi_1 = fresh_int 0
       ; carry0 = fresh_int 0
       ; carry1_0 = fresh_int 0
       ; carry1_12 = fresh_int 0
       ; carry1_24 = fresh_int 0
       ; carry1_36 = fresh_int 0
       ; carry1_48 = fresh_int 0
       ; carry1_60 = fresh_int 0
       ; carry1_72 = fresh_int 0
       ; carry1_84 = fresh_int 0
       ; carry1_86 = fresh_int 0
       ; carry1_88 = fresh_int 0
       ; carry1_90 = fresh_int 0
       ; foreign_field_modulus2 = Field.Constant.one
       ; neg_foreign_field_modulus0 = Field.Constant.zero
       ; neg_foreign_field_modulus1 = Field.Constant.zero
       ; neg_foreign_field_modulus2 =
           Field.Constant.(
             let two_to_22 = of_int Int.(2 lsl 22) in
             let two_to_44 = two_to_22 * two_to_22 in
             let two_to_88 = two_to_44 * two_to_44 in
             two_to_88 - one)
       } ) ;
  add_plonk_constraint
    (Raw { kind = Zero; values = [| fresh_int 0 |]; coeffs = [||] })

let main_body ~(feature_flags : _ Plonk_types.Features.t) () =
  if feature_flags.rot then main_rot () ;
  if feature_flags.xor then main_xor () ;
  if feature_flags.range_check0 then main_range_check0 () ;
  if feature_flags.range_check1 then main_range_check1 () ;
  if feature_flags.foreign_field_add then main_foreign_field_add () ;
  if feature_flags.foreign_field_mul then main_foreign_field_mul ()
