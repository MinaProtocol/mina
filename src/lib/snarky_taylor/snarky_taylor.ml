open Core
open Snarky
open Snark

module B = Bigint

(* 
    Given
    p / q = 0.b1 b2 b3 ...

    2^k p / q = b1 b2 b3 bk . b_{k+1} ...
  *)
let bignum_as_fixed_point k x =
  let p, q = Bignum.(num_as_bigint x, den_as_bigint x) in
  B.(shift_left p k / q)

let bigint_to_field (type f) ~m:((module M) : f m) =
  let open M in
  Fn.compose Bigint.to_field Bigint.of_bignum_bigint

let bigint_of_field (type f) ~m:((module M) : f m) =
  let open M in
  Fn.compose Bigint.to_bignum_bigint Bigint.of_field

let least ~such_that =
  let rec go i =
    if such_that i
    then i
    else go (i + 1)
  in
  go 0

let greatest ~such_that =
  let rec go best i =
    match  such_that i with
    | Some acc -> go (Some acc) (i + 1)
    | None -> Option.value_exn best
  in
  go None 0

let factorial n =
  let rec go acc i =
    if B.(equal zero i)
    then acc
    else go B.(i * acc) B.(i -  one)
  in
  go B.one n

let log ~terms x =
  let open Bignum in
  let a = x - one in
  let open Sequence in
  unfold ~init:(a, 1) ~f:(fun (ai, i) ->
    let t = ai / of_int i in
    Some
      ( (if Int.(i mod 2 = 0) then neg t else t),
       (ai * a, Int.(i + 1))))
  |> Fn.flip take terms
  |> fold ~init:zero ~f:(+)

let terms_needed ~derivative_upper_bound ~bits_of_precision:k =
  (*
      We want the least n such that

      (n + 1)! / sup |f^(n+1)(x)|  > 2^k
  *)
  let lower_bound = Bignum.of_bigint B.(pow (of_int 2) k) in
  least ~such_that:(fun n ->
    let nn = B.of_int n in
    let d = derivative_upper_bound Int.(n + 1) in
    Bignum.(of_bigint (factorial nn) / d > lower_bound )
  )

let ceil_log2 n =
  least ~such_that:(fun i ->
    B.(pow (of_int 2) (of_int i) >= n))

let binary_expansion x =
  assert Bignum.(x < one);
  let two = Bignum.of_int 2 in
  Sequence.unfold
    ~init:(x, Bignum.(one / two)) ~f:(fun (rem, pt) ->
      let b = Bignum.(rem >= pt) in
      let rem = if b then Bignum.(rem - pt) else rem in
      Some (
        b, Bignum.(rem, pt / two)))

module Integer = struct
  type 'f t =
    { value : 'f Cvar.t
    ; upper_bound : B.t (* A strict upper bound *)
    }

  let constant (type f) ~m:((module M) as m : f m) x=
    let open M in
    assert (x < Field.Constant.size);
    { value=
        Field.(constant (bigint_to_field ~m x))
    ; upper_bound = B.(one + x)
    }

  let shift_left (type f) ~m:((module M) as m : f m) t k =
    let open M in
    let two_to_k = B.(one lsl k) in
    let upper_bound = B.(two_to_k * t.upper_bound) in
    assert B.(upper_bound < Field.Constant.size);
    { value = Field.(constant
                (bigint_to_field ~m two_to_k) * t.value)
    ; upper_bound 
    }

  (* The number of bits needed to represent a number < x *)
  let bits_needed x =
    Z.log2up (B.to_zarith_bigint x)

  let of_bits (type f) ~m:((module M) : f m) bs =
    { value = M.Field.project bs
    ; upper_bound = B.((of_int 2) lsl ((List.length bs)))
    }

  let div_mod (type f) ~m:((module M) as m : f m) a b =
    let open M in
    let q, r =
      exists Typ.(field * field)
        ~compute:As_prover.(Let_syntax.(
          let%map a = read_var a.value >>| bigint_of_field ~m
          and b = read_var b.value >>| bigint_of_field ~m
          in
          ( bigint_to_field ~m B.(a / b)
          , bigint_to_field ~m (B.rem a b ))))
    in
    (* Check
       r < b
       a = q * b + r
       q has at most as many bits as a. *)
    let q_bit_length = bits_needed a.upper_bound in
    let _q_bits =
      Field.choose_preimage_var q
        ~length:q_bit_length
    in
    let b_bit_length = bits_needed b.upper_bound in
    let cmp =
      (* TODO: Also check if r is < some value. *)
      Field.compare
        ~bit_length:b_bit_length
        r b.value 
    in
    Boolean.Assert.is_true cmp.less;
    (* This assertion checkes that the multiplication q * b is safe. *)
    assert (q_bit_length + b_bit_length + 1 < Field.Constant.size_in_bits);
    assert_r1cs q b.value Field.(a.value - r);
    ( { value =q; upper_bound = B.(one lsl b_bit_length) }
    , {value=r; upper_bound = b.upper_bound })
