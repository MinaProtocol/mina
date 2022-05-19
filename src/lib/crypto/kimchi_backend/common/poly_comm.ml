open Intf
open Core_kernel

module type Inputs_intf = sig
  module Base_field : sig
    type t
  end

  module Curve : sig
    module Affine : sig
      type t = Base_field.t * Base_field.t

      module Backend : sig
        type t = Base_field.t Kimchi_types.or_infinity

        val zero : unit -> t

        val create : Base_field.t -> Base_field.t -> t
      end

      val of_backend :
        Backend.t -> (Base_field.t * Base_field.t) Pickles_types.Or_infinity.t
    end
  end

  module Backend : sig
    type t

    val make :
      Curve.Affine.Backend.t array -> Curve.Affine.Backend.t option -> t

    val shifted : t -> Curve.Affine.Backend.t option

    val unshifted : t -> Curve.Affine.Backend.t array
  end
end

type 'a t =
  [ `With_degree_bound of
    ('a * 'a) Pickles_types.Or_infinity.t
    Pickles_types.Plonk_types.Poly_comm.With_degree_bound.t
  | `Without_degree_bound of
    ('a * 'a) Pickles_types.Plonk_types.Poly_comm.Without_degree_bound.t ]

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  module Backend = Backend

  type nonrec t = Base_field.t t

  module G_affine = Curve.Affine.Backend

  let g (a, b) = G_affine.create a b

  let g_vec arr = Array.map ~f:g arr

  let or_infinity_to_backend :
      ('a * 'a) Pickles_types.Or_infinity.t -> 'a Kimchi_types.or_infinity =
    function
    | Infinity ->
        Infinity
    | Finite (x, y) ->
        Finite (x, y)

  let or_infinity_of_backend :
      'a Kimchi_types.or_infinity -> ('a * 'a) Pickles_types.Or_infinity.t =
    function
    | Infinity ->
        Infinity
    | Finite (x, y) ->
        Finite (x, y)

  let with_degree_bound_to_backend
      (commitment :
        (Base_field.t * Base_field.t) Pickles_types.Or_infinity.t
        Pickles_types.Plonk_types.Poly_comm.With_degree_bound.t ) : Backend.t =
    Backend.make
      (Array.map ~f:or_infinity_to_backend commitment.unshifted)
      (Some (or_infinity_to_backend commitment.shifted))

  let without_degree_bound_to_backend
      (commitment :
        (Base_field.t * Base_field.t)
        Pickles_types.Plonk_types.Poly_comm.Without_degree_bound.t ) : Backend.t
      =
    Backend.make
      (Array.map ~f:(fun x -> Kimchi_types.Finite (fst x, snd x)) commitment)
      None

  let to_backend (t : t) : Backend.t =
    match t with
    | `With_degree_bound t ->
        with_degree_bound_to_backend t
    | `Without_degree_bound t ->
        without_degree_bound_to_backend t

  let of_backend' (t : Backend.t) =
    ( Backend.unshifted t
    , Option.map (Backend.shifted t) ~f:Curve.Affine.of_backend )

  let of_backend_with_degree_bound (t : Backend.t) : t =
    let open Pickles_types.Plonk_types.Poly_comm in
    match Backend.shifted t with
    | None ->
        assert false
    | Some shifted ->
        let shifted = or_infinity_of_backend shifted in
        let unshifted =
          Backend.unshifted t |> Array.map ~f:or_infinity_of_backend
        in
        `With_degree_bound { unshifted; shifted }

  (*
     type 'a t =
       [ `With_degree_bound of
         ('a * 'a) Pickles_types.Or_infinity.t
         Pickles_types.Plonk_types.Poly_comm.With_degree_bound.t
       | `Without_degree_bound of
         ('a * 'a) Pickles_types.Plonk_types.Poly_comm.Without_degree_bound.t
       ]
  *)

  let of_backend_without_degree_bound (t : Backend.t) =
    let open Pickles_types.Plonk_types.Poly_comm in
    let unshifted = Backend.unshifted t in
    match Backend.shifted t with
    | None ->
        `Without_degree_bound
          (Array.map unshifted ~f:(function
            | Infinity ->
                assert false
            | Finite (x, y) ->
                (x, y) ) )
    | _ ->
        assert false
end
