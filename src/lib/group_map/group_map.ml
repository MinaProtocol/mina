(*

   This follows the approach of SvdW06 to construct a "near injection" from
   a field into an elliptic curve defined over that field. WB19 is also a useful
   reference that details several constructions which are more appropriate in other
   contexts.

   Fix an elliptic curve E given by y^2 = x^3 + ax + b over a field "F"
   Let f(x) = x^3 + ax + b.

   Define the variety V to be
   (x1, x2, x3, x4) : f(x1) f(x2) f(x3) = x4^2.

   By a not-too-hard we have a map `V -> E`. Thus, a map of type `F -> V` yields a
   map of type `F -> E` by composing.

   Our goal is to construct such a map of type `F -> V`. The paper SvdW06 constructs
   a family of such maps, defined by a collection of values which we'll term `params`.

   Define `params` to be the type of records of the form
    { u: F
    ; u_over_2: F
    ; projection_point: { z : F; y : F }
    ; conic_c: F
    ; a: F
    ; b: F }
   such that
   - a and b are the coefficients of our curve's defining equation.
   - u satisfies
      i. 0 <> 3/4 u^2 + a
      ii. 0 <> f(u)
      iii. -f(u) is not a square.
   - conic_c = 3/4 u^2 + a
   - {z; y} satisfy
      i. z^2 + conic_c * y^2 = -f(u)

   We will define a map of type `params -> (F -> V)`. Thus, fixing a choice of
   a value of type params, we obtain a map `F -> V` as desired.

SvdW06: Shallue and van de Woestijne, "Construction of rational points on elliptic curves over finite fields." Proc. ANTS 2006. https://works.bepress.com/andrew_shallue/1/download/
WB19: Riad S. Wahby and Dan Boneh, Fast and simple constant-time hashing to the BLS12-381 elliptic curve. https://eprint.iacr.org/2019/403
*)

(* we have φ(t) : F -> S
   and φ1(λ) : S -> V with
   V(F) : f(x1)f(x2)f(x3) = x4^2,
   (f is y^2 = x^3 + Bx + C)) (note choice of constant names
   -- A is coeff of x^2 so A = 0 for us)

   To construct a rational point on V(F), the authors define
   the surface S(F) and the rational map φ1:S(F)→ V(F), which
   is invertible on its image [SvdW06, Lemma 6]:
   S(F) : y^2(u^2 + uv + v^2 + a) = −f(u)

   φ(t) : t → ( u, α(t)/β(t) - u/2, β(t) )
   φ1: (u, v, y) →  ( v, −u − v, u + y^2,
                   f(u + y^2)·(y^2 + uv + v^2 + ay)/y )
*)

open Core_kernel
module Field_intf = Field_intf
module Bw19 = Bw19

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

module type S = sig
  module Spec : sig
    type _ t
  end

  module Params : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type _ t [@@deriving bin_io]
      end
    end]

    type 'f t = 'f Stable.Latest.t

    val map : 'a t -> f:('a -> 'b) -> 'b t

    val spec : 'f t -> 'f Spec.t

    val create :
      (module Field_intf.S_unchecked with type t = 'f) -> 'f Spec.t -> 'f t
  end

  module Make
      (Constant : Field_intf.S) (F : sig
          include Field_intf.S

          val constant : Constant.t -> t
      end) (Params : sig
        val params : Constant.t Params.t
      end) : sig
    val potential_xs : F.t -> F.t * F.t * F.t
  end

  val to_group :
       (module Field_intf.S_unchecked with type t = 'f)
    -> params:'f Params.t
    -> 'f
    -> 'f * 'f
end

module Conic = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'f t = {z: 'f; y: 'f}
    end
  end]

  type 'f t = 'f Stable.Latest.t = {z: 'f; y: 'f}

  let map {z; y} ~f = {z= f z; y= f y}
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

module Spec = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'f t = {a: 'f; b: 'f} [@@deriving fields, bin_io, version]
    end
  end]

  include Stable.Latest
end

