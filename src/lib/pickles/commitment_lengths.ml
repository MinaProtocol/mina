open Core
open Pickles_types
open Import

(* Compute the number of group elements required to represent each commitment.
   This is simply ceil(degree of commitment / max degree natively supported by the PCS) *)

let generic' ~h ~k ~sub:( - ) ~mul:( * ) ~of_int ~ceil_div_max_degree :
    _ Dlog_marlin_types.Evals.t =
  let two_h = ceil_div_max_degree (of_int 2 * h#size) in
  let three_k_minus_three =
    ceil_div_max_degree ((of_int 3 * k#size) - of_int 3)
  in
  let h = ceil_div_max_degree h#size in
  let k = ceil_div_max_degree k#size in
  let index : _ Abc.t = {a= k; b= k; c= k} in
  { w_hat= h
  ; z_hat_a= h
  ; z_hat_b= h
  ; h_1= two_h
  ; h_2= h
  ; h_3= three_k_minus_three
  ; row= index
  ; col= index
  ; value= index
  ; rc= index
  ; g_1= h
  ; g_2= h
  ; g_3= k }

let generic map ~h ~k ~max_degree : _ Dlog_marlin_types.Evals.t =
  let index : _ Abc.t = {a= k; b= k; c= k} in
  Dlog_marlin_types.Evals.map
    ~f:(fun v ->
      map v ~f:(fun x -> Int.round_up x ~to_multiple_of:max_degree / max_degree)
      )
    { w_hat= h
    ; z_hat_a= h
    ; z_hat_b= h
    ; h_1= map h ~f:(( * ) 2)
    ; h_2= h
    ; h_3= map k ~f:(fun k -> (3 * k) - 3)
    ; row= index
    ; col= index
    ; value= index
    ; rc= index
    ; g_1= h
    ; g_2= h
    ; g_3= k }

let of_domains {Domains.h; k} ~max_degree : int Dlog_marlin_types.Evals.t =
  let h, k = Domain.(size h, size k) in
  generic ~max_degree (fun x ~f -> f x) ~h ~k

let of_domains_vector domainses =
  let open Vector in
  let f field = map domainses ~f:(Fn.compose Domain.size field) in
  Vector.(generic map ~h:(f Domains.h) ~k:(f Domains.k))
