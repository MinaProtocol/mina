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

module Intf (F : sig
  type t
end) =
struct
  module type S = sig
    val to_group : F.t -> F.t * F.t
  end
end


module Make
    (Constant : Field_intf.S) (F : sig
        include Field_intf.S
        val random_element : unit -> t
        val constant : Constant.t -> t
    end) (Params : sig
      val a : F.t
      val b : F.t
    end) =
struct
  open Params
  open F

let rec gen_u () =
  let u = random_element () in
  let curve_eqn u = (u*u + a*u + b) in
  if not F.((of_int 3)/(of_int 4)*u*u + Params.a = zero) && not F.(curve_eqn u = zero) then u
  else gen_u () (* from (15), A = 0, B = a *)

let to_point u v ~lambda =
  let cu = (of_int 3)/(of_int 4)*u*u + Params.a in (* from (15), A = 0, B = a *)
  let du = y*y * (u*u + u*v + v*v + Params.a) in (* from (12), A = 0, B = a *)
  let z = y*(v + u/2) in
  let t = -(z + cu*y) + sqrt ((z + cu* ~lambda*y)*(z + cu* ~lambda*y)
  - (one + cu* ~lambda* ~lambda)*(z*z + cu*y*y - du)) / (one + cu* ~lambda* ~lambda)

(* (16) : φ(λ) : F →  S : λ → ( u, α(λ)/β(λ) - u/2, β(λ) ) *)
let phi lambda =
  (* generate (z0, y0) *)
  let (z, y) = random_point () in
  (* get (alpha, beta) = (z1, y1) *)
  let (alpha, beta) = to_point ~z ~y ~lambda in
  (u, alpha/beta - u/2, beta)

 (* φ1: (u, v, y) →  ( v, −u − v, u + y^2,
 *                  f(u + y^2)·(y^2 + uv + v^2 + ay)/y ) *)
let phi_1 (u, v, y) =
  (v, -u-v, u + y*y, f_eqn (u + y*y) * (y*y + u*v + v*v + Params.a*y)/y)

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
  let a = Params.a params in
  let b = Params.b params in
  let u = phi t in
  let v = phi_1 u in
  let try_decode x =
    let f x = F.((x * x * x) + (a * x) + b) in
    let y = f x in
    if F.is_square y then Some (x, F.sqrt y) else None
  in
  let x1, x2, x3 = M.potential_xs v in
  List.find_map [x1; x2; x3] ~f:try_decode |> Option.value_exn

end
