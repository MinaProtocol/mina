module Bignum_bigint = Bigint
open Core_kernel

let pow2 n = Bignum_bigint.(pow (of_int 2) (of_int n))

let bigint_num_bits =
  let rec go acc i =
    if Bignum_bigint.(acc = zero) then i
    else go (Bignum_bigint.shift_right acc 1) (i + 1)
  in
  fun n -> go n 0

module Make (Impl : Snark_intf.Basic) = struct
  open Impl
  open Let_syntax

  type t =
    { upper_bound: Bignum_bigint.t
    ; lower_bound: Bignum_bigint.t
    ; var: Field.Var.t
    ; bits: Boolean.var list option }

  let two_to_the n =
    let rec go acc i =
      if i <= 0 then acc else go (Field.add acc acc) (i - 1)
    in
    go Field.one n

  let to_bits {var; bits; upper_bound; lower_bound= _} =
    let length = bigint_num_bits upper_bound in
    with_label "Number.to_bits"
      ( match bits with
      | Some bs -> return (List.take bs length)
      | None -> Field.Checked.unpack var ~length )

  let of_bits bs =
    let n = List.length bs in
    assert (n < Field.size_in_bits) ;
    { upper_bound= Bignum_bigint.(pow2 n - one)
    ; lower_bound= Bignum_bigint.zero
    ; var= Field.Checked.pack bs
    ; bits= Some bs }

  let mul_pow_2 n (`Two_to_the k) =
    let%map bits = to_bits n in
    let multiplied = List.init k ~f:(fun _ -> Boolean.false_) @ bits in
    let upper_bound =
      Bignum_bigint.(n.upper_bound * pow (of_int 2) (of_int k))
    in
    assert (Bignum_bigint.(upper_bound < Field.size)) ;
    { upper_bound
    ; lower_bound= Bignum_bigint.(n.lower_bound * pow (of_int 2) (of_int k))
    ; var= Field.Checked.pack multiplied
    ; bits= Some multiplied }

  let div_pow_2 n (`Two_to_the k) =
    let%map bits = to_bits n in
    let divided = List.drop bits k in
    let divided_of_bits = of_bits divided in
    { upper_bound=
        Bignum_bigint.(divided_of_bits.upper_bound / pow (of_int 2) (of_int k))
    ; lower_bound=
        Bignum_bigint.(divided_of_bits.lower_bound / pow (of_int 2) (of_int k))
    ; var= divided_of_bits.var
    ; bits= divided_of_bits.bits }

  let clamp_to_n_bits t n =
    assert (n < Field.size_in_bits) ;
    with_label "Number.clamp_to_n_bits"
      (let k = pow2 n in
       if Bignum_bigint.(t.upper_bound < k) then return t
       else
         let%bind bs = to_bits t in
         let bs' = List.take bs n in
         let g = Field.Checked.project bs' in
         let%bind fits = Field.Checked.equal t.var g in
         let%map r =
           Field.Checked.if_ fits ~then_:g
             ~else_:(Field.Var.constant Field.(sub (two_to_the n) one))
         in
         { upper_bound= Bignum_bigint.(k - one)
         ; lower_bound= t.lower_bound
         ; var= r
         ; bits= None })

  let ( < ) x y =
    let open Bignum_bigint in
    (*
      x [ ]
      y     [ ]

      x     [ ]
      y [ ] 
    *)
    with_label "Number.(<)"
      ( if x.upper_bound < y.lower_bound then return Boolean.true_
      else if x.lower_bound >= y.upper_bound then return Boolean.false_
      else
        let bit_length =
          Int.max
            (bigint_num_bits x.upper_bound)
            (bigint_num_bits y.upper_bound)
        in
        let%map {less; _} = Field.Checked.compare ~bit_length x.var y.var in
        less )

  let ( <= ) x y =
    let open Bignum_bigint in
    (*
      x [ ]
      y   [ ]

      x     [ ]
      y [ ] 
    *)
    with_label "Number.(<)"
      ( if x.upper_bound <= y.lower_bound then return Boolean.true_
      else if x.lower_bound > y.upper_bound then return Boolean.false_
      else
        let bit_length =
          Int.max
            (bigint_num_bits x.upper_bound)
            (bigint_num_bits y.upper_bound)
        in
        let%map {less; _} = Field.Checked.compare ~bit_length x.var y.var in
        less )

  let ( > ) x y = y < x

  let ( >= ) x y = y <= x

  let ( = ) x y =
    (* TODO: Have "short circuiting" for efficiency as above. *)
    Field.Checked.equal x.var y.var

  let to_var {var; _} = var

  let constant x =
    let tick_n = Bigint.of_field x in
    let n = Bigint.to_bignum_bigint tick_n in
    { upper_bound= n
    ; lower_bound= n
    ; var= Field.Var.constant x
    ; bits=
        Some
          (List.init (bigint_num_bits n) ~f:(fun i ->
               Boolean.var_of_value (Bigint.test_bit tick_n i) )) }

  let one = constant Field.one

  let zero = constant Field.zero

  let of_pow_2 (`Two_to_the k) = constant (Field.of_int (Int.pow 2 k))

  let if_ b ~then_ ~else_ =
    let%map var = Field.Checked.if_ b ~then_:then_.var ~else_:else_.var in
    let open Bignum_bigint in
    { upper_bound= max then_.upper_bound else_.upper_bound
    ; lower_bound= min then_.lower_bound else_.lower_bound
    ; var
    ; bits= None }

  let ( + ) x y =
    let open Bignum_bigint in
    let upper_bound = x.upper_bound + y.upper_bound in
    if upper_bound < Field.size then
      { upper_bound
      ; lower_bound= x.lower_bound + y.lower_bound
      ; var= Field.Var.add x.var y.var
      ; bits= None }
    else
      failwithf "Number.+: Potential overflow: (%s + %s > Field.size)"
        (to_string x.upper_bound) (to_string y.upper_bound) ()

  let ( - ) x y =
    let open Bignum_bigint in
    (* x_upper_bound >= x >= x_lower_bound >= y_upper_bound >= y >= y_lower_bound *)
    if x.lower_bound >= y.upper_bound then
      { upper_bound= x.upper_bound - y.lower_bound
      ; lower_bound= x.lower_bound - y.upper_bound
      ; var= Field.Var.sub x.var y.var
      ; bits= None }
    else
      failwithf "Number.-: Potential underflow (%s < %s)"
        (to_string x.lower_bound) (to_string y.upper_bound) ()

  let ( * ) x y =
    let open Bignum_bigint in
    with_label "Number.(*)"
      (let upper_bound = x.upper_bound * y.upper_bound in
       if upper_bound < Field.size then
         let%map var = Field.Checked.mul x.var y.var in
         { upper_bound
         ; lower_bound= x.lower_bound * y.lower_bound
         ; var
         ; bits= None }
       else
         failwithf "Number.*: Potential overflow: (%s * %s > Field.size)"
           (to_string x.upper_bound) (to_string y.upper_bound) ())

  let min x y =
    let%bind less = x < y in
    if_ less ~then_:x ~else_:y

  let max x y =
    let%bind less = x < y in
    if_ less ~then_:y ~else_:x
end
