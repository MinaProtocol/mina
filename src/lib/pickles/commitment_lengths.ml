open Core_kernel
open Pickles_types
open Import

(* Compute the number of group elements required to represent each commitment.
   This is simply ceil(degree of commitment / max degree natively supported by the PCS) *)

let generic' ~h ~sub ~add:( + ) ~mul:( * ) ~of_int ~ceil_div_max_degree :
    _ Dlog_plonk_types.Evals.t =
  let n = h#size in
  let t_bound =
    ceil_div_max_degree (Common.max_quot_size ~of_int ~mul:( * ) ~sub n)
  in
  let h = ceil_div_max_degree n in
  { l = n; r = n; o = n; z = n; t = t_bound; f = n; sigma1 = h; sigma2 = h }

let generic map ~h ~max_degree : _ Dlog_plonk_types.Evals.t =
  let t_bound = map h ~f:(fun h -> Common.max_quot_size_int h) in
  Dlog_plonk_types.Evals.map
    ~f:(fun v ->
      map v ~f:(fun x -> Int.round_up x ~to_multiple_of:max_degree / max_degree)
      )
    { l = h; r = h; o = h; z = h; t = t_bound; f = h; sigma1 = h; sigma2 = h }

let of_domains { Domains.h; _ } ~max_degree : int Dlog_plonk_types.Evals.t =
  let h = Domain.size h in
  generic ~max_degree (fun x ~f -> f x) ~h

let of_domains_vector domainses =
  let open Vector in
  let f field = map domainses ~f:(Fn.compose Domain.size field) in
  Vector.(generic map ~h:(f Domains.h))
