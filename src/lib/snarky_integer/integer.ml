open Core
open Snarky
open Snark
open Util
open Bitstring_lib

(* The number of bits needed to represent a number < x *)
let bits_needed x = Z.log2up (B.to_zarith_bigint x)

module Interval = struct
  type t = Constant of B.t | Less_than of B.t

  let iter t ~f = match t with Constant x -> f x | Less_than x -> f x

  let check (type f) ~m:((module M) : f m) t =
    iter t ~f:(fun x -> assert (B.(x < M.Field.size))) ;
    t

  let map ~m t ~f =
    check ~m
      ( match t with
      | Constant x ->
          Constant (f x)
      | Less_than x ->
          Less_than (f x) )

  let scale ~m t x =
    check ~m
      ( match t with
      | Constant t ->
          Constant B.(t * x)
      | Less_than t ->
          Less_than B.(t * x) )

  let succ ~m t = map ~m t ~f:B.succ

  let bits_needed = function
    | Constant x ->
        bits_needed B.(x + one)
    | Less_than x ->
        bits_needed x

  let min a b =
    match (a, b) with
    | Constant a, Constant b ->
        Constant (B.min a b)
    | Less_than a, Less_than b ->
        Less_than (B.min a b)
    | Less_than bound, Constant c | Constant c, Less_than bound ->
        Less_than B.(min (c + one) bound)

  let lub a b =
    match (a, b) with
    | Constant a, Constant b ->
        if B.equal a b then Constant a else Less_than B.(max a b + one)
    | Less_than a, Less_than b ->
        Less_than B.(max a b)
    | Constant c, Less_than bound | Less_than bound, Constant c ->
        Less_than B.(max bound (c + one))

  let quotient a b =
    (* TODO: This code would be simplified if we
        used Less_than_equal instead of Less_than *)
    match (a, b) with
    | Constant a, Constant b ->
        Constant B.(a / b)
    | Less_than a, Constant b ->
        (* 
       floor and /b both preserve <=. I.e.,
       if x <= y then
        floor(x) <= floor(y)
        x / b <= y / b

       And thus the composition floor(- / b) does as well.

       If a < A, then a <= x - 1 so
       q = floor(a / b) <= floor (A / b) < floor (A / b) + 1
    *)
        Less_than B.((a / b) + one)
    | Constant a, Less_than _ ->
        Less_than B.(a + one)
    | Less_than a, Less_than _ ->
        Less_than a
end

