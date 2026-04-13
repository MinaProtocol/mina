open Core_kernel
open Currency

let%test_module "unchecked arithmetic" =
  ( module struct
    (* --- scale tests --- *)
    let%test_unit "scale by zero returns zero" =
      [%test_eq: Amount.t option] (Amount.scale Amount.zero 0) (Some Amount.zero) ;
      [%test_eq: Amount.t option]
        (Amount.scale (Amount.of_uint64 (Unsigned.UInt64.of_int 42)) 0)
        (Some Amount.zero)

    let%test_unit "scale by one is identity" =
      let v = Amount.of_uint64 (Unsigned.UInt64.of_int 12345) in
      [%test_eq: Amount.t option] (Amount.scale v 1) (Some v)

    let%test_unit "scale overflow returns none" =
      [%test_eq: Amount.t option] (Amount.scale Amount.max_int 2) None

    let%test_unit "scale correctness" =
      let v = Amount.of_uint64 (Unsigned.UInt64.of_int 100) in
      let expected = Amount.of_uint64 (Unsigned.UInt64.of_int 500) in
      [%test_eq: Amount.t option] (Amount.scale v 5) (Some expected)

    (* --- add / sub basic tests --- *)
    let%test_unit "add zero is identity" =
      let v = Amount.of_uint64 (Unsigned.UInt64.of_int 999) in
      [%test_eq: Amount.t option] (Amount.add v Amount.zero) (Some v) ;
      [%test_eq: Amount.t option] (Amount.add Amount.zero v) (Some v)

    let%test_unit "sub zero is identity" =
      let v = Amount.of_uint64 (Unsigned.UInt64.of_int 999) in
      [%test_eq: Amount.t option] (Amount.sub v Amount.zero) (Some v)

    let%test_unit "sub self is zero" =
      let v = Amount.of_uint64 (Unsigned.UInt64.of_int 999) in
      [%test_eq: Amount.t option] (Amount.sub v v) (Some Amount.zero)

    let%test_unit "add overflow returns none" =
      [%test_eq: Amount.t option]
        (Amount.add Amount.max_int Amount.max_int)
        None

    let%test_unit "sub underflow returns none" =
      let small = Amount.of_uint64 (Unsigned.UInt64.of_int 1) in
      let big = Amount.of_uint64 (Unsigned.UInt64.of_int 2) in
      [%test_eq: Amount.t option] (Amount.sub small big) None

    (* --- add_flagged / sub_flagged --- *)
    let%test_unit "add_flagged detects overflow" =
      let _, `Overflow b = Amount.add_flagged Amount.max_int Amount.max_int in
      assert b

    let%test_unit "add_flagged no overflow" =
      let v = Amount.of_uint64 (Unsigned.UInt64.of_int 5) in
      let w = Amount.of_uint64 (Unsigned.UInt64.of_int 10) in
      let result, `Overflow b = Amount.add_flagged v w in
      assert (not b) ;
      [%test_eq: Amount.t] result (Amount.of_uint64 (Unsigned.UInt64.of_int 15))

    let%test_unit "sub_flagged detects underflow" =
      let small = Amount.of_uint64 (Unsigned.UInt64.of_int 1) in
      let big = Amount.of_uint64 (Unsigned.UInt64.of_int 2) in
      let _, `Underflow b = Amount.sub_flagged small big in
      assert b

    let%test_unit "sub_flagged no underflow" =
      let big = Amount.of_uint64 (Unsigned.UInt64.of_int 10) in
      let small = Amount.of_uint64 (Unsigned.UInt64.of_int 3) in
      let result, `Underflow b = Amount.sub_flagged big small in
      assert (not b) ;
      [%test_eq: Amount.t] result (Amount.of_uint64 (Unsigned.UInt64.of_int 7))

    (* --- conversion tests --- *)
    let%test_unit "of_nanomina_int rejects negative" =
      [%test_eq: Amount.t option] (Amount.of_nanomina_int (-1)) None

    let%test_unit "of_nanomina_int accepts zero" =
      [%test_eq: Amount.t option] (Amount.of_nanomina_int 0) (Some Amount.zero)

    let%test_unit "of_nanomina_int roundtrip" =
      let n = 42_000_000 in
      let v = Amount.of_nanomina_int_exn n in
      [%test_eq: int] (Amount.to_nanomina_int v) n

    let%test_unit "of_mina_int roundtrip" =
      let v = Amount.of_mina_int_exn 5 in
      [%test_eq: int] (Amount.to_mina_int v) 5

    let%test_unit "of_mina_int_exn raises on negative" =
      match Amount.of_mina_int_exn (-1) with
      | exception _ ->
          ()
      | _ ->
          failwith "expected exception"

    let%test_unit "of_mina_string_exn edge cases" =
      (* whole number *)
      let v1 = Amount.of_mina_string_exn "1" in
      [%test_eq: Amount.t] v1 (Amount.of_mina_int_exn 1) ;
      (* with decimals *)
      let v2 = Amount.of_mina_string_exn "1.5" in
      [%test_eq: Amount.t] v2
        (Amount.of_uint64 (Unsigned.UInt64.of_int 1_500_000_000)) ;
      (* max precision *)
      let v3 = Amount.of_mina_string_exn "0.000000001" in
      [%test_eq: Amount.t] v3 (Amount.of_uint64 (Unsigned.UInt64.of_int 1))

    (* --- Fee/Amount conversions --- *)
    let%test_unit "Amount.of_fee and to_fee roundtrip" =
      let fee = Fee.of_uint64 (Unsigned.UInt64.of_int 12345) in
      [%test_eq: Fee.t] (Amount.to_fee (Amount.of_fee fee)) fee

    let%test_unit "Amount.add_fee works" =
      let amt = Amount.of_uint64 (Unsigned.UInt64.of_int 100) in
      let fee = Fee.of_uint64 (Unsigned.UInt64.of_int 50) in
      [%test_eq: Amount.t option] (Amount.add_fee amt fee)
        (Some (Amount.of_uint64 (Unsigned.UInt64.of_int 150)))
  end )