end

module Fixed_point = struct
  type 'f t =
    { value : 'f Cvar.t
    ; denominator_bits : int
    }

  let precision t = t.denominator_bits

  let to_bignum (type f) ~m:((module M) as m :  f m) t =
      let open M in
      let d = t.denominator_bits in
      As_prover.(map
                    (read_var t.value) ~f:(fun t ->
        Bignum.(
        of_bigint (bigint_of_field ~m t)
          / of_bigint B.(one lsl d))))

  let mul (type f) ~m:((module I) :  f m) x y =
    let open I in
    let new_denom = x.denominator_bits + y.denominator_bits in
    assert (new_denom < Field.Constant.size_in_bits);
    { value = Field.(x.value * y.value)
    ; denominator_bits = new_denom
    }

  let of_bigint_and_precision (type f) ~m:((module M) as m : f m) n precision =
    assert B.(n < (one lsl precision));
    let open M in
    { value = Field.constant (bigint_to_field ~m n)
    ; denominator_bits = precision
    }

  (* x, x^2, ..., x^n *)
  let powers ~m n x =
    let res = Array.create ~len:n x in
    let rec go acc i =
      if i >= n
      then ()
      else begin
        let acc = mul ~m x acc in
        res.(i) <- acc;
        go acc (i + 1)
      end
    in
    go x 1;
    res

  let pow2 add ~one k =
    let rec go acc i =
      if i = k
      then acc
      else go (add acc acc) (i + 1)
    in
    go one 0

  let add_signed (type f) ~m:((module M) : f m) t1 (sgn, t2) =
    let open M in
    let denominator_bits = max t1.denominator_bits t2.denominator_bits in
    assert (denominator_bits < Field.Constant.size_in_bits);
    let t1, t2 =
      if t1.denominator_bits < t2.denominator_bits
      then (t1, t2)
      else (t2, t1)
    in
    let value =
      let open Field in
      let f =
        match sgn with
        | `Pos -> (+)
        | `Neg -> (-)
      in
      f
        (pow2 add ~one Int.(t2.denominator_bits - t1.denominator_bits) * t1.value)
        t2.value
    in
    { denominator_bits
    ; value
    }

  let add ~m x y = add_signed ~m x (`Pos, y)
  let sub ~m x y = add_signed ~m x (`Neg, y)

  let of_quotient ~m ~precision ~top ~bottom ~top_is_less_than_bottom:() =
    let q, _r =
      Integer.(div_mod ~m (shift_left ~m top precision) bottom)
    in
    { value = q.value
    ; denominator_bits = precision }

  let%test_unit "of-quotient" =
    let module M =Snarky.Snark.Run.Make(Snarky.Backends.Mnt4.Default) in
    let m = ((module M) : M.field m) in
    let gen =
      let open Quickcheck in
      let open Generator.Let_syntax in
      let m = B.((one lsl 32) - one) in
      let%bind a = B.(gen_incl zero (m - one)) in
      let%map b = B.(gen_incl (a + one) m) in
      (a, b)
    in
    Quickcheck.test ~trials:5 gen ~f:(fun (a, b) ->
      let precision=32 in
      let res = 
        assert B.(a < b);
        M.run_and_check (fun () ->
          let t =
            of_quotient ~m ~precision
              ~top:(Integer.constant ~m a)
              ~bottom:(Integer.constant ~m b)
              ~top_is_less_than_bottom:()
            in
          to_bignum ~m t)
        |> Or_error.ok_exn 
      in
      let actual =Bignum.(of_bigint a / of_bigint b) in
      let good = Bignum.(
        abs (res - actual)
        < one / (of_bigint B.(one lsl precision)))
      in
      if not good then begin
        failwithf "got %s, expected %s\n"
          (Bignum.to_string_hum res)
          (Bignum.to_string_hum actual)
          ()
      end)
