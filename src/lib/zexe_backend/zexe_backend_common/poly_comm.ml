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

        val create_without_finaliser : Base_field.t -> Base_field.t -> t

        module Vector : Vector with type elt := t
      end

      val of_backend : Backend.t -> t
    end
  end

  module Backend : sig
    include Type_with_delete

    val make_without_finaliser :
      Curve.Affine.Backend.Vector.t -> Curve.Affine.Backend.t option -> t

    val shifted : t -> Curve.Affine.Backend.t option

    val unshifted : t -> Curve.Affine.Backend.Vector.t
  end
end

type 'a t =
  [ `With_degree_bound of 'a Dlog_marlin_types.Poly_comm.With_degree_bound.t
  | `Without_degree_bound of
    'a Dlog_marlin_types.Poly_comm.Without_degree_bound.t ]

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  module Backend = Backend

  type nonrec t = (Base_field.t * Base_field.t) t

  module G_affine = Curve.Affine.Backend

  let gc delete t = Caml.Gc.finalise delete t ; t

  let g (a, b) =
    let open G_affine in
    gc delete (create_without_finaliser a b)

  let g_vec arr =
    let v = G_affine.Vector.create_without_finaliser () in
    Array.iter arr ~f:(fun (a, b) ->
        let g_backend = G_affine.create_without_finaliser a b in
        G_affine.Vector.emplace_back v g_backend ;
        G_affine.delete g_backend ) ;
    Caml.Gc.finalise G_affine.Vector.delete v ;
    v

  let with_degree_bound_to_backend
      (commitment :
        (Base_field.t * Base_field.t)
        Dlog_marlin_types.Poly_comm.With_degree_bound.t) : Backend.t =
    gc Backend.delete
      (Backend.make_without_finaliser
         (g_vec commitment.unshifted)
         (Some (g commitment.shifted)))

  let without_degree_bound_to_backend
      (commitment :
        (Base_field.t * Base_field.t)
        Dlog_marlin_types.Poly_comm.Without_degree_bound.t) : Backend.t =
    gc Backend.delete (Backend.make_without_finaliser (g_vec commitment) None)

  let to_backend (t : t) : Backend.t =
    match t with
    | `With_degree_bound t ->
        with_degree_bound_to_backend t
    | `Without_degree_bound t ->
        without_degree_bound_to_backend t

  let of_backend (t : Backend.t) =
    let open Backend in
    let unshifted =
      let v = unshifted t in
      let res =
        Array.init (G_affine.Vector.length v) (fun i ->
            let x = G_affine.Vector.get_without_finaliser v i in
            let res = Curve.Affine.of_backend x in
            Curve.Affine.Backend.delete x ;
            res )
      in
      G_affine.Vector.delete v ; res
    in
    let shifted = shifted t in
    let open Dlog_marlin_types.Poly_comm in
    match shifted with
    | Some g ->
        Curve.Affine.Backend.delete g ;
        `With_degree_bound
          {With_degree_bound.unshifted; shifted= Curve.Affine.of_backend g}
    | None ->
        `Without_degree_bound unshifted
end