let%test_module "signed operations" =
  ( module struct
    let mk n = Amount.of_uint64 (Unsigned.UInt64.of_int n)

    (* --- create normalizes zero --- *)
    let%test_unit "Signed.create normalizes zero to positive" =
      let s = Amount.Signed.create ~magnitude:Amount.zero ~sgn:Sgn.Neg in
      [%test_eq: Sgn.t] s.sgn Sgn.Pos

    let%test_unit "Signed.create preserves sign for nonzero" =
      let s = Amount.Signed.create ~magnitude:(mk 5) ~sgn:Sgn.Neg in
      [%test_eq: Sgn.t] s.sgn Sgn.Neg

    (* --- predicates --- *)
    let%test_unit "is_zero on zero" =
      assert (Amount.Signed.is_zero Amount.Signed.zero)

    let%test_unit "is_zero on nonzero" =
      let s = Amount.Signed.create ~magnitude:(mk 1) ~sgn:Sgn.Pos in
      assert (not (Amount.Signed.is_zero s))

    let%test_unit "is_positive" =
      let pos = Amount.Signed.create ~magnitude:(mk 5) ~sgn:Sgn.Pos in
      let neg = Amount.Signed.create ~magnitude:(mk 5) ~sgn:Sgn.Neg in
      let zero = Amount.Signed.zero in
      assert (Amount.Signed.is_positive pos) ;
      assert (not (Amount.Signed.is_positive neg)) ;
      assert (not (Amount.Signed.is_positive zero))

    let%test_unit "is_negative" =
      let pos = Amount.Signed.create ~magnitude:(mk 5) ~sgn:Sgn.Pos in
      let neg = Amount.Signed.create ~magnitude:(mk 5) ~sgn:Sgn.Neg in
      let zero = Amount.Signed.zero in
      assert (Amount.Signed.is_negative neg) ;
      assert (not (Amount.Signed.is_negative pos)) ;
      assert (not (Amount.Signed.is_negative zero))

    (* --- negate --- *)
    let%test_unit "negate positive" =
      let s = Amount.Signed.create ~magnitude:(mk 5) ~sgn:Sgn.Pos in
      let n = Amount.Signed.negate s in
      [%test_eq: Sgn.t] n.sgn Sgn.Neg ;
      [%test_eq: Amount.t] n.magnitude (mk 5)

    let%test_unit "negate zero stays positive" =
      let n = Amount.Signed.negate Amount.Signed.zero in
      [%test_eq: Sgn.t] n.sgn Sgn.Pos

    (* --- signed add --- *)
    let%test_unit "add pos + pos" =
      let a = Amount.Signed.create ~magnitude:(mk 3) ~sgn:Sgn.Pos in
      let b = Amount.Signed.create ~magnitude:(mk 7) ~sgn:Sgn.Pos in
      let result = Option.value_exn (Amount.Signed.add a b) in
      [%test_eq: Amount.t] result.magnitude (mk 10) ;
      [%test_eq: Sgn.t] result.sgn Sgn.Pos

    let%test_unit "add neg + neg" =
      let a = Amount.Signed.create ~magnitude:(mk 3) ~sgn:Sgn.Neg in
      let b = Amount.Signed.create ~magnitude:(mk 7) ~sgn:Sgn.Neg in
      let result = Option.value_exn (Amount.Signed.add a b) in
      [%test_eq: Amount.t] result.magnitude (mk 10) ;
      [%test_eq: Sgn.t] result.sgn Sgn.Neg

    let%test_unit "add pos + neg where pos > neg" =
      let a = Amount.Signed.create ~magnitude:(mk 10) ~sgn:Sgn.Pos in
      let b = Amount.Signed.create ~magnitude:(mk 3) ~sgn:Sgn.Neg in
      let result = Option.value_exn (Amount.Signed.add a b) in
      [%test_eq: Amount.t] result.magnitude (mk 7) ;
      [%test_eq: Sgn.t] result.sgn Sgn.Pos

    let%test_unit "add pos + neg where neg > pos" =
      let a = Amount.Signed.create ~magnitude:(mk 3) ~sgn:Sgn.Pos in
      let b = Amount.Signed.create ~magnitude:(mk 10) ~sgn:Sgn.Neg in
      let result = Option.value_exn (Amount.Signed.add a b) in
      [%test_eq: Amount.t] result.magnitude (mk 7) ;
      [%test_eq: Sgn.t] result.sgn Sgn.Neg

    let%test_unit "add pos + neg cancels to zero" =
      let a = Amount.Signed.create ~magnitude:(mk 5) ~sgn:Sgn.Pos in
      let b = Amount.Signed.create ~magnitude:(mk 5) ~sgn:Sgn.Neg in
      let result = Option.value_exn (Amount.Signed.add a b) in
      assert (Amount.Signed.is_zero result)

    let%test_unit "add same sign overflow returns none" =
      let a = Amount.Signed.create ~magnitude:Amount.max_int ~sgn:Sgn.Pos in
      let b = Amount.Signed.create ~magnitude:(mk 1) ~sgn:Sgn.Pos in
      [%test_eq: Amount.Signed.t option] (Amount.Signed.add a b) None

    (* --- signed equality on zero --- *)
    let%test_unit "signed equal: positive and negative zero are equal" =
      let pos_zero =
        Amount.Signed.create_preserve_zero_sign ~magnitude:Amount.zero
          ~sgn:Sgn.Pos
      in
      let neg_zero =
        Amount.Signed.create_preserve_zero_sign ~magnitude:Amount.zero
          ~sgn:Sgn.Neg
      in
      assert (Amount.Signed.equal pos_zero neg_zero)

    (* --- add_signed_flagged --- *)
    let%test_unit "add_signed_flagged positive no overflow" =
      let base = mk 100 in
      let delta = Amount.Signed.create ~magnitude:(mk 50) ~sgn:Sgn.Pos in
      let result, `Overflow b = Amount.add_signed_flagged base delta in
      assert (not b) ;
      [%test_eq: Amount.t] result (mk 150)

    let%test_unit "add_signed_flagged negative no underflow" =
      let base = mk 100 in
      let delta = Amount.Signed.create ~magnitude:(mk 30) ~sgn:Sgn.Neg in
      let result, `Overflow b = Amount.add_signed_flagged base delta in
      assert (not b) ;
      [%test_eq: Amount.t] result (mk 70)

    let%test_unit "add_signed_flagged negative underflow" =
      let base = mk 10 in
      let delta = Amount.Signed.create ~magnitude:(mk 20) ~sgn:Sgn.Neg in
      let _, `Overflow b = Amount.add_signed_flagged base delta in
      assert b

    let%test_unit "add_signed_flagged positive overflow" =
      let delta = Amount.Signed.create ~magnitude:(mk 1) ~sgn:Sgn.Pos in
      let _, `Overflow b = Amount.add_signed_flagged Amount.max_int delta in
      assert b
  end )

