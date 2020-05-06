(* Based on this paper. https://eprint.iacr.org/2019/403 *)

open Core_kernel

module Spec = struct
  type 'f t = {b: 'f}
end

module Params = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'f t =
        { u: 'f
        ; fu: 'f
        ; sqrt_neg_three_u_squared_minus_u_over_2: 'f
        ; sqrt_neg_three_u_squared: 'f
        ; inv_three_u_squared: 'f
        ; b: 'f }
      [@@deriving fields, bin_io, version]
    end
  end]

  include Stable.Latest

  let spec {b; _} = {Spec.b}

  let map
      { u
      ; fu
      ; sqrt_neg_three_u_squared_minus_u_over_2
      ; sqrt_neg_three_u_squared
      ; inv_three_u_squared
      ; b } ~f =
    { u= f u
    ; fu= f fu
    ; sqrt_neg_three_u_squared_minus_u_over_2=
        f sqrt_neg_three_u_squared_minus_u_over_2
    ; sqrt_neg_three_u_squared= f sqrt_neg_three_u_squared
    ; inv_three_u_squared= f inv_three_u_squared
    ; b= f b }

  (* A deterministic function for constructing a valid choice of parameters for a
     given field. *)
  let create (type t) (module F : Field_intf.S_unchecked with type t = t)
      {Spec.b} =
    let open F in
    let first_map f =
      let rec go i = match f i with Some x -> x | None -> go (i + one) in
      go zero
    in
    let curve_eqn u = (u * u * u) + b in
    let u, fu =
      first_map (fun u ->
          let fu = curve_eqn u in
          if equal u zero || equal fu zero then None else Some (u, fu) )
    in
    let three_u_squared = u * u * of_int 3 in
    let sqrt_neg_three_u_squared = sqrt (negate three_u_squared) in
    { u
    ; fu
    ; sqrt_neg_three_u_squared_minus_u_over_2=
        (sqrt_neg_three_u_squared - u) / of_int 2
    ; sqrt_neg_three_u_squared
    ; inv_three_u_squared= one / three_u_squared
    ; b }
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
  open P

  let square x = x * x

  let potential_xs t =
    let t2 = t * t in
    let alpha =
      let alpha_inv = (t2 + constant params.fu) * t2 in
      one / alpha_inv
    in
    let x1 =
      let temp =
        square t2 * alpha * constant params.sqrt_neg_three_u_squared
      in
      constant params.sqrt_neg_three_u_squared_minus_u_over_2 - temp
    in
    let x2 = negate (constant params.u) - x1 in
    let x3 =
      let t2_plus_fu = t2 + constant params.fu in
      let t2_inv = alpha * t2_plus_fu in
      let temp =
        square t2_plus_fu * t2_inv * constant params.inv_three_u_squared
      in
      constant params.u - temp
    in
    (x1, x2, x3)
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
  let b = params.b in
  let try_decode x =
    let f x = F.((x * x * x) + b) in
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
                  let order =
                    Snarkette.Nat.of_string
                      "5543634365110765627805495722742127385843376434033820803590214255538854698464778703795540858859767700241957783601153"
                end)

      let b = of_int 7
    end

    module Make_tests (F : sig
      include Field_intf.S_unchecked

      val gen : t Quickcheck.Generator.t

      val b : t
    end) =
    struct
      module F = struct
        include F

        let constant = Fn.id
      end

      open F

      let params = Params.create (module F) {b}

      let curve_eqn u = (u * u * u) + params.b

      (* Filter the two points which cause the group-map to blow up. This
   is not an issue in practice because the points we feed into this function
   will be the output of poseidon, and thus (modeling poseidon as a random oracle)
   will not be either of those two points. *)
      let gen =
        Quickcheck.Generator.filter F.gen ~f:(fun t ->
            let t2 = t * t in
            let alpha_inv = (t2 + constant params.fu) * t2 in
            not (equal alpha_inv zero) )

      module M =
        Make (F) (F)
          (struct
            let params = params
          end)

      let%test_unit "full map works" =
        Quickcheck.test ~sexp_of:F.sexp_of_t gen ~f:(fun t ->
            let x, y = to_group (module F) ~params t in
            assert (equal (curve_eqn x) (y * y)) )
    end

    module T0 = Make_tests (Fp)
  end )