type 'f t =
  { value: 'f Cvar.t
  ; interval: Interval.t
  ; mutable bits: 'f Cvar.t Boolean.t list option }

let create ~value ~upper_bound =
  {value; interval= Less_than upper_bound; bits= None}

let to_field t = t.value

let constant (type f) ?length ~m:((module M) as m : f m) x =
  let open M in
  assert (x < Field.size) ;
  let upper_bound = B.(one + x) in
  let length =
    let b = bits_needed upper_bound in
    match length with
    | Some n ->
        assert (Int.(n >= b)) ;
        n
    | None ->
        b
  in
  { value= Field.(constant (bigint_to_field ~m x))
  ; interval= Constant x
  ; bits=
      Some
        (List.init length ~f:(fun i ->
             Boolean.var_of_value B.(shift_right x i land one = one) )) }

let shift_left (type f) ~m:((module M) as m : f m) t k =
  let open M in
  let two_to_k = B.(one lsl k) in
  { value= Field.(constant (bigint_to_field ~m two_to_k) * t.value)
  ; interval= Interval.scale ~m t.interval two_to_k
  ; bits=
      Option.map t.bits ~f:(fun bs ->
          List.init k ~f:(fun _ -> Boolean.false_) @ bs ) }

let of_bits (type f) ~m:((module M) : f m) bs =
  let bs = Bitstring.Lsb_first.to_list bs in
  { value= M.Field.project bs
  ; interval= Less_than B.(one lsl List.length bs)
  ; bits= Some bs }

(* Given a and b returns (q, r) such that

    a = q * b + r
    r < b
*)
let div_mod (type f) ~m:((module M) as m : f m) a b =
  let open M in
  (* Guess (q, r) *)
  let q, r =
    exists
      Typ.(field * field)
      ~compute:
        As_prover.(
          fun () ->
            let a = read_var a.value |> bigint_of_field ~m
            and b = read_var b.value |> bigint_of_field ~m in
            (bigint_to_field ~m B.(a / b), bigint_to_field ~m (B.rem a b)))
  in
  (* Check
      r < b
      a = q * b + r
      q has at most as many bits as a. *)
  let q_bit_length = Interval.bits_needed a.interval in
  let q_bits = Field.choose_preimage_var q ~length:q_bit_length in
  let b_bit_length = Interval.bits_needed b.interval in
  let r_bits = Field.choose_preimage_var r ~length:b_bit_length in
  let cmp = Field.compare ~bit_length:b_bit_length r b.value in
  Boolean.Assert.is_true cmp.less ;
  (* This assertion checkes that the multiplication q * b is safe. *)
  assert (q_bit_length + b_bit_length + 1 < Field.Constant.size_in_bits) ;
  assert_r1cs q b.value Field.(a.value - r) ;
  ( { value= q
    ; interval= Interval.quotient a.interval b.interval
    ; bits= Some q_bits }
  , {value= r; interval= b.interval; bits= Some r_bits} )

let to_bits ?length (type f) ~m:((module M) : f m) t =
  match t.bits with
  | Some bs -> (
      let bs = Bitstring.Lsb_first.of_list bs in
      match length with
      | None ->
          bs
      | Some n ->
          Bitstring.Lsb_first.pad bs
            ~padding_length:(n - Bitstring.Lsb_first.length bs)
            ~zero:M.Boolean.false_ )
  | None ->
      let bs =
        M.Field.choose_preimage_var t.value
          ~length:
            (Option.value ~default:(Interval.bits_needed t.interval) length)
      in
      t.bits <- Some bs ;
      Bitstring.Lsb_first.of_list bs

let to_bits_exn t = Bitstring.Lsb_first.of_list (Option.value_exn t.bits)

let min (type f) ~m:((module M) : f m) (a : f t) (b : f t) =
  let open M in
  let bit_length =
    Int.max (Interval.bits_needed a.interval) (Interval.bits_needed b.interval)
  in
  let c = Field.compare ~bit_length a.value b.value in
  { value= Field.if_ c.less_or_equal ~then_:a.value ~else_:b.value
  ; interval= Interval.min a.interval b.interval
  ; bits= None }

let if_ (type f) ~m:((module M) : f m) cond ~then_ ~else_ =
  { value= M.Field.if_ cond ~then_:then_.value ~else_:else_.value
  ; interval= Interval.lub then_.interval else_.interval
  ; bits= None }

let succ_if (type f) ~m:((module M) as m : f m) t (cond : f Cvar.t Boolean.t) =
  let open M in
  { value= Field.(add (cond :> t) t.value)
  ; interval= Interval.(lub t.interval (succ ~m t.interval))
  ; bits= None }

let succ (type f) ~m:((module M) as m : f m) t =
  let open M in
  { value= Field.(add one t.value)
  ; interval= Interval.succ ~m t.interval
  ; bits= None }

let equal (type f) ~m:((module M) : f m) a b = M.Field.equal a.value b.value

let max_bits a b =
  Int.max (Interval.bits_needed a.interval) (Interval.bits_needed b.interval)

let lt (type f) ~m:((module M) : f m) a b =
  (M.Field.compare ~bit_length:(max_bits a b) a.value b.value).less

let lte (type f) ~m:((module M) : f m) a b =
  (M.Field.compare ~bit_length:(max_bits a b) a.value b.value).less_or_equal

let gte (type f) ~m:((module M) as m : f m) a b = M.Boolean.not (lt ~m a b)

let gt (type f) ~m:((module M) as m : f m) a b = M.Boolean.not (lte ~m a b)
