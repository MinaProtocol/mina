open Intf
open Core_kernel
open Pickles_types

(* module B = Snarky_bn382 *)

module type Inputs_intf = sig
  module Base_field : sig
    type t
  end

  module Curve : sig
    module Affine : sig
      type t

      module Backend : sig
        include Type_with_delete

        val create : Base_field.t -> Base_field.t -> t

        module Vector : Vector with type elt := t
      end

      val of_backend : Backend.t -> t
    end
  end

  module Backend : sig
    include Type_with_delete

    val make :
      Curve.Affine.Backend.Vector.t -> Curve.Affine.Backend.t option -> t

    val shifted : t -> Curve.Affine.Backend.t option

    val unshifted : t -> Curve.Affine.Backend.Vector.t
  end
end

type 'a t =
  [ `With_degree_bound of
    ('a, 'a option) Dlog_plonk_types.Poly_comm.With_degree_bound.t
  | `Without_degree_bound of
    'a Dlog_plonk_types.Poly_comm.Without_degree_bound.t ]

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  module Backend = Backend

  type nonrec t = (Base_field.t * Base_field.t) t

  module G_affine = Curve.Affine.Backend

  let g (a, b) =
    let open G_affine in
    let t = create a b in
    Caml.Gc.finalise delete t ; t

  let g_vec arr =
    let v = G_affine.Vector.create () in
    Array.iter arr ~f:(fun c ->
        (* Very leaky *)
        G_affine.Vector.emplace_back v (g c) ) ;
    Caml.Gc.finalise G_affine.Vector.delete v ;
    v

  let with_degree_bound_to_backend
      (commitment :
        ( Base_field.t * Base_field.t
        , (Base_field.t * Base_field.t) option )
        Dlog_plonk_types.Poly_comm.With_degree_bound.t) : Backend.t =
    Backend.make
      (g_vec commitment.unshifted)
      (Option.map ~f:g commitment.shifted)

  let without_degree_bound_to_backend
      (commitment :
        (Base_field.t * Base_field.t)
        Dlog_plonk_types.Poly_comm.Without_degree_bound.t) : Backend.t =
    Backend.make (g_vec commitment) None

  let to_backend (t : t) : Backend.t =
    let t =
      match t with
      | `With_degree_bound t ->
          with_degree_bound_to_backend t
      | `Without_degree_bound t ->
          without_degree_bound_to_backend t
    in
    Caml.Gc.finalise Backend.delete t ;
    t

  let of_backend' (t : Backend.t) =
    let open Backend in
    let unshifted =
      (* TODO: Leaky? *)
      let v = unshifted t in
      Array.init (G_affine.Vector.length v) (fun i ->
          Curve.Affine.of_backend (G_affine.Vector.get v i) )
    in
    (* TODO: Leaky? *)
    let shifted = shifted t in
    (unshifted, Option.map shifted ~f:Curve.Affine.of_backend)

  let of_backend_with_degree_bound t =
    let open Dlog_plonk_types.Poly_comm in
    let unshifted, shifted = of_backend' t in
    `With_degree_bound {With_degree_bound.unshifted; shifted}

  let of_backend_without_degree_bound t =
    let open Dlog_plonk_types.Poly_comm in
    match of_backend' t with
    | unshifted, None ->
        `Without_degree_bound unshifted
    | _ ->
        assert false
end
