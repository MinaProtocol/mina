open Marlin_plonk_bindings
open Js_of_ocaml

(* NOTE: For nodejs, we need to manually add the following line to the javascript bindings, after imports['env'] has been declared.
imports['env']['memory'] = new WebAssembly.Memory({initial: 18, maximum: 16384, shared: true});
*)

type a = { a : int; b : bool; c : int option option }

type b = A | B | C | D | Aplus of b | Bplus of int | Cplus of bool

let _ =
  Js.export "testing"
    (object%js (_self)
       method a = { a = 15; b = true; c = Some (Some 125) }

       method b = { a = 20; b = false; c = Some None }

       method c = { a = 25; b = false; c = None }

       method create i =
         match i with
         | 0 ->
             A
         | 1 ->
             B
         | 2 ->
             C
         | 3 ->
             D
         | 4 ->
             Aplus A
         | 5 ->
             Aplus (Aplus (Aplus (Bplus 15)))
         | 6 ->
             Bplus 20
         | 7 ->
             Cplus true
         | _ ->
             A

       method returnString = "String"

       method returnString2 =
         String.concat "" [ "String1"; "String2"; "String3" ]

       method returnBytes = Bytes.of_string "Bytes"

       method returnStringAll =
         let bytes = Bytes.make 256 ' ' in
         let rec go i =
           if i < 256 then (
             Bytes.set bytes i (Char.chr i) ;
             go (i + 1) )
         in
         go 0 ; Bytes.to_string bytes

       method bytesOfJsString x = Js.to_string x |> Bytes.of_string

       method bytesToJsString x = Bytes.to_string x |> Js.string
    end)

let _ =
  let open Bigint_256 in
  Js.export "bigint_256"
    (object%js (_self)
       method ofNumeral x _len base = of_numeral x _len base

       method ofDecimalString x = of_decimal_string x

       method numLimbs = num_limbs ()

       method bytesPerLimb = bytes_per_limb ()

       method div x y = div x y

       method compare x y = compare x y

       method print x = print x

       method toString x = to_string x

       method testBit x i = test_bit x i

       method toBytes x = to_bytes x

       method ofBytes x = of_bytes x

       method deepCopy x = deep_copy x
    end)

let _ =
  let open Pasta_fp in
  Js.export "pasta_fp"
    (object%js (_self)
       method sizeInBits = size_in_bits ()

       method size = size ()

       method add x y = add x y

       method sub x y = sub x y

       method negate x = negate x

       method mul x y = mul x y

       method div x y = div x y

       method inv x = inv x

       method square x = square x

       method sqrt x = sqrt x

       method ofInt x = of_int x

       method toString x = to_string x

       method ofString x = of_string x

       method print x = print x

       method copy x y = copy ~over:x y

       method mutAdd x y = mut_add x ~other:y

       method mutSub x y = mut_sub x ~other:y

       method mutMul x y = mut_sub x ~other:y

       method mutSquare x = mut_square x

       method compare x y = compare x y

       method equal x y = equal x y

       method random = random ()

       method rng i = rng i

       method toBigint x = to_bigint x

       method ofBigint x = of_bigint x

       method twoAdicRootOfUnity = two_adic_root_of_unity ()

       method domainGenerator i = domain_generator i

       method toBytes x = to_bytes x

       method ofBytes x = of_bytes x

       method deepCopy x = deep_copy x
    end)

let _ =
  let open Pasta_fq in
  Js.export "pasta_fq"
    (object%js (_self)
       method sizeInBits = size_in_bits ()

       method size = size ()

       method add x y = add x y

       method sub x y = sub x y

       method negate x = negate x

       method mul x y = mul x y

       method div x y = div x y

       method inv x = inv x

       method square x = square x

       method sqrt x = sqrt x

       method ofInt x = of_int x

       method toString x = to_string x

       method ofString x = of_string x

       method print x = print x

       method copy x y = copy ~over:x y

       method mutAdd x y = mut_add x ~other:y

       method mutSub x y = mut_sub x ~other:y

       method mutMul x y = mut_sub x ~other:y

       method mutSquare x = mut_square x

       method compare x y = compare x y

       method equal x y = equal x y

       method random = random ()

       method rng i = rng i

       method toBigint x = to_bigint x

       method ofBigint x = of_bigint x

       method twoAdicRootOfUnity = two_adic_root_of_unity ()

       method domainGenerator i = domain_generator i

       method toBytes x = to_bytes x

       method ofBytes x = of_bytes x

       method deepCopy x = deep_copy x
    end)

