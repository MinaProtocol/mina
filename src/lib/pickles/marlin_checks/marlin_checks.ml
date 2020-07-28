open Core_kernel
open Pickles_types
module Domain = Domain

type 'field vanishing_polynomial_domain =
  < vanishing_polynomial: 'field -> 'field >

type 'field domain = < size: 'field ; vanishing_polynomial: 'field -> 'field >

let debug = false

module type Field_intf = sig
  type t

  val one : t

  val of_int : int -> t

  val ( * ) : t -> t -> t

  val ( / ) : t -> t -> t

  val ( + ) : t -> t -> t

  val ( - ) : t -> t -> t
end

type 'f field = (module Field_intf with type t = 'f)

let map_reduce reduce xs map = List.reduce_exn (List.map xs ~f:map) ~f:reduce

(* x^{2 ^ k} - 1 *)
let vanishing_polynomial (type t) ((module F) : t field) domain x =
  let k = Domain.log2_size domain in
  let rec pow2pow acc i =
    if i = 0 then acc else pow2pow F.(acc * acc) (i - 1)
  in
  F.(pow2pow x k - one)

let domain (type t) ((module F) : t field) (domain : Domain.t) : t domain =
  let size = F.of_int (Domain.size domain) in
  object
    method size = size

    method vanishing_polynomial x = vanishing_polynomial (module F) domain x
  end

let all_but m = List.filter Abc.Label.all ~f:(( <> ) m)

let actual_evaluation (type f) (module Field : Field_intf with type t = f)
    (e : Field.t array) (pt : Field.t) ~rounds : Field.t =
  let pt_n =
    let rec go acc i = if i = 0 then acc else go Field.(acc * acc) (i - 1) in
    go pt rounds
  in
  match List.rev (Array.to_list e) with
  | e :: es ->
      List.fold ~init:e es ~f:(fun acc fx -> Field.(fx + (pt_n * acc)))
  | [] ->
      failwith "empty list"

let evals_of_split_evals field (b1, b2, b3)
    ((e1, e2, e3) : _ Dlog_marlin_types.Evals.t Tuple_lib.Triple.t) ~rounds =
  let e = actual_evaluation field ~rounds in
  let abc es = Abc.map es ~f:(Fn.flip e b3) in
  { Pairing_marlin_types.Evals.w_hat= e e1.w_hat b1
  ; z_hat_a= e e1.z_hat_a b1
  ; z_hat_b= e e1.z_hat_b b1
  ; g_1= e e1.g_1 b1
  ; h_1= e e1.h_1 b1
  ; g_2= e e2.g_2 b2
  ; h_2= e e2.h_2 b2
  ; g_3= e e3.g_3 b3
  ; h_3= e e3.h_3 b3
  ; row= abc e3.row
  ; col= abc e3.col
  ; value= abc e3.value
  ; rc= abc e3.rc }

(* These correspond to the blue equations on [page 32 here](https://eprint.iacr.org/2019/1047.pdf),
   with a few modifications:

   - our [sigma_2] is the paper's [sigma_2 / domain_h#size]
   - our [sigma_3] is the paper's [sigma_3 / domain_k#size]
   - our Marlin variant does not have [h_0] and so the last equation on that page can be omitted.
*)
let checks (type t) (module F : Field_intf with type t = t)
    ~(input_domain : t vanishing_polynomial_domain) ~domain_h ~domain_k
    ~x_hat_beta_1
    { Composition_types.Dlog_based.Proof_state.Deferred_values.Marlin.sigma_2
    ; sigma_3
    ; alpha
    ; eta_a
    ; eta_b
    ; eta_c
    ; beta_1
    ; beta_2
    ; beta_3 }
    { Pairing_marlin_types.Evals.w_hat
    ; z_hat_a
    ; z_hat_b
    ; g_1
    ; h_1
    ; g_2
    ; h_2
    ; g_3
    ; h_3
    ; row= {a= row_a; b= row_b; c= row_c}
    ; col= {a= col_a; b= col_b; c= col_c}
    ; value= {a= value_a; b= value_b; c= value_c}
    ; rc= {a= rc_a; b= rc_b; c= rc_c} } =
  let open F in
  let abc = Abc.abc in
  (* Marlin checks follow *)
  let row = abc row_a row_b row_c
  and col = abc col_a col_b col_c
  and value = abc value_a value_b value_c
  and rc = abc rc_a rc_b rc_c
  and eta = abc eta_a eta_b eta_c
  and z_ = abc z_hat_a z_hat_b (z_hat_a * z_hat_b) in
  let z_hat =
    let v_X_beta_1 = input_domain#vanishing_polynomial beta_1 in
    (w_hat * v_X_beta_1) + x_hat_beta_1
  in
  let sum = map_reduce ( + ) in
  let prod = map_reduce ( * ) in
  let r_alpha =
    let v_h_alpha = domain_h#vanishing_polynomial alpha in
    fun x -> (v_h_alpha - domain_h#vanishing_polynomial x) / (alpha - x)
  in
  let v_h_beta_1 = domain_h#vanishing_polynomial beta_1 in
  let v_h_beta_2 = domain_h#vanishing_polynomial beta_2 in
  let a_beta_3, b_beta_3 =
    let beta_1_beta_2 = beta_1 * beta_2 in
    let term =
      Memo.general ~cache_size_bound:10 (fun m ->
          beta_1_beta_2 + rc m - (beta_1 * row m) - (beta_2 * col m) )
    in
    let a =
      v_h_beta_1 * v_h_beta_2
      * sum Abc.Label.all (fun m -> eta m * value m * prod (all_but m) term)
    in
    let b = prod Abc.Label.all term in
    (a, b)
  in
  [ ( h_3 * domain_k#vanishing_polynomial beta_3
    , a_beta_3 - (b_beta_3 * ((beta_3 * g_3) + sigma_3)) )
  ; ( r_alpha beta_2 * sigma_3 * domain_k#size
    , (h_2 * v_h_beta_2) + sigma_2 + (g_2 * beta_2) )
  ; ( r_alpha beta_1 * sum Abc.Label.all (fun m -> eta m * z_ m)
    , (h_1 * v_h_beta_1) + (beta_1 * g_1) + (sigma_2 * domain_h#size * z_hat)
    ) ]

let checked (type t) (module Impl : Snarky.Snark_intf.Run with type field = t)
    ~input_domain ~domain_h ~domain_k ~x_hat_beta_1 marlin evals =
  let open Impl in
  let eqns =
    checks
      (module Field)
      ~input_domain ~domain_h ~domain_k ~x_hat_beta_1 marlin evals
  in
  List.mapi
    ~f:(fun i (x, y) ->
      if debug then
        as_prover
          As_prover.(
            fun () ->
              let x = read_var x in
              let y = read_var y in
              if not (Field.Constant.equal x y) then (
                printf "bad marlin %d\n%!" i ;
                Field.Constant.print x ;
                printf "%!" ;
                Field.Constant.print y ;
                printf "%!" )) ;
      Field.equal x y )
    eqns
  |> Boolean.all
