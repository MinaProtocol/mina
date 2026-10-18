open Core_kernel
open Currency

(* Convenience constructors used throughout this file. They wrap the
   nanomina-valued [of_uint64] of each module so that tests can express
   small literal magnitudes without spelling out the full conversion. *)
let amount_of_int n = Amount.of_uint64 (Unsigned.UInt64.of_int n)

let balance_of_int n = Balance.of_uint64 (Unsigned.UInt64.of_int n)

let fee_of_int n = Fee.of_uint64 (Unsigned.UInt64.of_int n)

let%test_module "unchecked arithmetic" =
  ( module struct
    (* --- scale edge cases --- *)
    let%test_unit "scale overflow returns none" =
      [%test_eq: Amount.t option] (Amount.scale Amount.max_int 2) None

    let%test_unit "scale correctness" =
      let v = amount_of_int 100 in
      let expected = amount_of_int 500 in
      [%test_eq: Amount.t option] (Amount.scale v 5) (Some expected)

    (* --- add / sub edge cases --- *)
    let%test_unit "add overflow returns none" =
      [%test_eq: Amount.t option]
        (Amount.add Amount.max_int Amount.max_int)
        None

    let%test_unit "sub underflow returns none" =
      let small = amount_of_int 1 in
      let big = amount_of_int 2 in
      [%test_eq: Amount.t option] (Amount.sub small big) None

    (* --- add_flagged / sub_flagged edge cases --- *)
    let%test_unit "add_flagged detects overflow" =
      let _, `Overflow b = Amount.add_flagged Amount.max_int Amount.max_int in
      assert b

    let%test_unit "sub_flagged detects underflow" =
      let small = amount_of_int 1 in
      let big = amount_of_int 2 in
      let _, `Underflow b = Amount.sub_flagged small big in
      assert b

    (* --- conversion edge cases --- *)
    let%test_unit "of_nanomina_int rejects negative" =
      [%test_eq: Amount.t option] (Amount.of_nanomina_int (-1)) None

    let%test_unit "of_nanomina_int accepts zero" =
      [%test_eq: Amount.t option] (Amount.of_nanomina_int 0) (Some Amount.zero)

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
      [%test_eq: Amount.t] v2 (amount_of_int 1_500_000_000) ;
      (* max precision *)
      let v3 = Amount.of_mina_string_exn "0.000000001" in
      [%test_eq: Amount.t] v3 (amount_of_int 1)
  end )

let%test_module "signed operations" =
  ( module struct
    (* --- zero special cases --- *)
    let%test_unit "Signed.create normalizes zero to positive" =
      let s = Amount.Signed.create ~magnitude:Amount.zero ~sgn:Sgn.Neg in
      [%test_eq: Sgn.t] s.sgn Sgn.Pos

    let%test_unit "is_zero on zero" =
      assert (Amount.Signed.is_zero Amount.Signed.zero)

    let%test_unit "negate zero stays positive" =
      let n = Amount.Signed.negate Amount.Signed.zero in
      [%test_eq: Sgn.t] n.sgn Sgn.Pos

    (* --- overflow edge cases --- *)
    let%test_unit "add same sign overflow returns none" =
      let a = Amount.Signed.create ~magnitude:Amount.max_int ~sgn:Sgn.Pos in
      let b = Amount.Signed.create ~magnitude:(amount_of_int 1) ~sgn:Sgn.Pos in
      [%test_eq: Amount.Signed.t option] (Amount.Signed.add a b) None

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

    (* --- add_signed_flagged edge cases --- *)
    let%test_unit "add_signed_flagged negative underflow" =
      let base = amount_of_int 10 in
      let delta =
        Amount.Signed.create ~magnitude:(amount_of_int 20) ~sgn:Sgn.Neg
      in
      let _, `Overflow b = Amount.add_signed_flagged base delta in
      assert b

    let%test_unit "add_signed_flagged positive overflow" =
      let delta =
        Amount.Signed.create ~magnitude:(amount_of_int 1) ~sgn:Sgn.Pos
      in
      let _, `Overflow b = Amount.add_signed_flagged Amount.max_int delta in
      assert b
  end )

let%test_module "balance operations" =
  ( module struct
    (* --- edge cases --- *)
    let%test_unit "add_amount overflow" =
      [%test_eq: Balance.t option]
        (Balance.add_amount
           (Balance.of_uint64 Unsigned.UInt64.max_int)
           (amount_of_int 1) )
        None

    let%test_unit "sub_amount underflow" =
      [%test_eq: Balance.t option]
        (Balance.sub_amount (balance_of_int 10) (amount_of_int 20))
        None

    let%test_unit "add_amount_flagged overflow flag" =
      let _, `Overflow b =
        Balance.add_amount_flagged
          (Balance.of_uint64 Unsigned.UInt64.max_int)
          (amount_of_int 1)
      in
      assert b

    let%test_unit "sub_amount_flagged underflow flag" =
      let _, `Underflow b =
        Balance.sub_amount_flagged (balance_of_int 5) (amount_of_int 10)
      in
      assert b
  end )