let _ =
  let open Bigint_256 in
  Js.export "bigint_256_test"
    (object%js (_self)
       method run =
         let ten = of_numeral "A" 1 16 in
         let two = of_numeral "10" 2 2 in
         let five = of_numeral "5" 1 10 in
         let six = of_decimal_string "6" in
         let num_limbs = num_limbs () in
         let bytes_per_limb = bytes_per_limb () in
         assert (num_limbs * bytes_per_limb * 8 = 256) ;
         let two_again = div ten five in
         assert (compare ten two > 0) ;
         assert (compare two ten < 0) ;
         assert (compare two two = 0) ;
         assert (compare two two_again = 0) ;
         print ten ;
         assert (String.equal (to_string ten) "10") ;
         assert (String.equal (to_string two_again) "2") ;
         assert (test_bit five 0) ;
         assert (not (test_bit five 1)) ;
         assert (test_bit five 2) ;
         let ten_bytes = to_bytes ten in
         assert (compare (of_bytes ten_bytes) ten = 0) ;
         assert (compare (deep_copy six) six = 0)
    end)

let _ =
  let open Pasta_fp in
  Js.export "pasta_fp_test"
    (object%js (_self)
       method run =
         let size_in_bits = size_in_bits () in
         assert (size_in_bits = 255) ;
         let size = size () in
         assert (
           String.equal
             (Bigint_256.to_string size)
             "28948022309329048855892746252171976963363056481941560715954676764349967630337"
         ) ;
         let one = of_int 1 in
         let two = of_string "2" in
         let rand1 = random () in
         let rand2 = rng 15 in
         let ten = of_bigint (Bigint_256.of_decimal_string "10") in
         let eleven = of_bigint (Bigint_256.of_decimal_string "11") in
         let twenty_one = add ten eleven in
         let one_again = sub eleven ten in
         let twenty = mul two ten in
         let five = div ten two in
         assert (String.equal (to_string twenty_one) "21") ;
         assert (String.equal (to_string one_again) "1") ;
         assert (String.equal (to_string twenty) "20") ;
         assert (String.equal (to_string five) "5") ;
         assert (equal (of_string "5") five) ;
         assert (equal (of_string (to_string five)) five) ;
         assert (
           equal twenty_one
             ( match sqrt (square twenty_one) with
             | Some x ->
                 x
             | None ->
                 assert false ) ) ;
         print twenty_one ;
         copy ~over:eleven twenty_one ;
         assert (equal eleven twenty_one) ;
         assert (String.equal (to_string eleven) "21") ;
         mut_add one_again ~other:ten ;
         assert (String.equal (to_string one_again) "11") ;
         mut_sub one_again ~other:one ;
         assert (String.equal (to_string one_again) "10") ;
         mut_mul one_again ~other:ten ;
         assert (String.equal (to_string one_again) "100") ;
         mut_square one_again ;
         assert (String.equal (to_string one_again) "10000") ;
         assert (equal (of_bigint (to_bigint rand1)) rand1) ;
         assert (compare (of_bigint (to_bigint rand1)) rand1 = 0) ;
         assert (compare one ten < 0) ;
         assert (compare ten one > 0) ;
         let root_of_unity = two_adic_root_of_unity () in
         assert (equal (of_bytes (to_bytes root_of_unity)) root_of_unity) ;
         let gen = domain_generator 2 in
         assert (equal (of_bytes (to_bytes gen)) gen) ;
         assert (equal (deep_copy rand2) rand2)
    end)