let%test_module "balance operations" =
  ( module struct
    let mk n = Balance.of_uint64 (Unsigned.UInt64.of_int n)

    let mk_amount n = Amount.of_uint64 (Unsigned.UInt64.of_int n)

    let%test_unit "add_amount within range" =
      [%test_eq: Balance.t option]
        (Balance.add_amount (mk 100) (mk_amount 50))
        (Some (mk 150))

    let%test_unit "add_amount overflow" =
      [%test_eq: Balance.t option]
        (Balance.add_amount
           (Balance.of_uint64 Unsigned.UInt64.max_int)
           (mk_amount 1) )
        None

    let%test_unit "sub_amount within range" =
      [%test_eq: Balance.t option]
        (Balance.sub_amount (mk 100) (mk_amount 30))
        (Some (mk 70))

    let%test_unit "sub_amount underflow" =
      [%test_eq: Balance.t option]
        (Balance.sub_amount (mk 10) (mk_amount 20))
        None

    let%test_unit "sub_amount to zero" =
      [%test_eq: Balance.t option]
        (Balance.sub_amount (mk 100) (mk_amount 100))
        (Some (mk 0))

    let%test_unit "add_amount_flagged overflow flag" =
      let _, `Overflow b =
        Balance.add_amount_flagged
          (Balance.of_uint64 Unsigned.UInt64.max_int)
          (mk_amount 1)
      in
      assert b

    let%test_unit "sub_amount_flagged underflow flag" =
      let _, `Underflow b = Balance.sub_amount_flagged (mk 5) (mk_amount 10) in
      assert b

    let%test_unit "to_amount roundtrip" =
      let b = mk 12345 in
      [%test_eq: Amount.t] (Balance.to_amount b) (mk_amount 12345)
  end )

