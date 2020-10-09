open Core_kernel
open Snarky_integer
open Util
module Floating_point = Floating_point

(*
    Given
    p / q = 0.b1 b2 b3 ...

    2^k p / q = b1 b2 b3 bk . b_{k+1} ...
  *)
let bignum_as_fixed_point k x =
  let p, q = Bignum.(num_as_bigint x, den_as_bigint x) in
  B.(shift_left p k / q)

let least ~such_that =
  let rec go i = if such_that i then i else go (i + 1) in
  go 0

let greatest ~such_that =
  let rec go best i =
    match such_that i with
    | Some acc ->
        go (Some acc) (i + 1)
    | None ->
        Option.value_exn best
  in
  go None 0

let factorial n =
  let rec go acc i =
    if B.(equal zero i) then acc else go B.(i * acc) B.(i - one)
  in
  go B.one n

(* Computes log using the taylor expansion around 1

   (x - 1) - (x - 1)^2 / 2 + (x - 1)^3 / 3 - ...

   Only works for 0 < x < 2.
*)
let log ~terms x =
  let open Bignum in
  let a = x - one in
  let open Sequence in
  unfold ~init:(a, 1) ~f:(fun (ai, i) ->
      let t = ai / of_int i in
      Some ((if Int.(i mod 2 = 0) then neg t else t), (ai * a, Int.(i + 1))) )
  |> Fn.flip take terms |> fold ~init:zero ~f:( + )

(* This computes the number of terms of a taylor series one needs to compute
   if the output is to be within 1/2^k of the actual value.
   It requires one give an upper bound on the absolute value of the
   derivatives of the function *)
let terms_needed ~derivative_magnitude_upper_bound ~bits_of_precision:k =
  (*
      We want the least n such that

      (n + 1)! / sup |f^(n+1)(x)|  > 2^k
  *)
  let lower_bound = Bignum.of_bigint B.(pow (of_int 2) k) in
  least ~such_that:(fun n ->
      let nn = B.of_int n in
      let d = derivative_magnitude_upper_bound Int.(n + 1) in
      Bignum.(of_bigint (factorial nn) / d > lower_bound) )

let ceil_log2 n =
  least ~such_that:(fun i -> B.(pow (of_int 2) (of_int i) >= n))

let binary_expansion x =
  assert (Bignum.(x < one)) ;
  let two = Bignum.of_int 2 in
  Sequence.unfold
    ~init:(x, Bignum.(one / two))
    ~f:(fun (rem, pt) ->
      let b = Bignum.(rem >= pt) in
      let rem = if b then Bignum.(rem - pt) else rem in
      Some (b, Bignum.(rem, pt / two)) )

module Params = struct
  type t =
    { total_precision: int
    ; per_term_precision: int
    ; terms_needed: int
    ; coefficients: ([`Neg | `Pos] * B.t) array }
end

(* This module constructs a snarky function for computing the function

   x -> base^x

   where x is in the interval [0, 1)
*)
module Exp = struct
  (* An upper bound on the magnitude nth derivative of base^x in [0, 1) is
   |log(base)|^n *)

  let derivative_magnitude_upper_bound n ~log_base = Bignum.(log_base ** n)

  let terms_needed ~log_base ~bits_of_precision =
    terms_needed
      ~derivative_magnitude_upper_bound:
        (derivative_magnitude_upper_bound ~log_base)
      ~bits_of_precision

  type bit_params =
    {total_precision: int; terms_needed: int; per_term_precision: int}

  (* This figures out how many bits we can hope to calculate given our field
   size. This is because computing the terms

   x^k

   in the taylor series will start to overflow when k is too large. E.g.,
   if our field has 298 bits and x has 32 bits, then we cannot easily compute
   x^10, since representing it exactly requires 320 bits. *)
  let bit_params ~field_size_in_bits ~log_base =
    greatest ~such_that:(fun k ->
        let kk = B.of_int k in
        let n = terms_needed ~log_base ~bits_of_precision:kk in
        let per_term_precision = ceil_log2 (B.of_int n) + k in
        if (n * per_term_precision) + per_term_precision < field_size_in_bits
        then Some {per_term_precision; terms_needed= n; total_precision= k}
        else None )

  let params ~field_size_in_bits ~base =
    let abs_log_base =
      let log_base = log base ~terms:100 in
      assert (Bignum.(log_base < zero)) ;
      let r = Bignum.abs log_base in
      assert (Bignum.(r < one)) ;
      r
    in
    let {total_precision; terms_needed; per_term_precision} =
      bit_params ~field_size_in_bits ~log_base:abs_log_base
    in
    (* Precompute the coefficeints

       log(base)^i / i !

       as fixed point numbers.
    *)
    let coefficients =
      Array.init terms_needed ~f:(fun i ->
          (* Starts from 1 *)
          let i = i + 1 in
          ( (if i mod 2 = 0 then `Neg else `Pos)
          , Bignum.((abs_log_base ** i) / of_bigint (factorial (B.of_int i)))
            |> bignum_as_fixed_point per_term_precision ) )
    in
    {Params.total_precision; terms_needed; per_term_precision; coefficients}

  module Unchecked = struct
    let one_minus_exp (params : Params.t) x =
      let denom =
        Bignum.(of_bigint B.(shift_left one params.per_term_precision))
      in
      Array.fold params.coefficients ~init:(Bignum.zero, Bignum.one)
        ~f:(fun (acc, x_i) (sgn, c) ->
          let x_i = Bignum.(x_i * x) in
          let c = Bignum.(of_bigint c / denom) in
          let c = match sgn with `Pos -> c | `Neg -> Bignum.neg c in
          (Bignum.(acc + (x_i * c)), x_i) )
      |> fst
  end

  (* Zip together coefficients and powers of x and sum *)
  let taylor_sum ~m x_powers coefficients =
    Array.fold2_exn coefficients x_powers ~init:None
      ~f:(fun sum (sgn, ci) xi ->
        let term = Floating_point.(mul ~m ci xi) in
        match sum with
        | None ->
            assert (sgn = `Pos) ;
            Some term
        | Some s ->
            Some (Floating_point.add_signed ~m s (sgn, term)) )
    |> Option.value_exn

  let one_minus_exp ~m
      { Params.total_precision= _
      ; terms_needed
      ; per_term_precision
      ; coefficients } x =
    let powers = Floating_point.powers ~m x terms_needed in
    let coefficients =
      Array.map coefficients ~f:(fun (sgn, c) ->
          ( sgn
          , Floating_point.constant ~m ~value:c ~precision:per_term_precision
          ) )
    in
    taylor_sum ~m powers coefficients
end