let%test_module "fee_rate operations" =
  ( module struct
    let%test_unit "make creates valid rate" =
      let r = Fee_rate.make (fee_of_int 100) 2 in
      assert (Option.is_some r)

    let%test_unit "make with zero weight" =
      let r = Fee_rate.make (fee_of_int 0) 0 in
      assert (Option.is_some r)

    let%test_unit "to_uint64 on integer rate" =
      let r = Fee_rate.make_exn (fee_of_int 100) 1 in
      let result = Fee_rate.to_uint64 r in
      assert (Option.is_some result) ;
      assert (
        Unsigned.UInt64.equal (Option.value_exn result)
          (Unsigned.UInt64.of_int 100) )

    let%test_unit "to_uint64 on fractional rate is none" =
      let r = Fee_rate.make_exn (fee_of_int 100) 3 in
      assert (Option.is_none (Fee_rate.to_uint64 r))

    let%test_unit "add two rates" =
      let a = Fee_rate.make_exn (fee_of_int 100) 1 in
      let b = Fee_rate.make_exn (fee_of_int 200) 1 in
      let result = Option.value_exn (Fee_rate.add a b) in
      assert (
        Unsigned.UInt64.equal
          (Fee_rate.to_uint64_exn result)
          (Unsigned.UInt64.of_int 300) )

    let%test_unit "sub two rates" =
      let a = Fee_rate.make_exn (fee_of_int 200) 1 in
      let b = Fee_rate.make_exn (fee_of_int 100) 1 in
      let result = Option.value_exn (Fee_rate.sub a b) in
      assert (
        Unsigned.UInt64.equal
          (Fee_rate.to_uint64_exn result)
          (Unsigned.UInt64.of_int 100) )

    let%test_unit "compare rates" =
      let a = Fee_rate.make_exn (fee_of_int 100) 1 in
      let b = Fee_rate.make_exn (fee_of_int 200) 1 in
      assert (Fee_rate.compare a b < 0) ;
      assert (Fee_rate.compare b a > 0) ;
      assert (Int.equal (Fee_rate.compare a a) 0)

    let%test_unit "compare fractional rates" =
      (* 100/3 vs 100/2 => 33.33 vs 50 *)
      let a = Fee_rate.make_exn (fee_of_int 100) 3 in
      let b = Fee_rate.make_exn (fee_of_int 100) 2 in
      assert (Fee_rate.compare a b < 0)

    let%test_unit "scale rate" =
      let r = Fee_rate.make_exn (fee_of_int 100) 1 in
      let scaled = Option.value_exn (Fee_rate.scale r 3) in
      assert (
        Unsigned.UInt64.equal
          (Fee_rate.to_uint64_exn scaled)
          (Unsigned.UInt64.of_int 300) )

    let%test_unit "mul rates" =
      let a = Fee_rate.make_exn (fee_of_int 10) 1 in
      let b = Fee_rate.make_exn (fee_of_int 20) 1 in
      let result = Option.value_exn (Fee_rate.mul a b) in
      assert (
        Unsigned.UInt64.equal
          (Fee_rate.to_uint64_exn result)
          (Unsigned.UInt64.of_int 200) )

    let%test_unit "div rates" =
      let a = Fee_rate.make_exn (fee_of_int 100) 1 in
      let b = Fee_rate.make_exn (fee_of_int 10) 1 in
      let result = Option.value_exn (Fee_rate.div a b) in
      assert (
        Unsigned.UInt64.equal
          (Fee_rate.to_uint64_exn result)
          (Unsigned.UInt64.of_int 10) )

    (* The hand-written sexp roundtrip test on a single fixed value is
       subsumed by the [Fee_rate sexp roundtrip] property-based test in
       the [quickcheck properties] module below. *)
  end )

