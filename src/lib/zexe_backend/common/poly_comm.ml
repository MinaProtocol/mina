open Intf
open Core_kernel
open Pickles_types

(* module B = Snarky_bn382 *)

module type Inputs_intf = sig
  module Base_field : sig
    type t
  end

  module G_affine : sig
    include Type_with_delete

    val create : Base_field.t -> Base_field.t -> t

    module Vector : Vector with type elt := t
  end

  module Poly_comm : sig
    type t

    val make : G_affine.Vector.t -> G_affine.t option -> t
  end
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs

  type t = Poly_comm.t

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
        (Base_field.t * Base_field.t)
        Dlog_marlin_types.Poly_comm.With_degree_bound.t) : t =
    Poly_comm.make (g_vec commitment.unshifted) (Some (g commitment.shifted))

  let without_degree_bound_to_backend
      (commitment :
        (Base_field.t * Base_field.t)
        Dlog_marlin_types.Poly_comm.Without_degree_bound.t) : t =
    Poly_comm.make (g_vec commitment) None
end