let _ =
  let open Pasta_fq in
  Js.export "pasta_fq_test"
    (object%js (_self)
       method run =
         let size_in_bits = size_in_bits () in
         assert (size_in_bits = 255) ;
         let size = size () in
         assert (
           String.equal
             (Bigint_256.to_string size)
             "28948022309329048855892746252171976963363056481941647379679742748393362948097"
         ) ;
         let one = of_int 1 in
         let two = of_string "2" in
         let rand1 = random () in
         let rand2 = rng 15 in
         let ten = of_bigint (Bigint_256.of_decimal_string "10") in
         let eleven = of_bigint (Bigint_256.of_decimal_string "11") in
         let twenty_one = add ten eleven in
         let one_again = sub eleven ten in
         let twenty = mul two ten in
         let five = div ten two in
         assert (String.equal (to_string twenty_one) "21") ;
         assert (String.equal (to_string one_again) "1") ;
         assert (String.equal (to_string twenty) "20") ;
         assert (String.equal (to_string five) "5") ;
         assert (equal (of_string "5") five) ;
         assert (equal (of_string (to_string five)) five) ;
         assert (
           equal twenty_one
             ( match sqrt (square twenty_one) with
             | Some x ->
                 x
             | None ->
                 assert false ) ) ;
         print twenty_one ;
         copy ~over:eleven twenty_one ;
         assert (equal eleven twenty_one) ;
         assert (String.equal (to_string eleven) "21") ;
         mut_add one_again ~other:ten ;
         assert (String.equal (to_string one_again) "11") ;
         mut_sub one_again ~other:one ;
         assert (String.equal (to_string one_again) "10") ;
         mut_mul one_again ~other:ten ;
         assert (String.equal (to_string one_again) "100") ;
         mut_square one_again ;
         assert (String.equal (to_string one_again) "10000") ;
         assert (equal (of_bigint (to_bigint rand1)) rand1) ;
         assert (compare (of_bigint (to_bigint rand1)) rand1 = 0) ;
         assert (compare one ten < 0) ;
         assert (compare ten one > 0) ;
         let root_of_unity = two_adic_root_of_unity () in
         assert (equal (of_bytes (to_bytes root_of_unity)) root_of_unity) ;
         let gen = domain_generator 2 in
         assert (equal (of_bytes (to_bytes gen)) gen) ;
         assert (equal (deep_copy rand2) rand2)
    end)

let _ =
  let open Pasta_fp_vector in
  Js.export "pasta_fp_vector_test"
    (object%js (_self)
       method run =
         let first = create () in
         let second = create () in
         assert (length first = 0) ;
         assert (length second = 0) ;
         assert (not (first == second)) ;
         emplace_back first (Pasta_fp.of_int 0) ;
         assert (length first = 1) ;
         assert (length second = 0) ;
         emplace_back second (Pasta_fp.of_int 1) ;
         assert (length first = 1) ;
         assert (length second = 1) ;
         emplace_back first (Pasta_fp.of_int 10) ;
         assert (length first = 2) ;
         assert (length second = 1) ;
         emplace_back first (Pasta_fp.of_int 30) ;
         assert (length first = 3) ;
         assert (length second = 1) ;
         assert (Pasta_fp.equal (Pasta_fp.of_int 0) (get first 0)) ;
         assert (Pasta_fp.equal (Pasta_fp.of_int 10) (get first 1)) ;
         assert (Pasta_fp.equal (Pasta_fp.of_int 30) (get first 2)) ;
         assert (Pasta_fp.equal (Pasta_fp.of_int 1) (get second 0))
    end)

let _ =
  let open Pasta_fq_vector in
  Js.export "pasta_fq_vector_test"
    (object%js (_self)
       method run =
         let first = create () in
         let second = create () in
         assert (length first = 0) ;
         assert (length second = 0) ;
         assert (not (first == second)) ;
         emplace_back first (Pasta_fq.of_int 0) ;
         assert (length first = 1) ;
         assert (length second = 0) ;
         emplace_back second (Pasta_fq.of_int 1) ;
         assert (length first = 1) ;
         assert (length second = 1) ;
         emplace_back first (Pasta_fq.of_int 10) ;
         assert (length first = 2) ;
         assert (length second = 1) ;
         emplace_back first (Pasta_fq.of_int 30) ;
         assert (length first = 3) ;
         assert (length second = 1) ;
         assert (Pasta_fq.equal (Pasta_fq.of_int 0) (get first 0)) ;
         assert (Pasta_fq.equal (Pasta_fq.of_int 10) (get first 1)) ;
         assert (Pasta_fq.equal (Pasta_fq.of_int 30) (get first 2)) ;
         assert (Pasta_fq.equal (Pasta_fq.of_int 1) (get second 0))
    end)