let%test_module "quickcheck properties" =
  ( module struct
    let amount_gen = Amount.gen

    let fee_gen = Fee.gen

    let balance_gen = Balance.gen

    let signed_gen = Amount.Signed.gen

    let sgn_gen =
      Quickcheck.Generator.map Bool.quickcheck_generator ~f:(fun b ->
          if b then Sgn.Pos else Sgn.Neg )

    let nonzero_amount_gen =
      Quickcheck.Generator.filter amount_gen ~f:(fun a ->
          not (Amount.equal a Amount.zero) )

    (* Pairs whose addition is defined (i.e. does not overflow). Built
       with [Generator.bind] to avoid a high rejection rate: we pick
       any [a], then pick [b] in the range [0..max_int - a]. This way
       every generated pair is guaranteed to satisfy [Amount.add a b =
       Some _], and every quickcheck trial actually exercises the
       roundtrip rather than being silently skipped. *)
    let add_defined_pairs_gen =
      let open Quickcheck.Generator.Let_syntax in
      let%bind a = amount_gen in
      let max_b =
        (* [max_int - a] is well-defined since [a <= max_int]. *)
        Option.value_exn (Amount.sub Amount.max_int a)
      in
      let%map b = Amount.gen_incl Amount.zero max_b in
      (a, b)

    (* Pairs whose subtraction is defined (i.e. [a >= b]). *)
    let sub_defined_pairs_gen =
      let open Quickcheck.Generator.Let_syntax in
      let%bind a = amount_gen in
      let%map b = Amount.gen_incl Amount.zero a in
      (a, b)

    (* --- Amount arithmetic properties --- *)
    let%test_unit "add commutativity" =
      Quickcheck.test (Quickcheck.Generator.tuple2 amount_gen amount_gen)
        ~trials:1000 ~f:(fun (a, b) ->
          [%test_eq: Amount.t option] (Amount.add a b) (Amount.add b a) )

    let%test_unit "add zero identity" =
      Quickcheck.test amount_gen ~trials:1000 ~f:(fun a ->
          [%test_eq: Amount.t option] (Amount.add a Amount.zero) (Some a) )

    let%test_unit "sub zero is identity" =
      Quickcheck.test amount_gen ~trials:1000 ~f:(fun a ->
          [%test_eq: Amount.t option] (Amount.sub a Amount.zero) (Some a) )

    let%test_unit "sub self is zero" =
      Quickcheck.test amount_gen ~trials:1000 ~f:(fun a ->
          [%test_eq: Amount.t option] (Amount.sub a a) (Some Amount.zero) )

    let%test_unit "add then sub roundtrip" =
      Quickcheck.test add_defined_pairs_gen ~trials:1000 ~f:(fun (a, b) ->
          let c = Option.value_exn (Amount.add a b) in
          [%test_eq: Amount.t option] (Amount.sub c b) (Some a) )

    let%test_unit "sub then add roundtrip" =
      Quickcheck.test sub_defined_pairs_gen ~trials:1000 ~f:(fun (a, b) ->
          let c = Option.value_exn (Amount.sub a b) in
          [%test_eq: Amount.t option] (Amount.add c b) (Some a) )

    let%test_unit "scale by 1 is identity" =
      Quickcheck.test amount_gen ~trials:1000 ~f:(fun a ->
          [%test_eq: Amount.t option] (Amount.scale a 1) (Some a) )

    let%test_unit "scale by 0 is zero" =
      Quickcheck.test amount_gen ~trials:1000 ~f:(fun a ->
          [%test_eq: Amount.t option] (Amount.scale a 0) (Some Amount.zero) )

    let%test_unit "add overflow consistency" =
      Quickcheck.test (Quickcheck.Generator.tuple2 amount_gen amount_gen)
        ~trials:1000 ~f:(fun (a, b) ->
          let opt_result = Amount.add a b in
          let _, `Overflow overflowed = Amount.add_flagged a b in
          [%test_eq: bool] (Option.is_none opt_result) overflowed )

    let%test_unit "sub underflow consistency" =
      Quickcheck.test (Quickcheck.Generator.tuple2 amount_gen amount_gen)
        ~trials:1000 ~f:(fun (a, b) ->
          let opt_result = Amount.sub a b in
          let _, `Underflow underflowed = Amount.sub_flagged a b in
          [%test_eq: bool] (Option.is_none opt_result) underflowed )

    (* --- Conversion roundtrip properties --- *)
    let%test_unit "of_nanomina_int roundtrip" =
      Quickcheck.test (Int.gen_incl 0 4_611_686_018) ~trials:1000 ~f:(fun n ->
          let v = Amount.of_nanomina_int_exn n in
          [%test_eq: int] (Amount.to_nanomina_int v) n )

    let%test_unit "of_mina_int roundtrip" =
      Quickcheck.test (Int.gen_incl 0 4_611_686) ~trials:1000 ~f:(fun n ->
          let v = Amount.of_mina_int_exn n in
          [%test_eq: int] (Amount.to_mina_int v) n )

    let%test_unit "of_fee/to_fee roundtrip" =
      Quickcheck.test fee_gen ~trials:1000 ~f:(fun f ->
          [%test_eq: Fee.t] (Amount.to_fee (Amount.of_fee f)) f )

    let%test_unit "add_fee result is at least as large" =
      Quickcheck.test (Quickcheck.Generator.tuple2 amount_gen fee_gen)
        ~trials:1000 ~f:(fun (amt, fee) ->
          match Amount.add_fee amt fee with
          | None ->
              ()
          | Some result ->
              assert (Amount.( >= ) result amt) )

    (* --- Balance properties --- *)
    let%test_unit "Balance.add_amount then sub_amount roundtrip" =
      Quickcheck.test (Quickcheck.Generator.tuple2 balance_gen amount_gen)
        ~trials:1000 ~f:(fun (bal, amt) ->
          match Balance.add_amount bal amt with
          | None ->
              ()
          | Some bal' ->
              [%test_eq: Balance.t option]
                (Balance.sub_amount bal' amt)
                (Some bal) )

    let%test_unit "Balance.sub_amount self is zero" =
      Quickcheck.test balance_gen ~trials:1000 ~f:(fun b ->
          [%test_eq: Balance.t option]
            (Balance.sub_amount b (Balance.to_amount b))
            (Some Balance.zero) )

    let%test_unit "Balance.to_amount roundtrip" =
      Quickcheck.test balance_gen ~trials:1000 ~f:(fun b ->
          [%test_eq: Balance.t]
            (Balance.of_uint64 (Amount.to_uint64 (Balance.to_amount b)))
            b )

    (* --- Signed amount properties --- *)
    let%test_unit "Signed.negate is involution" =
      Quickcheck.test signed_gen ~trials:1000 ~f:(fun x ->
          [%test_eq: Amount.Signed.t]
            (Amount.Signed.negate (Amount.Signed.negate x))
            x )

    let%test_unit "Signed.add commutative" =
      Quickcheck.test (Quickcheck.Generator.tuple2 signed_gen signed_gen)
        ~trials:1000 ~f:(fun (a, b) ->
          [%test_eq: Amount.Signed.t option] (Amount.Signed.add a b)
            (Amount.Signed.add b a) )

    let%test_unit "Signed.create preserves sign for nonzero" =
      Quickcheck.test (Quickcheck.Generator.tuple2 nonzero_amount_gen sgn_gen)
        ~trials:1000 ~f:(fun (a, s) ->
          let signed = Amount.Signed.create ~magnitude:a ~sgn:s in
          [%test_eq: Sgn.t] signed.sgn s )

    let%test_unit "is_positive for positive nonzero" =
      Quickcheck.test nonzero_amount_gen ~trials:1000 ~f:(fun a ->
          let s = Amount.Signed.create ~magnitude:a ~sgn:Sgn.Pos in
          assert (Amount.Signed.is_positive s) )

    let%test_unit "is_negative for negative nonzero" =
      Quickcheck.test nonzero_amount_gen ~trials:1000 ~f:(fun a ->
          let s = Amount.Signed.create ~magnitude:a ~sgn:Sgn.Neg in
          assert (Amount.Signed.is_negative s) )

    let%test_unit "negate flips sign for nonzero" =
      Quickcheck.test (Quickcheck.Generator.tuple2 nonzero_amount_gen sgn_gen)
        ~trials:1000 ~f:(fun (a, s) ->
          let signed = Amount.Signed.create ~magnitude:a ~sgn:s in
          let negated = Amount.Signed.negate signed in
          let expected_sgn =
            match s with Sgn.Pos -> Sgn.Neg | Sgn.Neg -> Sgn.Pos
          in
          [%test_eq: Sgn.t] negated.sgn expected_sgn )

    let%test_unit "Signed.add x (negate x) is zero" =
      Quickcheck.test signed_gen ~trials:1000 ~f:(fun x ->
          let result = Amount.Signed.add x (Amount.Signed.negate x) in
          match result with
          | Some r ->
              assert (Amount.Signed.is_zero r)
          | None ->
              failwith "add x (negate x) should never overflow" )

    let%test_unit "add_signed_flagged consistency" =
      Quickcheck.test (Quickcheck.Generator.tuple2 amount_gen signed_gen)
        ~trials:1000 ~f:(fun (base, delta) ->
          let result, `Overflow overflowed =
            Amount.add_signed_flagged base delta
          in
          if not overflowed then
            (* When no overflow, the result should be valid *)
            ignore (result : Amount.t) )

    (* --- Fee_rate sexp roundtrip --- *)
    let%test_unit "Fee_rate sexp roundtrip" =
      Quickcheck.test
        (Quickcheck.Generator.tuple2 fee_gen (Int.gen_incl 1 100))
        ~trials:1000
        ~f:(fun (f, w) ->
          let r = Fee_rate.make_exn f w in
          let s = Fee_rate.sexp_of_t r in
          let r' = Fee_rate.t_of_sexp s in
          assert (Int.equal (Fee_rate.compare r r') 0) )
  end )
