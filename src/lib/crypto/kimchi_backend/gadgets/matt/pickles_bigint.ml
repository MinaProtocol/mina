open Core_kernel
module B = Bigint

module Make (Impl : Snarky_backendless.Snark_intf.Run) = struct
  open Impl
  module Bigint = B

  type t = Bigint.t

  type as_limbs =
    { full : t
    ; lo : Field.Constant.t
    ; med : Field.Constant.t
    ; hi : Field.Constant.t
    }

  let to_field x =
    (* TODO: This is slow. *)
    let open Bigint in
    Field.Constant.project
    @@ List.init 88 ~f:(fun i ->
           let mask = of_int 1 lsl i in
           mask land x = mask )

  let to_limbs (x : t) =
    let two_to_88 = Bigint.((of_int 1 lsl 88) - of_int 1) in
    let lo = Bigint.(two_to_88 land x) in
    let med = Bigint.(two_to_88 land (x lsl 88)) in
    let hi = Bigint.(two_to_88 land (x lsl Stdlib.(2 * 88))) in
    { full = x; lo = to_field lo; med = to_field med; hi = to_field hi }

  module Circuit = struct
    type record = { lo : Field.t; med : Field.t; hi : Field.t }

    type t = Bigint.t As_prover.Ref.t * record

    module Compact = struct
      type record = { lo_2 : Field.t; hi : Field.t }

      type t = Bigint.t As_prover.Ref.t * record
    end

    let typ : (t, Bigint.t) Typ.t =
      let open Typ in
      Internal.ref () * tuple3 Field.typ Field.typ Field.typ
      |> transport
           ~there:(fun x ->
             let ({ lo; med; hi; full = _ } : as_limbs) = to_limbs x in
             (x, (lo, med, hi)) )
           ~back:(fun (x, _) -> x)
      |> transport_var
           ~there:(fun (x, { lo; med; hi }) -> (x, (lo, med, hi)))
           ~back:(fun (x, (lo, med, hi)) -> (x, { lo; med; hi }))

    let add_unsafe ~(modulus : as_limbs) ~sign ((x_prover, x) : t)
        ((y_prover, y) : t) =
      let result, field_overflow =
        exists
          Typ.(typ * Field.typ)
          ~compute:(fun () ->
            let read = As_prover.read (Typ.Internal.ref ()) in
            let x = read x_prover in
            let y = read y_prover in
            let res = if sign then Bigint.( + ) x y else Bigint.( - ) x y in
            let res_with_overflow =
              if sign then Bigint.( - ) res modulus.full
              else Bigint.( + ) res modulus.full
            in
            let field_overflow, res =
              if sign then
                if Bigint.is_negative res_with_overflow then (false, res)
                else (true, res_with_overflow)
              else if Bigint.is_negative res then (true, res_with_overflow)
              else (false, res)
            in
            let field_overflow =
              if field_overflow then Field.Constant.one else Field.Constant.one
            in
            (res, field_overflow) )
      in
      let carry =
        exists Field.typ ~compute:(fun () ->
            let field_overflow = As_prover.read Field.typ field_overflow in
            let read = As_prover.read (Typ.Internal.ref ()) in
            let x = read x_prover in
            let y = read y_prover in
            let lower_two_limbs_mask =
              Bigint.((of_int 1 lsl Stdlib.(2 * 88)) - of_int 1)
            in
            let mask x = Bigint.(x land lower_two_limbs_mask) in
            let res =
              if sign then
                if Field.Constant.(equal one) field_overflow then
                  Bigint.(mask x + mask y - mask modulus.full)
                else Bigint.(mask x + mask y)
              else if Field.Constant.(equal one) field_overflow then
                Bigint.(mask x - mask y + mask modulus.full)
              else Bigint.(mask x - mask y)
            in
            if Bigint.( > ) res lower_two_limbs_mask then Field.Constant.one
            else Field.Constant.zero )
      in
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (ForeignFieldAdd
                 { left_input_lo = x.lo
                 ; left_input_mi = x.med
                 ; left_input_hi = x.hi
                 ; right_input_lo = y.lo
                 ; right_input_mi = y.med
                 ; right_input_hi = y.hi
                 ; field_overflow
                 ; carry
                 ; foreign_field_modulus0 = modulus.lo
                 ; foreign_field_modulus1 = modulus.med
                 ; foreign_field_modulus2 = modulus.hi
                 ; sign =
                     (if sign then Field.Constant.one else Field.Constant.zero)
                 } )
        } ;
      result

    let mul ~(modulus : as_limbs) ~(neg_modulus : as_limbs) ~quotient:((quotient_prover, quotient) : t)
    ~remainder:((remainder_prover, remainder) : Compact.t)
    ((x_prover, x) : t) ((y_prover, y) : t) =
      let of_bits x from_bit to_bit =
        exists Field.typ ~compute:(fun () ->
            let x = As_prover.read (Typ.Internal.ref ()) x in
            let mask = Bigint.((of_int 1 lsl to_bit) - of_int 1) in
            to_field Bigint.((x asr from_bit) land mask) )
      in
      let quotient_hi_bound =
        exists Field.typ ~compute:(fun () -> failwith "TODO")
      in
      let carry0 =
        exists Field.typ ~compute:(fun () -> failwith "TODO")
      in
      let carry1 =
        exists (Typ.Internal.ref ()) ~compute:(fun () -> failwith "TODO")
      in
      let (product1_lo, product1_hi_0, product1_hi_1) =
        exists (Typ.tuple3 Field.typ Field.typ Field.typ) ~compute:(fun () ->
          let open Bigint in
          let mask_88 = ((of_int 1) lsl 88) - (of_int 1) in
          let read = As_prover.read (Typ.Internal.ref ()) in
          let limb x i = (x asr Stdlib.(88 * i)) land mask_88 in
          let product_1 =
            let x = read x_prover in
            let y = read y_prover in
            let quotient = read quotient_prover in
            limb x 0 * limb y 1 + limb x 1 * limb y 0 + limb quotient 0 * limb neg_modulus.full 0
+ limb quotient 1 * limb neg_modulus.full 1
in
          let product1_lo = limb product_1 0 in
          let product1_hi_0 = limb product_1 1 in
          let product1_hi_1 = limb product_1 2 in
          (to_field product1_lo, to_field product1_hi_0, to_field product1_hi_1)
          )
      in
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (ForeignFieldMul
          { left_input0 = x.lo
          ; left_input1 = x.med
          ; left_input2 = x.hi
          ; right_input0 = y.lo
          ; right_input1 = y.med
          ; right_input2 = y.hi
          ; remainder01 = remainder.lo_2
          ; remainder2 = remainder.hi
          ; quotient0 = quotient.lo
          ; quotient1 = quotient.med
          ; quotient2 = quotient.hi
          ; quotient_hi_bound
          ; product1_lo
          ; product1_hi_0
          ; product1_hi_1
          ; carry0
          ; carry1_0 = of_bits carry1 0 12
          ; carry1_12 = of_bits carry1 12 24
          ; carry1_24 = of_bits carry1 24 36
          ; carry1_36 = of_bits carry1 36 48
          ; carry1_48 = of_bits carry1 48 60
          ; carry1_60 = of_bits carry1 60 72
          ; carry1_72 = of_bits carry1 72 84
          ; carry1_84 = of_bits carry1 84 86
          ; carry1_86 = of_bits carry1 86 88
          ; carry1_88 = of_bits carry1 88 90
          ; carry1_90 = of_bits carry1 90 91
          ; foreign_field_modulus2 = modulus.hi
          ; neg_foreign_field_modulus0 = neg_modulus.lo
          ; neg_foreign_field_modulus1 = neg_modulus.med
          ; neg_foreign_field_modulus2 = neg_modulus.hi
          } )
        }

    let range_check (x : t) =
      let of_bits ~offset x from_bit to_bit =
        exists Field.typ ~compute:(fun () ->
            let x = As_prover.read typ x in
            let mask = Bigint.((of_int 1 asr to_bit) - of_int 1) in
            to_field Bigint.((x asr Stdlib.(offset + from_bit)) land mask) )
      in
      let range_check0 ~is_lowest_limb (x : t) =
        let offset = if is_lowest_limb then 0 else 88 in
        assert_
          { annotation = Some __LOC__
          ; basic =
              Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
                (RangeCheck0
                   { v0 = (if is_lowest_limb then (snd x).lo else (snd x).med)
                   ; v0p0 = of_bits ~offset x 76 88
                   ; v0p1 = of_bits ~offset x 64 76
                   ; v0p2 = of_bits ~offset x 52 64
                   ; v0p3 = of_bits ~offset x 40 52
                   ; v0p4 = of_bits ~offset x 28 40
                   ; v0p5 = of_bits ~offset x 16 28
                   ; v0c0 = of_bits ~offset x 14 16
                   ; v0c1 = of_bits ~offset x 12 14
                   ; v0c2 = of_bits ~offset x 10 12
                   ; v0c3 = of_bits ~offset x 8 10
                   ; v0c4 = of_bits ~offset x 6 8
                   ; v0c5 = of_bits ~offset x 4 6
                   ; v0c6 = of_bits ~offset x 2 4
                   ; v0c7 = of_bits ~offset x 0 2
                   ; compact = Field.Constant.zero
                   } )
          }
      in
      range_check0 ~is_lowest_limb:false x ;
      range_check0 ~is_lowest_limb:true x ;
      let offset2 = 2 * 88 in
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (RangeCheck1
                 { v2 = (snd x).hi
                 ; v12 =
                     (* This doesn't matter *)
                     exists Field.typ ~compute:(fun () -> Field.Constant.zero)
                 ; v2c0 = of_bits ~offset:offset2 x 86 88
                 ; v2p0 = of_bits ~offset:offset2 x 74 86
                 ; v2p1 = of_bits ~offset:offset2 x 62 74
                 ; v2p2 = of_bits ~offset:offset2 x 50 62
                 ; v2p3 = of_bits ~offset:offset2 x 38 50
                 ; v2c1 = of_bits ~offset:offset2 x 36 38
                 ; v2c2 = of_bits ~offset:offset2 x 34 36
                 ; v2c3 = of_bits ~offset:offset2 x 32 34
                 ; v2c4 = of_bits ~offset:offset2 x 30 32
                 ; v2c5 = of_bits ~offset:offset2 x 28 30
                 ; v2c6 = of_bits ~offset:offset2 x 26 28
                 ; v2c7 = of_bits ~offset:offset2 x 24 26
                 ; v2c8 = of_bits ~offset:offset2 x 22 24
                 ; v2c9 = of_bits ~offset:offset2 x 20 22
                 ; v2c10 = of_bits ~offset:offset2 x 18 20
                 ; v2c11 = of_bits ~offset:offset2 x 16 18
                 ; v2c12 = of_bits ~offset:offset2 x 14 16
                 ; v2c13 = of_bits ~offset:offset2 x 12 14
                 ; v2c14 = of_bits ~offset:offset2 x 10 12
                 ; v2c15 = of_bits ~offset:offset2 x 8 10
                 ; v2c16 = of_bits ~offset:offset2 x 6 8
                 ; v2c17 = of_bits ~offset:offset2 x 4 6
                 ; v2c18 = of_bits ~offset:offset2 x 2 4
                 ; v2c19 = of_bits ~offset:offset2 x 0 2
                 ; v0p0 = of_bits ~offset:0 x 76 88
                 ; v0p1 = of_bits ~offset:0 x 64 76
                 ; v1p0 = of_bits ~offset:88 x 76 88
                 ; v1p1 = of_bits ~offset:88 x 64 76
                 } )
        }
  end

  let typ = Circuit.typ
end