let%test_module "fee_rate operations" =
  ( module struct
    let fee n = Fee.of_uint64 (Unsigned.UInt64.of_int n)

    let%test_unit "make creates valid rate" =
      let r = Fee_rate.make (fee 100) 2 in
      assert (Option.is_some r)

    let%test_unit "make with zero weight" =
      let r = Fee_rate.make (fee 0) 0 in
      assert (Option.is_some r)

    let%test_unit "to_uint64 on integer rate" =
      let r = Fee_rate.make_exn (fee 100) 1 in
      let result = Fee_rate.to_uint64 r in
      assert (Option.is_some result) ;
      assert (
        Unsigned.UInt64.equal (Option.value_exn result)
          (Unsigned.UInt64.of_int 100) )

    let%test_unit "to_uint64 on fractional rate is none" =
      let r = Fee_rate.make_exn (fee 100) 3 in
      assert (Option.is_none (Fee_rate.to_uint64 r))

    let%test_unit "add two rates" =
      let a = Fee_rate.make_exn (fee 100) 1 in
      let b = Fee_rate.make_exn (fee 200) 1 in
      let result = Option.value_exn (Fee_rate.add a b) in
      assert (
        Unsigned.UInt64.equal
          (Fee_rate.to_uint64_exn result)
          (Unsigned.UInt64.of_int 300) )

    let%test_unit "sub two rates" =
      let a = Fee_rate.make_exn (fee 200) 1 in
      let b = Fee_rate.make_exn (fee 100) 1 in
      let result = Option.value_exn (Fee_rate.sub a b) in
      assert (
        Unsigned.UInt64.equal
          (Fee_rate.to_uint64_exn result)
          (Unsigned.UInt64.of_int 100) )

    let%test_unit "compare rates" =
      let a = Fee_rate.make_exn (fee 100) 1 in
      let b = Fee_rate.make_exn (fee 200) 1 in
      assert (Fee_rate.compare a b < 0) ;
      assert (Fee_rate.compare b a > 0) ;
      assert (Int.equal (Fee_rate.compare a a) 0)

    let%test_unit "compare fractional rates" =
      (* 100/3 vs 100/2 => 33.33 vs 50 *)
      let a = Fee_rate.make_exn (fee 100) 3 in
      let b = Fee_rate.make_exn (fee 100) 2 in
      assert (Fee_rate.compare a b < 0)

    let%test_unit "scale rate" =
      let r = Fee_rate.make_exn (fee 100) 1 in
      let scaled = Option.value_exn (Fee_rate.scale r 3) in
      assert (
        Unsigned.UInt64.equal
          (Fee_rate.to_uint64_exn scaled)
          (Unsigned.UInt64.of_int 300) )

    let%test_unit "mul rates" =
      let a = Fee_rate.make_exn (fee 10) 1 in
      let b = Fee_rate.make_exn (fee 20) 1 in
      let result = Option.value_exn (Fee_rate.mul a b) in
      assert (
        Unsigned.UInt64.equal
          (Fee_rate.to_uint64_exn result)
          (Unsigned.UInt64.of_int 200) )

    let%test_unit "div rates" =
      let a = Fee_rate.make_exn (fee 100) 1 in
      let b = Fee_rate.make_exn (fee 10) 1 in
      let result = Option.value_exn (Fee_rate.div a b) in
      assert (
        Unsigned.UInt64.equal
          (Fee_rate.to_uint64_exn result)
          (Unsigned.UInt64.of_int 10) )

    let%test_unit "sexp roundtrip" =
      let r = Fee_rate.make_exn (fee 100) 3 in
      let s = Fee_rate.sexp_of_t r in
      let r' = Fee_rate.t_of_sexp s in
      assert (Int.equal (Fee_rate.compare r r') 0)
  end )