module Params = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'f t =
        { u: 'f
        ; u_over_2: 'f
        ; projection_point: 'f Conic.Stable.V1.t
        ; conic_c: 'f
        ; spec: 'f Spec.Stable.V1.t }
      [@@deriving fields, version]
    end
  end]

  type 'f t = 'f Stable.Latest.t =
    { u: 'f
    ; u_over_2: 'f
    ; projection_point: 'f Conic.t
    ; conic_c: 'f
    ; spec: 'f Spec.t }
  [@@deriving fields]

  let map {u; u_over_2; projection_point; conic_c; spec= {a; b}} ~f =
    { u= f u
    ; u_over_2= f u_over_2
    ; projection_point= Conic.map ~f projection_point
    ; conic_c= f conic_c
    ; spec= {a= f a; b= f b} }

  (* A deterministic function for constructing a valid choice of parameters for a
     given field.

     We start by finding the first `u` satisfying the constraints described above,
     then find the first `y` satisyfing the condition described above. The other
     values are derived from these two choices*.

     *Actually we have one bit of freedom in choosing `z` as z = sqrt(conic_c y^2 - conic_d),
     since there are two square roots.
  *)

  let create (type t) (module F : Field_intf.S_unchecked with type t = t)
      ({Spec.a; b} as spec) =
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
    {u; u_over_2= u / of_int 2; conic_c; projection_point; spec}
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
    {Conic.z= z0 - s; y= y0 - (s * t)}

  (* From (16) : φ(λ) : F → S : λ → ( u, α(λ)/β(λ) - u/2, β(λ) ) *)
  let conic_to_s {Conic.z; y} =
    { S.u= constant P.params.u
    ; v= (z / y) - constant P.params.u_over_2 (* From (16) *)
    ; y }

  (* This is here for explanatory purposes. See s_to_v_truncated. *)
  let _s_to_v {S.u; v; y} : _ V.t =
    let curve_eqn x =
      (x * x * x) + (constant P.params.spec.a * x) + constant P.params.spec.b
    in
    let h = (u * u) + (u * v) + (v * v) + constant P.params.spec.a in
    (v, negate (u + v), u + (y * y), curve_eqn (u + (y * y)) * h / y)

  (* from (13) *)

  (* We don't actually need to compute the final coordinate in V *)
  let s_to_v_truncated {S.u; v; y} = (v, negate (u + v), u + (y * y))

  let potential_xs =
    let ( @ ) = Fn.compose in
    s_to_v_truncated @ conic_to_s @ field_to_conic
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
  let {Spec.a; b} = params.spec in
  let try_decode x =
    let f x = F.((x * x * x) + (a * x) + b) in
    let y = f x in
    if F.is_square y then Some (x, F.sqrt y) else None
  in
  let x1, x2, x3 = M.potential_xs t in
  List.find_map [x1; x2; x3] ~f:try_decode |> Option.value_exn

let%test_module "test" =
  ( module struct
    module Fp = struct
      include Snarkette.Fields.Make_fp
                (Snarkette.Nat)
                (struct
                  let order = Snarkette.Nat.of_int 100003
                end)

      let a = of_int 1

      let b = of_int 3
    end

    module F13 = struct
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

      let gen = Int.gen_incl 0 Int.(p - 1)

      let a = 1

      let b = 3
    end

    module Make_tests (F : sig
      include Field_intf.S_unchecked

      val gen : t Quickcheck.Generator.t

      val a : t

      val b : t
    end) =
    struct
      module F = struct
        include F

        let constant = Fn.id
      end

      open F

      let params = Params.create (module F) {a; b}

      let curve_eqn u = (u * u * u) + (params.spec.a * u) + params.spec.b

      let conic_d =
        let open F in
        negate (curve_eqn params.u)

      let on_conic {Conic.z; y} =
        F.(equal ((z * z) + (params.conic_c * y * y)) conic_d)

      let on_s {S.u; v; y} =
        F.(equal conic_d (y * y * ((u * u) + (u * v) + (v * v) + a)))

      let on_v (x1, x2, x3, x4) =
        F.(equal (curve_eqn x1 * curve_eqn x2 * curve_eqn x3) (x4 * x4))

      (* Filter the two points which cause the group-map to blow up. This
   is not an issue in practice because the points we feed into this function
   will be the output of blake2s, and thus (modeling blake2s as a random oracle)
   will not be either of those two points. *)
      let gen =
        Quickcheck.Generator.filter F.gen ~f:(fun t ->
            not F.(equal ((params.conic_c * t * t) + one) zero) )

      module M =
        Make (F) (F)
          (struct
            let params = params
          end)

      let%test "projection point well-formed" =
        on_conic params.projection_point

      let%test_unit "field-to-conic" =
        Quickcheck.test ~sexp_of:F.sexp_of_t gen ~f:(fun t ->
            assert (on_conic (M.field_to_conic t)) )

      let%test_unit "conic-to-S" =
        let conic_gen =
          Quickcheck.Generator.filter_map F.gen ~f:(fun y ->
              let z2 = conic_d - (params.conic_c * y * y) in
              if is_square z2 then Some {Conic.z= sqrt z2; y} else None )
        in
        Quickcheck.test conic_gen ~f:(fun p -> assert (on_s (M.conic_to_s p)))

      let%test_unit "field-to-S" =
        Quickcheck.test ~sexp_of:F.sexp_of_t gen ~f:(fun t ->
            assert (on_s (Fn.compose M.conic_to_s M.field_to_conic t)) )

      (* Schwarz-zippel says if this tests succeeds once, then the probability that
   the implementation is correct is at least 1 - (D / field-size), where D is
   the total degree of the polynomial defining_equation_of_V(s_to_v(t)) which should
   be less than, say, 10. So, this test succeeding gives good evidence of the
   correctness of the implementation (assuming that the implementation is just a
   polynomial, which it is by parametricity!) *)
      let%test_unit "field-to-V" =
        Quickcheck.test ~sexp_of:F.sexp_of_t gen ~f:(fun t ->
            let s = M.conic_to_s (M.field_to_conic t) in
            assert (on_v (M._s_to_v s)) )

      let%test_unit "full map works" =
        Quickcheck.test ~sexp_of:F.sexp_of_t gen ~f:(fun t ->
            let x, y = to_group (module F) ~params t in
            assert (equal (curve_eqn x) (y * y)) )
    end

    module T0 = Make_tests (F13)
    module T1 = Make_tests (Fp)
  end )
