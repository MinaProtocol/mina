open Core_kernel
open Import
module SC = Pickles_types.Scalar_challenge

(* Implementation of the algorithm described on page 29 of the Halo paper
   https://eprint.iacr.org/2019/1021.pdf
*)

let to_field_checked (type f)
    (module Impl : Snarky_backendless.Snark_intf.Run with type field = f) ~endo
    (SC.Scalar_challenge bits) =
  let bits = Array.of_list bits in
  let module F = Impl.Field in
  let two = F.Constant.of_int 2 in
  let a = ref (F.of_int 2) in
  let b = ref (F.of_int 2) in
  let one = F.of_int 1 in
  let neg_one = F.(of_int 0 - one) in
  for i = (128 / 2) - 1 downto 0 do
    let s = F.if_ bits.(2 * i) ~then_:one ~else_:neg_one in
    (a := F.(scale !a two)) ;
    (b := F.(scale !b two)) ;
    let r_2i1 = bits.((2 * i) + 1) in
    a := F.if_ r_2i1 ~then_:F.(!a + s) ~else_:!a ;
    b := F.if_ r_2i1 ~then_:!b ~else_:F.(!b + s)
  done ;
  F.(scale !a endo + !b)

let to_field_constant (type f) ~endo
    (module F : Marlin_checks.Field_intf with type t = f)
    (SC.Scalar_challenge c) =
  let bits = Array.of_list (Challenge.Constant.to_bits c) in
  let a = ref (F.of_int 2) in
  let b = ref (F.of_int 2) in
  let one = F.of_int 1 in
  let neg_one = F.(of_int 0 - one) in
  for i = (128 / 2) - 1 downto 0 do
    let s = if bits.(2 * i) then one else neg_one in
    (a := F.(!a + !a)) ;
    (b := F.(!b + !b)) ;
    let r_2i1 = bits.((2 * i) + 1) in
    if r_2i1 then a := F.(!a + s) else b := F.(!b + s)
  done ;
  F.((!a * endo) + !b)

module Make
    (Impl : Snarky_backendless.Snark_intf.Run)
    (G : Intf.Group(Impl).S with type t = Impl.Field.t * Impl.Field.t)
    (Challenge : Challenge.S with module Impl := Impl) (Endo : sig
        val base : Impl.Field.Constant.t

        val scalar : G.Constant.Scalar.t
    end) =
struct
  open Impl
  module Scalar = G.Constant.Scalar

  type t = Challenge.t SC.t

  module Constant = struct
    type t = Challenge.Constant.t SC.t

    let to_field = to_field_constant ~endo:Endo.scalar (module Scalar)
  end

  let typ : (t, Constant.t) Typ.t = SC.typ Challenge.typ

  (* TODO-someday: Combine this and the identical definition in the
     snarky_curve library.
  *)
  (* b ? t : -t *)
  let conditional_negation (b : Boolean.var) (x, y) =
    let y' =
      exists Field.typ
        ~compute:
          As_prover.(
            fun () ->
              if read Boolean.typ b then read Field.typ y
              else Field.Constant.negate (read Field.typ y))
    in
    assert_r1cs y Field.((of_int 2 * (b :> Field.t)) - of_int 1) y' ;
    (x, y')

  (* TODO-someday: Combine this and the identical definition in the
     snarky_curve library.
  *)
  let p_plus_q_plus_p (x1, y1) (x2, y2) =
    let open Field in
    let ( ! ) = As_prover.read typ in
    let lambda_1 =
      exists typ ~compute:Constant.(fun () -> (!y2 - !y1) / (!x2 - !x1))
    in
    let x3 =
      exists typ
        ~compute:Constant.(fun () -> (!lambda_1 * !lambda_1) - !x1 - !x2)
    in
    let lambda_2 =
      exists typ
        ~compute:
          Constant.(fun () -> (of_int 2 * !y1 / (!x1 - !x3)) - !lambda_1)
    in
    let x4 =
      exists typ
        ~compute:Constant.(fun () -> (!lambda_2 * !lambda_2) - !x3 - !x1)
    in
    let y4 =
      exists typ ~compute:Constant.(fun () -> ((!x1 - !x4) * !lambda_2) - !y1)
    in
    (* Determines lambda_1 *)
    assert_r1cs (x2 - x1) lambda_1 (y2 - y1) ;
    (* Determines x_3 *)
    assert_square lambda_1 (x1 + x2 + x3) ;
    (* Determines lambda_2 *)
    assert_r1cs (x1 - x3) (lambda_1 + lambda_2) (of_int 2 * y1) ;
    (* Determines x4 *)
    assert_square lambda_2 (x3 + x1 + x4) ;
    (* Determines y4 *)
    assert_r1cs (x1 - x4) lambda_2 (y4 + y1) ;
    (x4, y4)

  let endo p (SC.Scalar_challenge bits) =
    let bits = Array.of_list bits in
    let n = Array.length bits in
    assert (n = 128) ;
    let rec go acc i =
      if i < 0 then acc
      else
        let x, y = conditional_negation bits.(2 * i) p in
        let b_2i1 = bits.((2 * i) + 1) in
        let sx =
          exists Field.typ
            ~compute:
              As_prover.(
                fun () ->
                  if read Boolean.typ b_2i1 then
                    Field.Constant.(Endo.base * read_var x)
                  else read_var x)
        in
        (* TODO: Play around with this constraint and see how it affects
           performance.
           E.g., try sx = (1 + (endo - 1) * bits.(2*i + 1)) * x
        *)
        Field.(
          (* (endo - 1) * bits.(2*i + 1) * x = sx - x *)
          assert_r1cs
            (scale (b_2i1 :> t) Constant.(Endo.base - one) + one)
            x sx) ;
        go (p_plus_q_plus_p acc (sx, y)) (i - 1)
    in
    let phi (x, y) = (Field.scale x Endo.base, y) in
    go (G.double (G.( + ) (phi p) p)) ((n / 2) - 1)

  let endo_inv ((gx, gy) as g) chal =
    let res =
      exists G.typ
        ~compute:
          As_prover.(
            fun () ->
              let x = Constant.to_field (read typ chal) in
              G.Constant.scale (read G.typ g) Scalar.(one / x))
    in
    let x, y = endo res chal in
    Field.Assert.(equal gx x ; equal gy y) ;
    res
end
