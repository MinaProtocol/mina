open Core
open Pickles_types
open Import

(* Compute the number of group elements required to represent each commitment.
   This is simply ceil(degree of commitment / max degree natively supported by the PCS) *)

let generic map ~h ~k : _ Dlog_marlin_types.Evals.t =
  let index : _ Abc.t = {a= k; b= k; c= k} in
  Dlog_marlin_types.Evals.map
    ~f:(fun v ->
      map v ~f:(fun x ->
          Int.round_up x ~to_multiple_of:Common.crs_max_degree
          / Common.crs_max_degree ) )
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

let of_domains {Domains.h; k} : int Dlog_marlin_types.Evals.t =
  let h, k = Domain.(size h, size k) in
  generic (fun x ~f -> f x) ~h ~k

let of_domains_vector domainses =
  let open Vector in
  let f field = map domainses ~f:(Fn.compose Domain.size field) in
  Vector.(generic map ~h:(f Domains.h) ~k:(f Domains.k))
