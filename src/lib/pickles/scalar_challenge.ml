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
  let two =
    (* Hack for plonk constraints *)
    let x = Impl.exists F.typ ~compute:(fun () -> F.Constant.of_int 2) in
    F.Assert.equal x (F.of_int 2) ;
    x
  in
  let a = ref two in
  let b = ref two in
  let one = F.Constant.one in
  let neg_one = F.Constant.(negate one) in
  let zero = F.Constant.zero in
  for i = (128 / 2) - 1 downto 0 do
    (* s = -1 + 2 * r_2i
       a_next = 
        if r_2i1 
        then 2 a_prev + s
        else 2 a_prev
       =
       2 a_prev + r_2i1 * s
       =
       2 a_prev + r_2i1 * (-1 + 2 r_2i)
       <->
       0 = 2 a_prev + r_2i1 * (-1 + 2 r_2i) - a_next
       <->
       0 = 2 a_prev - r_2i1 + 2 r_2i1 r_2i - a_next
       <->
       two_a_prev_minus_a_next = 2 a_prev - a_next
       &&
       0 = - r_2i1 + 2 r_2i1 r_2i + two_a_prev_minus_a_next

       b_next =
        if r_2i1
        then 2 b_prev
        else 2 b_prev + s
       =
       2 b_prev + (1 - r_2i1) * s
       =
       2 b_prev + (1 - r_2i1) * (2 * r_2i - 1)
       =
       2 b_prev - 1 + 2 r_2i + r_2i1 - 2 r_2i1 r_2i
       <->
       0 = 2 b_prev - 1 + 2 r_2i + r_2i1 - 2 r_2i1 r_2i - b_next
       <->
       0 = (2 b_prev - b_next) - 1 + 2 r_2i + r_2i1 - 2 r_2i1 r_2i
       <->
       two_b_prev_minus_b_next = 2 b_prev - b_next
       &&
       0 
       = two_b_prev_minus_b_next - 1 + 2 r_2i + r_2i1 - 2 r_2i1 r_2i
       = 2 r_2i + r_2i1 - 2 r_2i1 r_2i + two_b_prev_minus_b_next + -1 
    *)
    let open Impl in
    let a_next =
      exists Field.typ
        ~compute:
          As_prover.(
            fun () ->
              let s : F.Constant.t =
                if read Boolean.typ bits.(Int.(2 * i)) then F.Constant.one
                else F.Constant.(negate one)
              in
              let a_prev = read_var !a in
              let two_a_prev = F.Constant.(a_prev + a_prev) in
              if read Boolean.typ bits.(Int.((2 * i) + 1)) then
                F.Constant.(two_a_prev + s)
              else two_a_prev)
    in
    let b_next =
      exists Field.typ
        ~compute:
          As_prover.(
            fun () ->
              let s : F.Constant.t =
                if read Boolean.typ bits.(Int.(2 * i)) then F.Constant.one
                else F.Constant.(negate one)
              in
              let b_prev = read_var !b in
              let two_b_prev = F.Constant.(b_prev + b_prev) in
              if read Boolean.typ bits.(Int.((2 * i) + 1)) then two_b_prev
              else F.Constant.(two_b_prev + s))
    in
    let two_a_prev_minus_a_next =
      exists Field.typ
        ~compute:As_prover.(fun () -> read_var F.(!a + !a - a_next))
    in
    let two_b_prev_minus_b_next =
      exists Field.typ
        ~compute:As_prover.(fun () -> read_var F.(!b + !b - b_next))
    in
    let open Zexe_backend_common.Plonk_constraint_system.Plonk_constraint in
    let p l r o m c =
      [ { Snarky_backendless.Constraint.annotation= None
        ; basic= T (Basic {l; r; o; m; c}) } ]
    in
    let two = F.Constant.of_int 2 in
    let r_2i = (bits.(2 * i) :> F.t) in
    let r_2i1 = (bits.((2 * i) + 1) :> F.t) in
    List.iter ~f:assert_
      [ (* 0 = 2 a_prev - a_next - two_a_prev_minus_a_next  *)
        p (two, !a) (neg_one, a_next)
          (neg_one, two_a_prev_minus_a_next)
          zero zero
      ; (* 0 = 2 b_prev - b_next - two_b_prev_minus_b_next  *)
        p (two, !b) (neg_one, b_next)
          (neg_one, two_b_prev_minus_b_next)
          zero zero
        (* 0 = - r_2i1 + 2 r_2i1 r_2i + two_a_prev_minus_a_next *)
      ; p (neg_one, r_2i1) (zero, r_2i) (one, two_a_prev_minus_a_next) two zero
        (* 2 r_2i + r_2i1 - 2 r_2i1 r_2i + two_b_prev_minus_b_next + -1  *)
      ; p (two, r_2i) (one, r_2i1)
          (one, two_b_prev_minus_b_next)
          (F.Constant.negate two) neg_one ] ;
    a := a_next ;
    b := b_next
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
    (Impl : Snarky_backendless.Snark_intf.Run with type prover_state = unit)
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

  let typ_unchecked : (t, Constant.t) Typ.t = SC.typ Challenge.typ_unchecked

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

  let endo (t : Field.t * Field.t) (SC.Scalar_challenge bits) =
    let xt, yt = Tuple_lib.Double.map t ~f:(Util.seal (module Impl)) in
    let bits = Array.of_list bits in
    let n = Array.length bits in
    (*     assert (n = 128) ; *)
    assert (n mod 2 = 0) ;
    let rec go rows (xp, yp) i =
      if i < 0 then (Array.of_list_rev rows, (xp, yp))
      else
        let b2i = bits.(Int.(2 * i)) in
        let b2i1 = bits.(Int.((2 * i) + 1)) in
        let xq =
          exists Field.typ
            ~compute:
              As_prover.(
                fun () ->
                  let xt = read_var xt in
                  if read Boolean.typ b2i1 then Field.Constant.mul Endo.base xt
                  else xt)
        in
        let l1 =
          exists Field.typ
            ~compute:
              As_prover.(
                fun () ->
                  let open Field.Constant in
                  let yt = read_var yt in
                  let xq = read_var xq in
                  let yq = if read Boolean.typ b2i then yt else negate yt in
                  (yq - read_var yp) / (xq - read_var xp))
        in
        let xr =
          As_prover.Ref.create
            As_prover.(
              fun () ->
                (* l1^2 - xp - xq *)
                let open Field.Constant in
                square (read_var l1) - read_var xp - read_var xq)
        in
        let l2 =
          As_prover.Ref.create
            As_prover.(
              fun () ->
                (* 2 yp / (xp - xr) - l1 *)
                let open Field.Constant in
                let yp = read_var yp in
                ((yp + yp) / (read_var xp - As_prover.Ref.get xr))
                - read_var l1)
        in
        let xs =
          exists Field.typ
            ~compute:
              As_prover.(
                fun () ->
                  (* l2^2 - xr - xp *)
                  let open Field.Constant in
                  square (As_prover.Ref.get l2)
                  - As_prover.Ref.get xr - read_var xp)
        in
        let ys =
          exists Field.typ
            ~compute:
              As_prover.(
                fun () ->
                  (* (xp - xs) * l2 - yp *)
                  let open Field.Constant in
                  ((read_var xp - read_var xs) * As_prover.Ref.get l2)
                  - read_var yp)
        in
        let row =
          { Zexe_backend_common.Endoscale_round.b2i1= (b2i1 :> Field.t)
          ; b2i= (b2i :> Field.t)
          ; xt
          ; xq
          ; yt
          ; xp
          ; l1
          ; yp
          ; xs
          ; ys }
        in
        go (row :: rows) (xs, ys) (i - 1)
    in
    with_label __LOC__ (fun () ->
        let phi (x, y) = (Field.scale x Endo.base, y) in
        let t = (xt, yt) in
        let rows, res = go [] (G.double (G.( + ) (phi t) t)) ((n / 2) - 1) in
        assert_
          [ { annotation= Some __LOC__
            ; basic=
                Zexe_backend_common.Plonk_constraint_system.Plonk_constraint.T
                  (EC_endoscale {state= rows}) } ] ;
        res )

  let endo t (SC.Scalar_challenge scalar) =
    let xt, yt = Tuple_lib.Double.map t ~f:(Util.seal (module Impl)) in
    let scalar : Boolean.var array = Array.of_list scalar in
    (*
      Acc := [2](endo(P) + P)
      for i from n/2-1 down to 0:
        let S[i] =
          (
            [2r[2i] - 1]P; if r[2i+1] = 0
            endo[2r[2i] - 1]P; otherwise
          )
        Acc := (Acc + S[i]) + Acc
      return Acc
    *)
    let n = Array.length scalar in
    let n = Int.(if n % 2 = 0 then n / 2 else (n + 1) / 2) in
    let endo = Endo.base in
    let xp, yp = G.double (G.( + ) (Field.scale xt endo, yt) (xt, yt)) in
    let state =
      exists
        (Typ.array ~length:n
           (Zexe_backend_common.Endoscale_round.typ Field.typ))
        ~compute:
          As_prover.(
            fun () ->
              let state = ref [] in
              let xpl, ypl = (ref (read_var xp), ref (read_var yp)) in
              let xtl, ytl = (read_var xt, read_var yt) in
              for i = Int.(n - 1) downto 0 do
                let b2il = read_var (scalar.(Int.(2 * i)) :> Field.t) in
                let b2i1l =
                  Int.(
                    if (2 * i) + 1 < Array.length scalar then
                      read_var (scalar.((2 * i) + 1) :> Field.t)
                    else Field.Constant.zero)
                in
                let xql = (one + ((endo - one) * b2i1l)) * xtl in
                let xsl, ysl =
                  let open G.Constant in
                  of_affine (!xpl, !ypl)
                  + ( of_affine (!xpl, !ypl)
                    + of_affine (xql, Field.Constant.(b2il + b2il - one) * ytl)
                    )
                  |> G.Constant.to_affine_exn
                in
                let round =
                  { Zexe_backend_common.Endoscale_round.b2i1= b2i1l
                  ; xt= xtl
                  ; b2i= b2il
                  ; xq= xql
                  ; yt= ytl
                  ; xp= !xpl
                  ; l1= (!ypl - ((b2il + b2il - one) * ytl)) / (!xpl - xql)
                  ; yp= !ypl
                  ; xs= xsl
                  ; ys= ysl }
                in
                state := !state @ [round] ;
                xpl := xsl ;
                ypl := ysl
              done ;
              Array.of_list !state)
    in
    let state =
      Array.mapi state ~f:(fun i s ->
          { s with
            xt
          ; yt
          ; b2i= (scalar.(Int.(2 * (n - i - 1))) :> Field.t)
          ; b2i1=
              Int.(
                if (2 * (n - i - 1)) + 1 < Array.length scalar then
                  (scalar.((2 * (n - i - 1)) + 1) :> Field.t)
                else Field.zero) } )
    in
    state.(0) <- {(state.(0)) with xp; yp} ;
    assert_
      [ { basic=
            Zexe_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (EC_endoscale {state})
        ; annotation= None } ] ;
    let finish = state.(Int.(n - 1)) in
    (finish.xs, finish.ys)

  let%test_unit "endo" =
    let module T = Internal_Basic in
    let random_point =
      let rec pt x =
        let y2 = G.Params.(T.Field.(b + (x * (a + (x * x))))) in
        if T.Field.is_square y2 then (x, T.Field.sqrt y2)
        else pt T.Field.(x + one)
      in
      G.Constant.of_affine (pt (T.Field.random ()))
    in
    let n = 128 in
    Quickcheck.test ~trials:10
      (Quickcheck.Generator.list_with_length n Bool.quickcheck_generator)
      ~f:(fun xs ->
        try
          T.Test.test_equal ~equal:G.Constant.equal
            ~sexp_of_t:G.Constant.sexp_of_t
            (Typ.tuple2 G.typ (Typ.list ~length:n Boolean.typ))
            G.typ
            (fun (g, s) ->
              make_checked (fun () -> endo g (SC.Scalar_challenge s)) )
            (fun (g, s) ->
              let x =
                Constant.to_field
                  (Scalar_challenge (Challenge.Constant.of_bits s))
              in
              G.Constant.scale g x )
            (random_point, xs)
        with e ->
          Core.eprintf !"Input %{sexp: bool list}\n%!" xs ;
          raise e )

  let endo_inv ((gx, gy) as g) chal =
    let res =
      exists G.typ
        ~compute:
          As_prover.(
            fun () ->
              let x = Constant.to_field (read typ_unchecked chal) in
              G.Constant.scale (read G.typ g) Scalar.(one / x))
    in
    let x, y = endo res chal in
    Field.Assert.(equal gx x ; equal gy y) ;
    res
end
