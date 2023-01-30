open Core
open Mina_transaction_logic
open Currency_amount

let rec gen_signed (sign : Sgn.t) =
  let open Quickcheck.Generator.Let_syntax in
  let%bind magn = Currency.Amount.gen in
  (* We don't consider 0 positive or negative, so try again. *)
  if Currency.Amount.(magn = zero) then gen_signed sign
  else return Currency.Signed_poly.{ magnitude = magn; sgn = sign }

let xor a b = not Bool.(a = b)

(* We're only testing the functionality added in this library. Functions
   imported from Currency package should be tested there. *)
let%test_module "Signed currency amount" =
  ( module struct
    let%test "Zero is neither positive nor negative." =
      let open Signed in
      (not (is_neg zero)) && not (is_pos zero)

    let%test_unit "Positive and negative values cancel out." =
      Quickcheck.test Currency.Amount.gen ~f:(fun c ->
          [%test_eq: t]
            (fst @@ add_signed_flagged c Signed.(negate @@ of_unsigned c))
            zero )

    let%test_unit "add_signed_flagged is commutative." =
      Quickcheck.test
        Quickcheck.Generator.(both Currency.Amount.gen Currency.Amount.gen)
        ~f:(fun (a, b) ->
          [%test_eq: t]
            (fst @@ add_signed_flagged a @@ Signed.of_unsigned b)
            (fst @@ add_signed_flagged b @@ Signed.of_unsigned a) )

    let%test_unit "Zero is neutral element of add_signed_flagged." =
      Quickcheck.test Currency.Amount.gen ~f:(fun c ->
          [%test_eq: t] (fst @@ add_signed_flagged c Signed.zero) c )

    let%test_unit "Adding posiitive value increases result." =
      Quickcheck.test
        Quickcheck.Generator.(both Currency.Amount.gen (gen_signed Pos))
        ~f:(fun (a, b) ->
          [%test_pred: t * [ `Overflow of bool ]]
            (fun (c, `Overflow overflow) -> xor overflow Currency.Amount.(c > a))
            (add_signed_flagged a b) )

    let%test_unit "Adding posiitive value decreases result." =
      Quickcheck.test
        Quickcheck.Generator.(both Currency.Amount.gen (gen_signed Neg))
        ~f:(fun (a, b) ->
          [%test_pred: t * [ `Overflow of bool ]]
            (fun (c, `Overflow overflow) -> xor overflow Currency.Amount.(c < a))
            (add_signed_flagged a b) )
  end )
