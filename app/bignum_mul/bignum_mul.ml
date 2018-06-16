open Core

type t = int array

let two_to_the_15 = 32768

let info_per_limb = 15

let len ~max_bits : int =
  (max_bits / info_per_limb) + if max_bits % info_per_limb <> 0 then 1 else 0

let alloc ~max_bits () = Array.init (len ~max_bits) ~f:(fun _ -> 0)

let of_int15 ~max_bits x =
  assert (x < two_to_the_15) ;
  let t = alloc ~max_bits () in
  t.(0) <- x ; t

let gen ~max_bits =
  let open Quickcheck.Generator in
  list_with_length (len ~max_bits) Int.(gen_incl 0 (two_to_the_15 - 1))
  >>| Array.of_list

let to_bigint =
  Array.foldi ~init:Bigint.zero ~f:(fun i acc x ->
      Bigint.(acc + (of_int x * pow (of_int two_to_the_15) (of_int i))) )

let mul a b : t =
  assert (Array.length a = Array.length b) ;
  let res = alloc ~max_bits:(info_per_limb * Array.length a * 2) () in
  let rec go i carry =
    if i = Array.length b then ()
    else
      let go'_stop = Array.length a + i in
      let rec go' j carry =
        if j = go'_stop then carry
        else
          let digit = res.(j) + (b.(i) * a.(j - i)) + carry in
          let carry = digit / two_to_the_15 in
          res.(j) <- digit % two_to_the_15 ;
          go' (j + 1) carry
      in
      let carry = go' i carry in
      let carry =
        if carry <> 0 then (
          let digit = res.(go'_stop) + carry in
          res.(go'_stop) <- digit % two_to_the_15 ;
          let carry = digit / two_to_the_15 in
          carry )
        else carry
      in
      go (i + 1) carry
  in
  go 0 0 ; res

let () =
  let size = 768 in
  (* Limbs are 15bits each, so we'll need 52 of them for a 768 bit number *)
  assert (len size = 52) ;
  (* Make sure bigint conversion is sane *)
  assert (
    Bigint.( = ) (to_bigint (of_int15 ~max_bits:size 4)) (Bigint.of_int 4) ) ;
  (* Quickcheck the shit out of multiplication *)
  Quickcheck.test ~trials:100000
    ~sexp_of:[%sexp_of : int Array.t * int Array.t]
    (Quickcheck.Generator.tuple2 (gen ~max_bits:size) (gen ~max_bits:size))
    ~f:(fun (a, b) ->
      let work = mul a b |> to_bigint in
      let expected = Bigint.( * ) (to_bigint a) (to_bigint b) in
      assert (Bigint.( = ) work expected) ) ;
  printf "All tests passed\n"
