open Core
open Snarky
open Snark
open Snarky_integer
open Util
module B = Bigint

(* This module is for representing arbitrary precision rationals in the interval
    [0, 1). We represent such a number as an integer [value] and an int [precision].

    The interpretation is that it corresponds to the rational number

    value / 2^precision
*)

type 'f t = {value: 'f Cvar.t; precision: int}

let precision t = t.precision

let to_bignum (type f) ~m:((module M) as m : f m) t =
  let open M in
  let d = t.precision in
  fun () ->
    let t = As_prover.read_var t.value in
    Bignum.(of_bigint (bigint_of_field ~m t) / of_bigint B.(one lsl d))

(*
    x      y        x*y
    ---- * ---- = ---------
    2^px   2^py   2^(px+py)
*)
let mul (type f) ~m:((module I) : f m) x y =
  let open I in
  let new_precision = x.precision + y.precision in
  assert (new_precision < Field.Constant.size_in_bits) ;
  {value= Field.(x.value * y.value); precision= new_precision}

let constant (type f) ~m:((module M) as m : f m) ~value ~precision =
  assert (B.(value < one lsl precision)) ;
  let open M in
  {value= Field.constant (bigint_to_field ~m value); precision}

(* x, x^2, ..., x^n *)
let powers ~m x n =
  let res = Array.create ~len:n x in
  let rec go acc i =
    if i >= n then ()
    else
      let acc = mul ~m x acc in
      res.(i) <- acc ;
      go acc (i + 1)
  in
  go x 1 ; res

let pow2 add ~one k =
  let rec go acc i = if i = k then acc else go (add acc acc) (i + 1) in
  go one 0

(*
    Say px <= py.

    x      y     2^(py-px) x + y
    ---- + ---- = ---------------
    2^px   2^py        2^py
*)
let add_signed (type f) ~m:((module M) : f m) t1 (sgn, t2) =
  let open M in
  let precision = max t1.precision t2.precision in
  assert (precision < Field.Constant.size_in_bits) ;
  let t1, t2 = if t1.precision < t2.precision then (t1, t2) else (t2, t1) in
  let value =
    let open Field in
    let f = match sgn with `Pos -> ( + ) | `Neg -> ( - ) in
    f (pow2 add ~one Int.(t2.precision - t1.precision) * t1.value) t2.value
  in
  {precision; value}

let add ~m x y = add_signed ~m x (`Pos, y)

let sub ~m x y = add_signed ~m x (`Neg, y)

let le (type f) ~m:((module M) : f m) t1 t2 =
  let open M in
  let precision = max t1.precision t2.precision in
  assert (precision < Field.Constant.size_in_bits) ;
  let padding =
    let k = precision - min t1.precision t2.precision in
    let open Field in
    constant (pow2 Constant.add ~one:Constant.one k)
  in
  let x1, x2 =
    let open Field in
    let x1, x2 = (t1.value, t2.value) in
    if t1.precision < t2.precision then (padding * x1, x2)
    else if t2.precision < t1.precision then (x1, padding * x2)
    else (x1, x2)
  in
  (Field.compare ~bit_length:precision x1 x2).less_or_equal

(*
    Compute the truncated fixed point representation of the quotient top / bottom.

    This uses the fact that if

    top
    -----  = 0.b1 ... bk b_{k+1} ...
    bottom

    then

    2^k top
    ------- = b1 ... bk.b_{k+1} ...
    bottom

    so we can compute the first k bits of the binary expansion of
    top / bottom as floor(2^k * top / bottom).
*)
let of_quotient ~m ~precision ~top ~bottom ~top_is_less_than_bottom:() =
  let q, _r = Integer.(div_mod ~m (shift_left ~m top precision) bottom) in
  {value= Integer.to_field q; precision}

let of_bits (type f) ~m:((module M) : f m) bits ~precision =
  assert (List.length bits <= precision) ;
  {value= M.Field.pack bits; precision}
