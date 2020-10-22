open Core
open Pickles_types
open Import

(* Compute the number of group elements required to represent each commitment.
   This is simply ceil(degree of commitment / max degree natively supported by the PCS) *)

let generic' ~h ~add:( + ) ~mul:( * ) ~of_int ~ceil_div_max_degree :
    _ Dlog_plonk_types.Evals.t =
  let n = h#size in
  let n_plus_2 = ceil_div_max_degree (of_int 2 + n) in
  let n_plus_3 = ceil_div_max_degree (of_int 3 + n) in
  let five_n_plus_1 = ceil_div_max_degree (of_int 5 * (n + of_int 1)) in
  let h = ceil_div_max_degree n in
  { l= n_plus_2
  ; r= n_plus_2
  ; o= n_plus_2
  ; z= n_plus_3
  ; t= five_n_plus_1
  ; f= n_plus_3
  ; sigma1= h
  ; sigma2= h }

let generic map ~h ~max_degree : _ Dlog_plonk_types.Evals.t =
  let n_plus_2 = map h ~f:(fun h -> h + 2) in
  let n_plus_3 = map h ~f:(fun h -> h + 3) in
  let five_n_plus_1 = map h ~f:(fun h -> 5 * (h + 1)) in
  Dlog_plonk_types.Evals.map
    ~f:(fun v ->
      map v ~f:(fun x -> Int.round_up x ~to_multiple_of:max_degree / max_degree)
      )
    { l= n_plus_2
    ; r= n_plus_2
    ; o= n_plus_2
    ; z= n_plus_3
    ; t= five_n_plus_1
    ; f= n_plus_3
    ; sigma1= h
    ; sigma2= h }

let of_domains {Domains.h; _} ~max_degree : int Dlog_plonk_types.Evals.t =
  let h = Domain.size h in
  generic ~max_degree (fun x ~f -> f x) ~h

let of_domains_vector domainses =
  let open Vector in
  let f field = map domainses ~f:(Fn.compose Domain.size field) in
  Vector.(generic map ~h:(f Domains.h))
