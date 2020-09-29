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

  let endo (xt, yt) (SC.Scalar_challenge bits) =
    let bits = Array.of_list bits in
    let n = Array.length bits in
    assert (n = 128) ;
    let rec go rows (xp, yp) i =
      if i < 0
      then (Array.of_list_rev rows, (xp, yp))
      else
        let b2i = bits.(Int.(2 * i)) in
        let b2i1 = bits.(Int.(2 * i + 1)) in
        let xq =
          exists Field.typ
            ~compute:As_prover.(fun () ->
                let xt = read_var xt in
                if read Boolean.typ b2i1
                then Field.Constant.mul Endo.base xt
                else xt )
        in
        let l1 =
          exists Field.typ
            ~compute:As_prover.(fun () ->
                let open Field.Constant in
                let yt = read_var yt in
                let xq = read_var xq in
                let yq = if read Boolean.typ b2i then yt else negate yt in
                (yq - read_var yp) / (xq - read_var xp)
              )
        in 
        let xr =
          As_prover.Ref.create As_prover.(fun () ->
              (* B l1^2 - A - xp - xq *)
              let open Field.Constant in
              G.Params.b * read_var l1 - G.Params.a - read_var xp - read_var xq
            )
        in
        let l2 =
          As_prover.Ref.create As_prover.(fun () ->
              (* 2 yp / (xp - xr) - l1 *)
              let open Field.Constant in
              let yp = read_var yp in
              (yp + yp) / (read_var xp - As_prover.Ref.get xr) - read_var l1
          )
        in 
        let xs =
          exists Field.typ ~compute:As_prover.(fun () ->
              (* B l2^2 - A - xr - xp *)
              let open Field.Constant in
              G.Params.b * square (As_prover.Ref.get l2) - G.Params.a - As_prover.Ref.get xr - read_var xp
            )
        in
        let ys =
          exists Field.typ ~compute:As_prover.(fun () ->
              (* (xp - xs) * l2 - yp *)
              let open Field.Constant in
              (read_var xp - read_var xs) * As_prover.Ref.get l2 - read_var yp )
        in
        let row =
          { Zexe_backend_common.Endoscale_round.b2i1= (b2i1 :> Field.t)
          ; b2i = (b2i :> Field.t)
          ; xt
          ; xq
          ; yt
          ; xp
          ; l1
          ; yp
          ; xs
          ; ys
          }
        in 
        go (row :: rows) (xs, ys) (i - 1)
    in 
    with_label __LOC__ (fun () ->
    let phi (x, y) = (Field.scale x Endo.base, y) in
    let t = (xt, yt) in
    let rows, res = go [] (G.double (G.( + ) (phi t) t)) ((n / 2) - 1) in
    assert_ [
      { annotation= Some __LOC__
      ; basic= 
          Zexe_backend_common.Plonk_constraint_system.Plonk_constraint.T
            (EC_endoscale { state= rows })
      }
    ] ;
    res )

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
