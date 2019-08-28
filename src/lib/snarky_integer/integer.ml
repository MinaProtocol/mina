open Core
open Snarky
open Snark
open Util
open Bitstring_lib

type 'f t =
  { value: 'f Cvar.t
  ; upper_bound: B.t (* A strict upper bound *)
  ; mutable bits: 'f Cvar.t Boolean.t list option }

let create ~value ~upper_bound = {value; upper_bound; bits= None}

let to_field t = t.value

(* The number of bits needed to represent a number < x *)
let bits_needed x = Z.log2up (B.to_zarith_bigint x)

let constant (type f) ~m:((module M) as m : f m) x =
  let open M in
  assert (x < Field.size) ;
  let upper_bound = B.(one + x) in
  { value= Field.(constant (bigint_to_field ~m x))
  ; upper_bound
  ; bits=
      Some
        (List.init (bits_needed upper_bound) ~f:(fun i ->
             Boolean.var_of_value B.(shift_right x i land one = one) )) }

let shift_left (type f) ~m:((module M) as m : f m) t k =
  let open M in
  let two_to_k = B.(one lsl k) in
  let upper_bound = B.(two_to_k * t.upper_bound) in
  assert (B.(upper_bound < Field.size)) ;
  { value= Field.(constant (bigint_to_field ~m two_to_k) * t.value)
  ; upper_bound
  ; bits=
      Option.map t.bits ~f:(fun bs ->
          List.init k ~f:(fun _ -> Boolean.false_) @ bs ) }

let of_bits (type f) ~m:((module M) : f m) bs =
  let bs = Bitstring.Lsb_first.to_list bs in
  { value= M.Field.project bs
  ; upper_bound= B.(one lsl List.length bs)
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
  let q_bit_length = bits_needed a.upper_bound in
  let q_bits = Field.choose_preimage_var q ~length:q_bit_length in
  let b_bit_length = bits_needed b.upper_bound in
  let r_bits = Field.choose_preimage_var r ~length:b_bit_length in
  let cmp = Field.compare ~bit_length:b_bit_length r b.value in
  Boolean.Assert.is_true cmp.less ;
  (* This assertion checkes that the multiplication q * b is safe. *)
  assert (q_bit_length + b_bit_length + 1 < Field.Constant.size_in_bits) ;
  assert_r1cs q b.value Field.(a.value - r) ;
  ( {value= q; upper_bound= B.(one lsl q_bit_length); bits= Some q_bits}
  , {value= r; upper_bound= b.upper_bound; bits= Some r_bits} )

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
          ~length:(Option.value ~default:(bits_needed t.upper_bound) length)
      in
      t.bits <- Some bs ;
      Bitstring.Lsb_first.of_list bs

let to_bits_exn t = Bitstring.Lsb_first.of_list (Option.value_exn t.bits)

let min (type f) ~m:((module M) : f m) (a : f t) (b : f t) =
  let open M in
  let bit_length =
    Int.max (bits_needed a.upper_bound) (bits_needed b.upper_bound)
  in
  let c = Field.compare ~bit_length a.value b.value in
  { value= Field.if_ c.less_or_equal ~then_:a.value ~else_:b.value
  ; upper_bound= B.min a.upper_bound b.upper_bound
  ; bits= None }

let if_ (type f) ~m:((module M) : f m) cond ~then_ ~else_ =
  { value= M.Field.if_ cond ~then_:then_.value ~else_:else_.value
  ; upper_bound= B.max then_.upper_bound else_.upper_bound
  ; bits= None }

let succ_if (type f) ~m:((module M) : f m) t (cond : f Cvar.t Boolean.t) =
  let open M in
  { value= Field.(add (cond :> t) t.value)
  ; upper_bound= B.(one + t.upper_bound)
  ; bits= None }

let succ (type f) ~m:((module M) : f m) t =
  let open M in
  { value= Field.(add one t.value)
  ; upper_bound= B.(one + t.upper_bound)
  ; bits= None }

let equal (type f) ~m:((module M) : f m) a b = M.Field.equal a.value b.value

let lt (type f) ~m:((module M) : f m) a b =
  let bit_length =
    Int.max (bits_needed a.upper_bound) (bits_needed b.upper_bound)
  in
  (M.Field.compare ~bit_length a.value b.value).less

let lte (type f) ~m:((module M) : f m) a b =
  let bit_length =
    Int.max (bits_needed a.upper_bound) (bits_needed b.upper_bound)
  in
  (M.Field.compare ~bit_length a.value b.value).less_or_equal

let gte (type f) ~m:((module M) as m : f m) a b = M.Boolean.not (lt ~m a b)

let gt (type f) ~m:((module M) as m : f m) a b = M.Boolean.not (lte ~m a b)
