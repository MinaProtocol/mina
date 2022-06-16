open Intf
open Core_kernel
open Pickles_types

module type Inputs_intf = sig
  module Base_field : sig
    type t
  end

  module Curve : sig
    module Affine : sig
      type t = Base_field.t * Base_field.t

      module Backend : sig
        type t = (Base_field.t * Base_field.t) Or_infinity.t

        val zero : unit -> t

        val create : Base_field.t -> Base_field.t -> t
      end

      val of_backend : Backend.t -> t Or_infinity.t
    end
  end

  module Backend : sig
    type t = Curve.Affine.Backend.t Marlin_plonk_bindings.Types.Poly_comm.t

    val make :
      Curve.Affine.Backend.t array -> Curve.Affine.Backend.t option -> t

    val shifted : t -> Curve.Affine.Backend.t option

    val unshifted : t -> Curve.Affine.Backend.t array
  end
end

type 'a t =
  [ `With_degree_bound of
    'a Or_infinity.t Dlog_plonk_types.Poly_comm.With_degree_bound.t
  | `Without_degree_bound of
    'a Dlog_plonk_types.Poly_comm.Without_degree_bound.t ]

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  module Backend = Backend

  type nonrec t = (Base_field.t * Base_field.t) t

  module G_affine = Curve.Affine.Backend

  let g (a, b) = G_affine.create a b

  let g_vec arr = Array.map ~f:g arr

  let with_degree_bound_to_backend
      (commitment :
        (Base_field.t * Base_field.t) Or_infinity.t
        Dlog_plonk_types.Poly_comm.With_degree_bound.t ) : Backend.t =
    { shifted = Some commitment.shifted; unshifted = commitment.unshifted }

  let without_degree_bound_to_backend
      (commitment :
        (Base_field.t * Base_field.t)
        Dlog_plonk_types.Poly_comm.Without_degree_bound.t ) : Backend.t =
    { shifted = None
    ; unshifted = Array.map ~f:(fun x -> Or_infinity.Finite x) commitment
    }

  let to_backend (t : t) : Backend.t =
    let t =
      match t with
      | `With_degree_bound t ->
          with_degree_bound_to_backend t
      | `Without_degree_bound t ->
          without_degree_bound_to_backend t
    in
    t

  let of_backend' (t : Backend.t) =
    (t.unshifted, Option.map t.shifted ~f:Curve.Affine.of_backend)

  let of_backend_with_degree_bound (t : Backend.t) =
    let open Dlog_plonk_types.Poly_comm in
    match t.shifted with
    | None ->
        assert false
    | Some shifted ->
        `With_degree_bound
          { With_degree_bound.unshifted = t.unshifted; shifted }

  let of_backend_without_degree_bound (t : Backend.t) =
    let open Dlog_plonk_types.Poly_comm in
    match t with
    | { unshifted; shifted = None } ->
        `Without_degree_bound
          (Array.map unshifted ~f:(function
            | Infinity ->
                assert false
            | Finite g ->
                g ) )
    | _ ->
        assert false
end
