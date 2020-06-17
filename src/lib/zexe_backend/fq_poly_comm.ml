open Core_kernel
open Pickles_types
module B = Snarky_bn382

type t = B.Fq_poly_comm.t

let g (a, b) =
  let open B.G.Affine in
  let t = create a b in
  Caml.Gc.finalise delete t ; t

let g_vec arr =
  let v = B.G.Affine.Vector.create () in
  Array.iter arr ~f:(fun c ->
      (* Very leaky *)
      B.G.Affine.Vector.emplace_back v (g c) ) ;
  Caml.Gc.finalise B.G.Affine.Vector.delete v ;
  v

let with_degree_bound_to_backend
    (commitment : G.Affine.t Dlog_marlin_types.Poly_comm.With_degree_bound.t) :
    t =
  B.Fq_poly_comm.make
    (g_vec commitment.unshifted)
    (Some (g commitment.shifted))

let without_degree_bound_to_backend
    (commitment :
      G.Affine.t Dlog_marlin_types.Poly_comm.Without_degree_bound.t) : t =
  B.Fq_poly_comm.make (g_vec commitment) None
