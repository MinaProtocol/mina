open Core_kernel
open Pickles_types
open Pickles_base
open Tuple_lib
module Domain = Domain

type 'field vanishing_polynomial_domain =
  < vanishing_polynomial: 'field -> 'field >

type 'field plonk_domain =
  < vanishing_polynomial: 'field -> 'field
  ; shifts: 'field Snarky_bn382.Shifts.t
  ; generator: 'field
  ; size: 'field >

type 'field domain = < size: 'field ; vanishing_polynomial: 'field -> 'field >

let debug = false

module type Field_intf = sig
  type t

  val size_in_bits : int

  val one : t

  val of_int : int -> t

  val ( * ) : t -> t -> t

  val ( / ) : t -> t -> t

  val ( + ) : t -> t -> t

  val ( - ) : t -> t -> t

  val negate : t -> t
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

let domain (type t) ((module F) : t field) ~shifts ~domain_generator
    (domain : Domain.t) : t plonk_domain =
  let size = F.of_int (Domain.size domain) in
  let log2_size = Domain.log2_size domain in
  let shifts = shifts ~log2_size in
  let generator = domain_generator ~log2_size in
  object
    method size = size

    method shifts = shifts

    method vanishing_polynomial x = vanishing_polynomial (module F) domain x

    method generator = generator
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

let evals_of_split_evals field ~zeta ~zetaw
    ((es1, es2) : _ Dlog_plonk_types.Evals.t Double.t) ~rounds =
  let e = Fn.flip (actual_evaluation field ~rounds) in
  Dlog_plonk_types.Evals.(map es1 ~f:(e zeta), map es2 ~f:(e zetaw))

open Composition_types.Dlog_based.Proof_state.Deferred_values.Plonk

let derive_plonk (type t) ?(with_label = fun _ (f : unit -> t) -> f ())
    (module F : Field_intf with type t = t) ~shift ~endo
    ~(domain : t plonk_domain) =
  let open F in
  let square x = x * x in
  let double x = of_int 2 * x in
  let sbox x =
    (* x^5 *)
    square (square x) * x
  in
  let {Snarky_bn382.Shifts.r; o} = domain#shifts in
  fun ({alpha; beta; gamma; zeta} : _ Minimal.t)
      ((e0, e1) : _ Dlog_plonk_types.Evals.t Double.t) ->
    let bz = beta * zeta in
    let perm0 =
      with_label __LOC__ (fun () ->
          (e0.l + bz + gamma)
          * (e0.r + (bz * r) + gamma)
          * (e0.o + (bz * o) + gamma)
          * alpha
          + (alpha * alpha * domain#vanishing_polynomial zeta / (zeta - one))
      )
    in
    let perm1 =
      let beta_sigma1 = with_label __LOC__ (fun () -> beta * e0.sigma1) in
      let beta_sigma2 = with_label __LOC__ (fun () -> beta * e0.sigma2) in
      let beta_alpha = with_label __LOC__ (fun () -> beta * alpha) in
      with_label __LOC__ (fun () ->
          negate (e0.l + beta_sigma1 + gamma)
          * (e0.r + beta_sigma2 + gamma)
          * (e1.z * beta_alpha) )
    in
    let gnrc_l = e0.l in
    let gnrc_r = e0.r in
    let gnrc_o = e0.o in
    let alphas =
      let a2 = alpha * alpha in
      let a = Array.init 4 ~f:(fun _ -> a2) in
      for i = 1 to Int.(Array.length a - 1) do
        a.(i) <- with_label __LOC__ (fun () -> a.(Int.(i - 1)) * alpha)
      done ;
      a
    in
    let psdn0 =
      let l, r, o = (sbox e0.l, sbox e0.r, sbox e0.o) in
      with_label __LOC__ (fun () ->
          ((l + o - e1.l) * alphas.(1))
          + ((l + r - e1.r) * alphas.(2))
          + ((r + o - e1.o) * alphas.(3)) )
    in
    let ecad0 =
      with_label __LOC__ (fun () ->
          (((e1.r - e1.l) * (e0.o + e0.l)) - ((e1.l - e1.o) * (e0.r - e0.l)))
          * alphas.(1)
          + ( ((e1.l + e1.r + e1.o) * (e1.l - e1.o) * (e1.l - e1.o))
            - ((e0.o + e0.l) * (e0.o + e0.l)) )
            * alphas.(2) )
    in
    let vbmul0, vbmul1 =
      let tmp = double e0.l - square e0.r + e1.r in
      ( with_label __LOC__ (fun () ->
            ((square e0.r - e0.r) * alphas.(1))
            + (((e1.l - e0.l) * e1.r) - e1.o + (e0.o * (double e0.r - one)))
              * alphas.(2) )
      , with_label __LOC__ (fun () ->
            ( square (double e0.o - (tmp * e0.r))
            - ((square e0.r - e1.r + e1.l) * square tmp) )
            * alphas.(1)
            + ( ((e0.l - e1.l) * (double e0.o - (tmp * e0.r)))
              - ((e1.o + e0.o) * tmp) )
              * alphas.(2) ) )
    in
    let endomul0, endomul1, endomul2 =
      let xr = square e0.r - e0.l - e1.r in
      let t = e0.l - xr in
      let u = double e0.o - (t * e0.r) in
      ( with_label __LOC__ (fun () ->
            ((square e0.l - e0.l) * alphas.(1))
            + ((square e1.l - e1.l) * alphas.(2))
            + ((e1.r - ((one + (e0.l * (endo - one))) * e0.r)) * alphas.(3)) )
      , with_label __LOC__ (fun () ->
            ((e1.l - e0.r) * e1.r) - e1.o + (e0.o * (double e0.l - one)) )
      , with_label __LOC__ (fun () ->
            ((square u - (square t * (xr + e0.l + e1.l))) * alphas.(1))
            + ((((e0.l - e1.l) * u) - (t * (e0.o + e1.o))) * alphas.(2)) ) )
    in
    In_circuit.map_fields
      ~f:(Shifted_value.of_field (module F) ~shift)
      { alpha
      ; beta
      ; gamma
      ; zeta
      ; perm0
      ; perm1
      ; gnrc_l
      ; gnrc_r
      ; gnrc_o
      ; psdn0
      ; ecad0
      ; vbmul0
      ; vbmul1
      ; endomul0
      ; endomul1
      ; endomul2 }

let checked (type t)
    (module Impl : Snarky_backendless.Snark_intf.Run with type field = t)
    ~domain ~shift ~endo (plonk : _ In_circuit.t) evals =
  let actual =
    derive_plonk ~with_label:Impl.with_label
      (module Impl.Field)
      ~endo ~domain ~shift
      { alpha= plonk.alpha
      ; beta= plonk.beta
      ; gamma= plonk.gamma
      ; zeta= plonk.zeta }
      evals
  in
  let open Impl in
  let open In_circuit in
  with_label __LOC__ (fun () ->
      List.map
        ~f:(fun f -> Shifted_value.equal Field.equal (f plonk) (f actual))
        [ perm0
        ; perm1
        ; gnrc_l
        ; gnrc_r
        ; gnrc_o
        ; psdn0
        ; ecad0
        ; vbmul0
        ; vbmul1
        ; endomul0
        ; endomul1
        ; endomul2 ]
      |> Boolean.all )

(*
let checked (type t)
    (module Impl : Snarky_backendless.Snark_intf.Run with type field = t)
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
*)
