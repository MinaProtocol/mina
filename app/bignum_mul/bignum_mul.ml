open Core

type t = Int64.t array

let two_to_the_30 = Int64.of_int 1073741824

let info_per_limb = 30

let len ~max_bits : int =
  (max_bits / info_per_limb) + if max_bits % info_per_limb <> 0 then 1 else 0

let alloc ~max_bits () = Array.init (len ~max_bits) ~f:(fun _ -> Int64.zero)

let of_int30 ~max_bits x =
  let x = Int64.of_int x in
  assert (Int64.( < ) x two_to_the_30) ;
  let t = alloc ~max_bits () in
  t.(0) <- x ; t

let gen ~max_bits =
  let open Quickcheck.Generator in
  list_with_length (len ~max_bits) Int64.(gen_incl zero (two_to_the_30 - one))
  >>| Array.of_list

let zero ~max_bits = Array.init (len ~max_bits) ~f:(fun _ -> 0)

let to_bigint =
  Array.foldi ~init:Bigint.zero ~f:(fun i acc x ->
      Bigint.(acc + (of_int64 x * pow (of_int64 two_to_the_30) (of_int i))) )

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
          let open Int64 in
          let digit = res.(j) + (b.(i) * a.(Int.( - ) j i)) + carry in
          let carry = digit / two_to_the_30 in
          res.(j) <- digit % two_to_the_30 ;
          go' (Int.( + ) j 1) carry
      in
      let carry = go' i carry in
      let carry =
        let open Int64 in
        if Int64.( <> ) carry Int64.zero then (
          let digit = res.(go'_stop) + carry in
          res.(go'_stop) <- digit % two_to_the_30 ;
          let carry = digit / two_to_the_30 in
          carry )
        else carry
      in
      go (i + 1) carry
  in
  go 0 Int64.zero ; res

let () =
  let size = 768 in
  (* Limbs are 30bits each, so we'll need 26 of them for a 768 bit number *)
  assert (len size = 26) ;
  (* Make sure bigint conversion is sane *)
  assert (
    Bigint.( = ) (to_bigint (of_int30 ~max_bits:size 4)) (Bigint.of_int 4) ) ;
  (* Quickcheck the shit out of multiplication *)
  Quickcheck.test ~trials:100000
    ~sexp_of:[%sexp_of : Int64.t Array.t * Int64.t Array.t]
    (Quickcheck.Generator.tuple2 (gen ~max_bits:size) (gen ~max_bits:size))
    ~f:(fun (a, b) ->
      let work = mul a b |> to_bigint in
      let expected = Bigint.( * ) (to_bigint a) (to_bigint b) in
      assert (Bigint.( = ) work expected) ) ;
  printf "All tests passed\n"