end

module Params = struct
  type params =
    { total_precision : int
    ; per_term_precision : int
    ; terms_needed : int
    ; coefficients : ([`Neg | `Pos] * B.t) array
    }
end

module Exp (M : Snark_intf.Run) = struct
  open M

  let derivative_upper_bound n ~log_base =
    Bignum.(log_base ** n)

  let terms_needed ~log_base ~bits_of_precision =
    terms_needed
      ~derivative_upper_bound:( derivative_upper_bound ~log_base)
      ~bits_of_precision

  type bit_params =
    { total_precision : int
    ; terms_needed : int
    ; per_term_precision : int
    }

  let bits_possible ~log_base =
    greatest ~such_that:(fun k ->
      let kk = B.of_int k in
      let n = terms_needed ~log_base ~bits_of_precision:kk in
      let per_term_precision = (ceil_log2 (B.of_int n)) + k in
      if n * per_term_precision < Field.Constant.size_in_bits
      then Some
             { per_term_precision
             ; terms_needed = n
             ; total_precision = k }
      else None)

  let m = ((module M) : M.field m)

  let params base =
    let abs_log_base =
      let log_base = log base ~terms:100 in
      assert Bignum.(log_base < zero);
      let r = Bignum.abs log_base in
      assert Bignum.(r < one);
      r
    in
    let { total_precision; terms_needed; per_term_precision } =
      bits_possible ~log_base:abs_log_base
    in
    (* Starts from 1 *)
    let coefficients =
      Array.init terms_needed ~f:(fun i ->
        let i = i + 1 in
        ( (if i mod 2 = 0 then `Neg else `Pos)
        , Bignum.(
            abs_log_base ** i
            /
            of_bigint (factorial (B.of_int i)))
          |> bignum_as_fixed_point per_term_precision
        )
      )
    in
    { Params.total_precision; terms_needed; per_term_precision; coefficients }  

  let one_minus_exp { Params.total_precision=_; terms_needed; per_term_precision; coefficients } x =
      let powers = Fixed_point.powers ~m terms_needed x in
      let term i =
        let (sgn, c) = coefficients.(i) in
        ( sgn, 
          Fixed_point.mul ~m
            (Fixed_point.of_bigint_and_precision ~m c per_term_precision)
            powers.(i) 
        )
      in
      let rec go acc i =
        if i = terms_needed
        then acc
        else
          go (Fixed_point.add_signed ~m acc (term i)) (i + 1)
      in
      match term 0 with
      | (`Pos, term0) ->
        go term0 1
      | (`Neg, _) -> assert false

  let%test_unit "works" =
    let c () =
      let params = params Bignum.(one / of_int 2) in
      let arg = Fixed_point.of_quotient ~m
                  ~top:(Integer.of_bits ~m Boolean.[true_])
                  ~bottom:(Integer.of_bits ~m Boolean.[false_; true_])
                  ~top_is_less_than_bottom:()
                  ~precision:2
      in
      (Fixed_point.to_bignum ~m
         (one_minus_exp params arg) )
    in
    (M.run_and_check c)
    |> Or_error.ok_exn |> ignore
end

let%test_unit "instantiate" =
  let module M = Exp(Snarky.Snark.Run.Make(Snarky.Backends.Mnt4.Default)) in
  ()

