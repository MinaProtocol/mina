(* we have φ(t) : F -> S
 * and φ1(λ) : S -> V with
 * V(F) : f(x1)f(x2)f(x3) = x4^2,
 * (f is y^2 = x^3 + Bx + C)) (note choice of constant names
 * -- A is coeff of x^2 so A = 0 for us)
 *
 * To construct a rational point on V(F), the authors define
 * the surface S(F) and the rational map φ1:S(F)→ V(F), which
 * is invertible on its image [SvdW06, Lemma 6]:
 * S(F) : y^2(u^2 + uv + v^2 + a) = −f(u)
 *
 * φ(t) : t → ( u, α(t)/β(t) - u/2, β(t) )
 * φ1: (u, v, y) →  ( v, −u − v, u + y^2,
 *                  f(u + y^2)·(y^2 + uv + v^2 + ay)/y )
 *)

open Core_kernel
module Field_intf = Field_intf

let ( = ) = `Don't_use_polymorphic_compare

let _ = ( = )

module Intf (F : sig
  type t
end) =
struct
  module type S = sig
    val to_group : F.t -> F.t * F.t
  end
end

module Conic = struct
  type 'f t = {z: 'f; y: 'f}
end

module S = struct
  (* S = S(u, v, y) : y^2(u^2 + uv + v^2 + a) = −f(u)
     from (12)
  *)
  type 'f t = {u: 'f; v: 'f; y: 'f}
end

module V = struct
  (* V = V(x1, x2, x3, x4) : f(x1)f(x2)f(x3) = x4^2
     from (8)
  *)
  type 'f t = 'f * 'f * 'f * 'f
end

module Params = struct
  type 'f t = {u: 'f; projection_point: 'f Conic.t; conic_c: 'f; a: 'f; b: 'f}
  [@@deriving fields]

  let create (type t) (module F : Field_intf.S_unchecked with type t = t) ~a ~b
      =
    let open F in
    let first_map f =
      let rec go i = match f i with Some x -> x | None -> go (i + one) in
      go zero
    in
    let first f = first_map (fun x -> Option.some_if (f x) x) in
    let three_fourths = of_int 3 / of_int 4 in
    let curve_eqn u = (u * u * u) + (a * u) + b in
    let u =
      first (fun u ->
          (* from (15), A = 0, B = Params.a *)
          let check = (three_fourths * u * u) + a in
          let fu = curve_eqn u in
          (not (equal check zero))
          && (not (equal fu zero))
          && not (is_square (negate fu))
          (* imeckler: I added this condition. It prevents the possibility of having
   a point (z, 0) on the conic, which is useful because in the map from the
   conic to S we divide by the "y" coordinate of the conic. It's not strictly
   necessary when we have a random input in a large field, but it is still nice to avoid the 
   bad case in theory (and for the tests below with a small field). *)
      )
    in
    (* The coefficients defining the conic z^2 + c y^2 = d
       in (15). *)
    let conic_c = (three_fourths * u * u) + a in
    let conic_d = negate (curve_eqn u) in
    let projection_point =
      first_map (fun y ->
          let z2 = conic_d - (conic_c * y * y) in
          if F.is_square z2 then Some {Conic.z= F.sqrt z2; y} else None )
    in
    {u; conic_c; projection_point; a; b}
end

module Make
    (Constant : Field_intf.S) (F : sig
        include Field_intf.S

        val constant : Constant.t -> t
    end) (P : sig
      val params : Constant.t Params.t
    end) =
struct
  open F

  (* For a curve z^2 + c y^2 = d and a point (z0, y0) on the curve, there
     is one other point on the curve which is also on the line through (z0, y0)
     with slope t. This function returns that point. *)
  let field_to_conic t =
    let z0, y0 =
      ( constant P.params.projection_point.z
      , constant P.params.projection_point.y )
    in
    let ct = constant P.params.conic_c * t in
    let s = of_int 2 * ((ct * y0) + z0) / ((ct * t) + one) in
    let c = {Conic.z= z0 - s; y= y0 - (s * t)} in
    c

  let u_over_2 = lazy Constant.(P.params.u / of_int 2)

  (* (16) : φ(λ) : F →  S : λ → ( u, α(λ)/β(λ) - u/2, β(λ) ) *)
  let field_to_s t =
    let {Conic.z; y} = field_to_conic t in
    { S.u= constant P.params.u
    ; v= (z / y) - constant (Lazy.force u_over_2) (* From (16) *)
    ; y }

  (* This is here for explanatory purposes. See s_to_v_truncated. *)
  let _s_to_v {S.u; v; y} : _ V.t =
    let curve_eqn x =
      (x * x * x) + (constant P.params.a * x) + constant P.params.b
    in
    let h = (u * u) + (u * v) + (v * v) + constant P.params.a in
    (v, negate (u + v), u + (y * y), curve_eqn (u + (y * y)) * h / y)

  (* from (13) *)

  (* We don't actually need to compute the final coordinate in V *)
  let s_to_v_truncated {S.u; v; y} = (v, negate (u + v), u + (y * y))

  let potential_xs t = s_to_v_truncated (field_to_s t)
end

let to_group (type t) (module F : Field_intf.S_unchecked with type t = t)
    ~params t =
  let module M =
    Make
      (F)
      (struct
        include F

        let constant = Fn.id
      end)
      (struct
        let params = params
      end)
  in
  let a = params.a in
  let b = params.b in
  let try_decode x =
    let f x = F.((x * x * x) + (a * x) + b) in
    let y = f x in
    if F.is_square y then Some (x, F.sqrt y) else None
  in
  let x1, x2, x3 = M.potential_xs t in
  List.find_map [x1; x2; x3] ~f:try_decode |> Option.value_exn

let%test_module "test" =
  ( module struct
    module F = struct
      type t = int [@@deriving sexp]

      let p = 13

      let ( + ) x y = (x + y) mod p

      let ( * ) x y = x * y mod p

      let negate x = (p - x) mod p

      let ( - ) x y = (x - y + p) mod p

      let equal = Int.equal

      let ( / ) x y =
        let rec go i = if equal x (i * y) then i else go (i + 1) in
        if equal y 0 then failwith "Divide by 0" else go 1

      let sqrt' x =
        let rec go i =
          if Int.equal i p then None
          else if equal (i * i) x then Some i
          else go Int.(i + 1)
        in
        go 0

      let sqrt x = Option.value_exn (sqrt' x)

      let is_square x = Option.is_some (sqrt' x)

      let zero = 0

      let one = 1

      let of_int = Fn.id

      let constant = Fn.id

      let gen = Int.gen_incl 0 Int.(p - 1)
    end

    let a = 1

    let b = 3

    let params = Params.create (module F) ~a ~b

    let curve_eqn u = (u * u * u) + (params.a * u) + params.b

    let conic_d =
      let open F in
      negate (curve_eqn params.u)

    let on_conic {Conic.z; y} =
      F.(equal ((z * z) + (params.conic_c * y * y)) conic_d)

    module M =
      Make (F) (F)
        (struct
          let params = params
        end)

    let%test "projection point well-formed" = on_conic params.projection_point

    let gen =
      Quickcheck.Generator.filter F.gen ~f:(fun t ->
          not F.(equal ((params.conic_c * t * t) + one) zero) )

    let%test_unit "field-to-conic" =
      Quickcheck.test ~sexp_of:F.sexp_of_t gen ~f:(fun t ->
          assert (on_conic (M.field_to_conic t)) )

    let on_s {S.u; v; y} =
      F.(equal conic_d (y * y * ((u * u) + (u * v) + (v * v) + a)))

    let%test_unit "field-to-S" =
      Quickcheck.test ~sexp_of:F.sexp_of_t gen ~f:(fun t ->
          assert (on_s (M.field_to_s t)) )

    let on_v (x1, x2, x3, x4) =
      F.(equal (curve_eqn x1 * curve_eqn x2 * curve_eqn x3) (x4 * x4))

    let%test_unit "field-to-S" =
      Quickcheck.test ~sexp_of:F.sexp_of_t gen ~f:(fun t ->
          let s = M.field_to_s t in
          assert (on_v (M._s_to_v s)) )
  end )
