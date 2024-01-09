open Kimchi_types
open Pasta_bindings
open Kimchi_bindings
open Js_of_ocaml
module Bigint_256 = BigInt256
module Pasta_fp = Fp
module Pasta_fq = Fq
module Pasta_fp_vector = FieldVectors.Fp
module Pasta_fq_vector = FieldVectors.Fq
module Pasta_pallas = Pallas
module Pasta_vesta = Vesta
module Pasta_fp_urs = Protocol.SRS.Fp
module Pasta_fq_urs = Protocol.SRS.Fq
module Pasta_fp_index = Protocol.Index.Fp
module Pasta_fq_index = Protocol.Index.Fq
module Pasta_fp_verifier_index = Protocol.VerifierIndex.Fp
module Pasta_fq_verifier_index = Protocol.VerifierIndex.Fq

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
    end )

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
    end )

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

       method copy x y = copy x y

       method mutAdd x y = mut_add x y

       method mutSub x y = mut_sub x y

       method mutMul x y = mut_sub x y

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
    end )

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

       method copy x y = copy x y

       method mutAdd x y = mut_add x y

       method mutSub x y = mut_sub x y

       method mutMul x y = mut_sub x y

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
    end )

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
    end )

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
             "28948022309329048855892746252171976963363056481941560715954676764349967630337" ) ;
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
         copy eleven twenty_one ;
         assert (equal eleven twenty_one) ;
         assert (String.equal (to_string eleven) "21") ;
         mut_add one_again ten ;
         assert (String.equal (to_string one_again) "11") ;
         mut_sub one_again one ;
         assert (String.equal (to_string one_again) "10") ;
         mut_mul one_again ten ;
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
    end )

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
             "28948022309329048855892746252171976963363056481941647379679742748393362948097" ) ;
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
         copy eleven twenty_one ;
         assert (equal eleven twenty_one) ;
         assert (String.equal (to_string eleven) "21") ;
         mut_add one_again ten ;
         assert (String.equal (to_string one_again) "11") ;
         mut_sub one_again one ;
         assert (String.equal (to_string one_again) "10") ;
         mut_mul one_again ten ;
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
    end )

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
    end )

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
    end )

let eq_affine ~field_equal x y =
  match (x, y) with
  | Infinity, Infinity ->
      true
  | Finite (x1, y1), Finite (x2, y2) ->
      field_equal x1 x2 && field_equal y1 y2
  | _ ->
      false

let _ =
  let open Pasta_pallas in
  Js.export "pasta_pallas_test"
    (object%js (_self)
       method run =
         let eq x y = eq_affine ~field_equal:Pasta_fp.equal x y in
         let one_ = one () in
         let two = add one_ one_ in
         let infinity = sub one_ one_ in
         let one_again = sub two one_ in
         let neg_one = negate one_ in
         let two_again = double one_ in
         let two_again_ = scale one_ (Pasta_fq.of_int 2) in
         let rand1 = random () in
         let rand2 = rng 15 in
         let affine_one = to_affine one_ in
         let affine_two = to_affine two in
         assert (not (eq affine_one affine_two)) ;
         let affine_infinity = to_affine infinity in
         assert (not (eq affine_one affine_infinity)) ;
         assert (not (eq affine_two affine_infinity)) ;
         assert (eq affine_infinity Infinity) ;
         let affine_neg_one = to_affine neg_one in
         assert (not (eq affine_one affine_neg_one)) ;
         assert (not (eq affine_two affine_neg_one)) ;
         assert (not (eq affine_infinity affine_neg_one)) ;
         let affine_one_again = to_affine one_again in
         assert (eq affine_one affine_one_again) ;
         let affine_two_again = to_affine two_again in
         assert (eq affine_two affine_two_again) ;
         let affine_two_again_ = to_affine two_again_ in
         assert (eq affine_two affine_two_again_) ;
         let affine_rand1 = to_affine rand1 in
         let affine_rand2 = to_affine rand2 in
         let copy_using_of_affine_coordinates pt =
           match pt with
           | Infinity ->
               of_affine Infinity
           | Finite (x, y) ->
               of_affine_coordinates x y
         in
         let rand1_again = copy_using_of_affine_coordinates affine_rand1 in
         let rand2_again = copy_using_of_affine_coordinates affine_rand2 in
         let affine_rand1_again = to_affine rand1_again in
         let affine_rand2_again = to_affine rand2_again in
         ( match
             ( eq affine_rand1 affine_rand2
             , eq affine_rand1_again affine_rand2_again )
           with
         | true, true | false, false ->
             ()
         | _ ->
             assert false ) ;
         assert (eq affine_rand1 affine_rand1_again) ;
         assert (eq affine_rand2 affine_rand2_again) ;
         assert (
           eq
             (to_affine (negate (sub rand1 rand2)))
             (to_affine (sub rand2_again rand1_again)) ) ;
         let endo_base = endo_base () in
         assert (
           String.equal
             (Pasta_fp.to_string endo_base)
             "20444556541222657078399132219657928148671392403212669005631716460534733845831" ) ;
         let endo_scalar = endo_scalar () in
         assert (
           String.equal
             (Pasta_fq.to_string endo_scalar)
             "26005156700822196841419187675678338661165322343552424574062261873906994770353" ) ;
         let one_copied = deep_copy affine_one in
         assert (eq affine_one one_copied) ;
         let infinity_copied = deep_copy affine_infinity in
         assert (eq affine_infinity infinity_copied) ;
         assert (eq affine_infinity Infinity) ;
         let infinity_copied_ = deep_copy Infinity in
         assert (eq infinity_copied_ Infinity)
    end )

let _ =
  let open Pasta_vesta in
  Js.export "pasta_vesta_test"
    (object%js (_self)
       method run =
         let eq x y = eq_affine ~field_equal:Pasta_fq.equal x y in
         let one_ = one () in
         let two = add one_ one_ in
         let infinity = sub one_ one_ in
         let one_again = sub two one_ in
         let neg_one = negate one_ in
         let two_again = double one_ in
         let two_again_ = scale one_ (Pasta_fp.of_int 2) in
         let rand1 = random () in
         let rand2 = rng 15 in
         let affine_one = to_affine one_ in
         let affine_two = to_affine two in
         assert (not (eq affine_one affine_two)) ;
         let affine_infinity = to_affine infinity in
         assert (not (eq affine_one affine_infinity)) ;
         assert (not (eq affine_two affine_infinity)) ;
         assert (eq affine_infinity Infinity) ;
         let affine_neg_one = to_affine neg_one in
         assert (not (eq affine_one affine_neg_one)) ;
         assert (not (eq affine_two affine_neg_one)) ;
         assert (not (eq affine_infinity affine_neg_one)) ;
         let affine_one_again = to_affine one_again in
         assert (eq affine_one affine_one_again) ;
         let affine_two_again = to_affine two_again in
         assert (eq affine_two affine_two_again) ;
         let affine_two_again_ = to_affine two_again_ in
         assert (eq affine_two affine_two_again_) ;
         let affine_rand1 = to_affine rand1 in
         let affine_rand2 = to_affine rand2 in
         let copy_using_of_affine_coordinates pt =
           match pt with
           | Infinity ->
               of_affine Infinity
           | Finite (x, y) ->
               of_affine_coordinates x y
         in
         let rand1_again = copy_using_of_affine_coordinates affine_rand1 in
         let rand2_again = copy_using_of_affine_coordinates affine_rand2 in
         let affine_rand1_again = to_affine rand1_again in
         let affine_rand2_again = to_affine rand2_again in
         ( match
             ( eq affine_rand1 affine_rand2
             , eq affine_rand1_again affine_rand2_again )
           with
         | true, true | false, false ->
             ()
         | _ ->
             assert false ) ;
         assert (eq affine_rand1 affine_rand1_again) ;
         assert (eq affine_rand2 affine_rand2_again) ;
         assert (
           eq
             (to_affine (negate (sub rand1 rand2)))
             (to_affine (sub rand2_again rand1_again)) ) ;
         let endo_base = endo_base () in
         assert (
           String.equal
             (Pasta_fq.to_string endo_base)
             "2942865608506852014473558576493638302197734138389222805617480874486368177743" ) ;
         let endo_scalar = endo_scalar () in
         assert (
           String.equal
             (Pasta_fp.to_string endo_scalar)
             "8503465768106391777493614032514048814691664078728891710322960303815233784505" ) ;
         let one_copied = deep_copy affine_one in
         assert (eq affine_one one_copied) ;
         let infinity_copied = deep_copy affine_infinity in
         assert (eq affine_infinity infinity_copied) ;
         assert (eq affine_infinity Infinity) ;
         let infinity_copied_ = deep_copy Infinity in
         assert (eq infinity_copied_ Infinity)
    end )

let eq_poly_comm ~field_equal (x : _ poly_comm) (y : _ poly_comm) =
  Array.for_all2 (eq_affine ~field_equal) x.unshifted y.unshifted
  && Option.equal (eq_affine ~field_equal) x.shifted y.shifted

module Backend = Kimchi_backend.Pasta.Pallas_based_plonk

let () = Backend.Keypair.set_urs_info []

module Impl =
  Snarky_backendless.Snark.Run.Make (Kimchi_backend.Pasta.Pallas_based_plonk)

let _ =
  Js.export "snarky_test"
    (object%js (_self)
       method run =
         let log x = (Js.Unsafe.js_expr "console.log" : _ -> unit) x in
         let time label f =
           let start = new%js Js_of_ocaml.Js.date_now in
           let x = f () in
           let stop = new%js Js_of_ocaml.Js.date_now in
           log
             (Core_kernel.ksprintf Js.string "%s: %f seconds" label
                ((stop##getTime -. start##getTime) /. 1000.) ) ;
           x
         in
         let open Impl in
         let main x () =
           let rec go i acc =
             if i = 0 then acc else go (i - 1) (Field.mul acc acc)
           in
           let _ = go 1000 x in
           ()
         in
         let (pk : Backend.Keypair.t) =
           time "generate_keypair" (fun () ->
               constraint_system ~input_typ:Typ.field ~return_typ:Typ.unit main
               |> Backend.Keypair.create ~prev_challenges:0 )
         in
         let (_ : Backend.Keypair.t) =
           time "generate_keypair2" (fun () ->
               constraint_system ~input_typ:Typ.field ~return_typ:Typ.unit main
               |> Backend.Keypair.create ~prev_challenges:0 )
         in
         let x = Backend.Field.of_int 2 in
         let (pi : Backend.Proof.with_public_evals) =
           time "generate witness conv" (fun () ->
               Impl.generate_witness_conv ~input_typ:Typ.field
                 ~return_typ:Typ.unit main
                 ~f:(fun { Proof_inputs.auxiliary_inputs; public_inputs } () ->
                   time "create proof" (fun () ->
                       Backend.Proof.create pk ~auxiliary:auxiliary_inputs
                         ~primary:public_inputs ) )
                 x )
         in
         let vk = Backend.Keypair.vk pk in
         let vec = Backend.Field.Vector.create () in
         Backend.Field.Vector.emplace_back vec x ;
         assert (time "verify proof" (fun () -> Backend.Proof.verify pi vk vec))
    end )

let _ =
  let open Pasta_fp_urs in
  Js.export "pasta_fp_urs_test"
    (object%js (_self)
       method run =
         (let time label f =
            let start = new%js Js_of_ocaml.Js.date_now in
            let x = f () in
            let stop = new%js Js_of_ocaml.Js.date_now in
            let log x = (Js.Unsafe.js_expr "console.log" : _ -> unit) x in
            log
              (Core_kernel.ksprintf Js.string "%s: %f seconds" label
                 ((stop##getTime -. start##getTime) /. 1000.) ) ;
            x
          in
          let n = 131072 in
          let log_n = Core_kernel.Int.ceil_log2 n in
          let urs = time "create" (fun () -> create n) in
          let inputs =
            time "inputs" (fun () -> Array.init n (fun i -> Pasta_fp.of_int i))
          in
          let _ = time "commit" (fun () -> commit_evaluations urs n inputs) in
          let _ =
            let xs = Array.init log_n (fun _ -> Pasta_fp.random ()) in
            time "b_poly" (fun () -> b_poly_commitment urs xs)
          in
          () ) ;
         let eq_affine x y = eq_affine ~field_equal:Pasta_fq.equal x y in
         let eq = eq_poly_comm ~field_equal:Pasta_fq.equal in
         let first = create 10 in
         let second = create 16 in
         let lcomm1 = lagrange_commitment first 8 0 in
         let lcomm1_again = lagrange_commitment second 8 0 in
         assert (eq lcomm1 lcomm1_again) ;
         let inputs = Pasta_fp.[| of_int 1; of_int 2; of_int 3; of_int 4 |] in
         let commits = commit_evaluations second 8 inputs in
         let commits_again = commit_evaluations second 8 inputs in
         assert (eq commits commits_again) ;
         let inputs2 = Array.init 64 Pasta_fp.of_int in
         let affines =
           Array.init 16 (fun i ->
               try lcomm1.unshifted.(i)
               with _ -> Pasta_vesta.random () |> Pasta_vesta.to_affine )
         in
         let res = batch_accumulator_check second affines inputs2 in
         assert (res || not res) ;
         let h_first = urs_h first in
         let h_second = urs_h second in
         let h_first_again = Pasta_vesta.deep_copy h_first in
         let h_second_again = Pasta_vesta.deep_copy h_second in
         assert (eq_affine h_first h_first_again) ;
         assert (eq_affine h_second h_second_again)
    end )

let _ =
  let open Pasta_fq_urs in
  Js.export "pasta_fq_urs_test"
    (object%js (_self)
       method run =
         let eq_affine x y = eq_affine ~field_equal:Pasta_fp.equal x y in
         let eq = eq_poly_comm ~field_equal:Pasta_fp.equal in
         let first = create 10 in
         let second = create 16 in
         let lcomm1 = lagrange_commitment first 8 0 in
         let lcomm1_again = lagrange_commitment second 8 0 in
         assert (eq lcomm1 lcomm1_again) ;
         let inputs = Pasta_fq.[| of_int 1; of_int 2; of_int 3; of_int 4 |] in
         let commits = commit_evaluations second 8 inputs in
         let commits_again = commit_evaluations second 8 inputs in
         assert (eq commits commits_again) ;
         let inputs2 = Array.init 64 Pasta_fq.of_int in
         let affines =
           Array.init 16 (fun i ->
               try lcomm1.unshifted.(i)
               with _ -> Pasta_pallas.random () |> Pasta_pallas.to_affine )
         in
         let res = batch_accumulator_check second affines inputs2 in
         assert (res || not res) ;
         let h_first = urs_h first in
         let h_second = urs_h second in
         let h_first_again = Pasta_pallas.deep_copy h_first in
         let h_second_again = Pasta_pallas.deep_copy h_second in
         assert (eq_affine h_first h_first_again) ;
         assert (eq_affine h_second h_second_again)
    end )

let mk_wires typ i (r1, c1) (r2, c2) (r3, c3) coeffs : _ circuit_gate =
  { typ
  ; wires =
      ( { row = r1; col = c1 }
      , { row = r2; col = c2 }
      , { row = r3; col = c3 }
      , { row = i; col = 3 }
      , { row = i; col = 4 }
      , { row = i; col = 5 }
      , { row = i; col = 6 } )
  ; coeffs
  }

let _ =
  let open Protocol.Gates.Vector.Fp in
  Js.export "pasta_fp_gate_vector_test"
    (object%js (_self)
       method run =
         let vec1 = create () in
         let vec2 = create () in
         let eq { typ = kind1; wires = wires1; coeffs = c1 }
             { typ = kind2; wires = wires2; coeffs = c2 } =
           kind1 = kind2 && wires1 = wires2
           && try Array.for_all2 Pasta_fp.equal c1 c2 with _ -> false
         in
         let assert_eq_or_log ?extra ~loc x y =
           if not (eq x y) then (
             let log x = (Js.Unsafe.js_expr "console.log" : _ -> unit) x in
             log loc ;
             Option.iter log extra ;
             log x ;
             log y ;
             assert false )
         in
         let rand_fields i = Array.init i Pasta_fp.rng in
         let zero = mk_wires Zero 0 (0, 0) (0, 1) (0, 2) (rand_fields 0) in
         let generic =
           mk_wires Generic 1 (1, 0) (1, 1) (1, 2) (rand_fields 1)
         in
         let add1 =
           mk_wires CompleteAdd 1 (1, 0) (1, 1) (1, 2) (rand_fields 2)
         in
         let add2 =
           mk_wires CompleteAdd 2 (2, 0) (2, 1) (2, 2) (rand_fields 3)
         in
         let vbmul1 =
           mk_wires VarBaseMul 3 (3, 0) (3, 1) (3, 2) (rand_fields 5)
         in
         let vbmul2 =
           mk_wires VarBaseMul 4 (4, 0) (4, 1) (4, 2) (rand_fields 10)
         in
         let vbmul3 =
           mk_wires VarBaseMul 5 (5, 0) (5, 1) (5, 2) (rand_fields 20)
         in
         let endomul1 =
           mk_wires EndoMul 6 (6, 0) (6, 1) (6, 2) (rand_fields 30)
         in
         let endomul2 =
           mk_wires EndoMul 7 (7, 0) (7, 1) (7, 2) (rand_fields 31)
         in
         let endomul3 =
           mk_wires EndoMul 8 (8, 0) (8, 1) (8, 2) (rand_fields 32)
         in
         let endomul4 =
           mk_wires EndoMul 9 (9, 0) (9, 1) (9, 2) (rand_fields 33)
         in
         let poseidon =
           mk_wires Poseidon 10 (10, 0) (10, 1) (10, 2) (rand_fields 34)
         in
         let all =
           [ zero
           ; generic
           ; add1
           ; add2
           ; vbmul1
           ; vbmul2
           ; vbmul3
           ; endomul1
           ; endomul2
           ; endomul3
           ; endomul4
           ; poseidon
           ]
         in
         let test_vec vec =
           List.iter (add vec) all ;
           List.iteri
             (fun i x -> assert_eq_or_log ~extra:i ~loc:__LOC__ x (get vec i))
             all ;
           let l, r, o, _, _, _, _ = zero.wires in
           wrap vec l r ;
           assert_eq_or_log ~loc:__LOC__ (get vec 0)
             (mk_wires Zero 0 (0, 1) (0, 1) (0, 2) zero.coeffs) ;
           wrap vec o l ;
           assert_eq_or_log ~loc:__LOC__ (get vec 0)
             (mk_wires Zero 0 (0, 1) (0, 1) (0, 0) zero.coeffs)
         in
         test_vec vec1 ; test_vec vec2
    end )

let _ =
  let open Protocol.Gates.Vector.Fq in
  Js.export "pasta_fq_gate_vector_test"
    (object%js (_self)
       method run =
         let vec1 = create () in
         let vec2 = create () in
         let eq { typ = kind1; wires = wires1; coeffs = c1 }
             { typ = kind2; wires = wires2; coeffs = c2 } =
           kind1 = kind2 && wires1 = wires2
           && try Array.for_all2 Pasta_fq.equal c1 c2 with _ -> false
         in
         let rand_fields i = Array.init i Pasta_fq.rng in
         let zero = mk_wires Zero 0 (0, 0) (0, 1) (0, 2) (rand_fields 0) in
         let generic =
           mk_wires Generic 1 (1, 0) (1, 1) (1, 2) (rand_fields 1)
         in
         let add1 = mk_wires Poseidon 1 (1, 0) (1, 1) (1, 2) (rand_fields 2) in
         let add2 =
           mk_wires CompleteAdd 2 (2, 0) (2, 1) (2, 2) (rand_fields 3)
         in
         let vbmul1 =
           mk_wires VarBaseMul 3 (3, 0) (3, 1) (3, 2) (rand_fields 5)
         in
         let vbmul2 =
           mk_wires EndoMul 4 (4, 0) (4, 1) (4, 2) (rand_fields 10)
         in
         let vbmul3 =
           mk_wires EndoMulScalar 5 (5, 0) (5, 1) (5, 2) (rand_fields 20)
         in
         let all = [ zero; generic; add1; add2; vbmul1; vbmul2; vbmul3 ] in
         let test_vec vec =
           List.iter (add vec) all ;
           List.iteri (fun i x -> assert (eq x (get vec i))) all ;
           let l, r, o, _, _, _, _ = zero.wires in
           wrap vec l r ;
           assert (
             eq (get vec 0) (mk_wires Zero 0 (0, 1) (0, 1) (0, 2) zero.coeffs) ) ;
           wrap vec o l ;
           assert (
             eq (get vec 0) (mk_wires Zero 0 (0, 1) (0, 1) (0, 0) zero.coeffs) )
         in
         test_vec vec1 ; test_vec vec2
    end )

let _ =
  let open Pasta_fp_index in
  Js.export "pasta_fp_index_test"
    (object%js (_self)
       method run =
         let gate_vector =
           let open Protocol.Gates.Vector.Fp in
           let vec = create () in
           let fields = Array.map Pasta_fp.of_int in
           let zero = mk_wires Zero 0 (0, 0) (0, 1) (0, 2) (fields [||]) in
           let generic =
             mk_wires Generic 1 (1, 0) (1, 1) (1, 2)
               (fields [| 0; 0; 0; 0; 0 |])
           in
           let add1 = mk_wires Poseidon 1 (1, 0) (1, 1) (1, 2) (fields [||]) in
           let add2 =
             mk_wires CompleteAdd 2 (2, 0) (2, 1) (2, 2) (fields [||])
           in
           let vbmul1 =
             mk_wires VarBaseMul 3 (3, 0) (3, 1) (3, 2) (fields [||])
           in
           let vbmul2 = mk_wires EndoMul 4 (4, 0) (4, 1) (4, 2) (fields [||]) in
           let vbmul3 =
             mk_wires EndoMulScalar 5 (5, 0) (5, 1) (5, 2) (fields [||])
           in
           let all = [ zero; generic; add1; add2; vbmul1; vbmul2; vbmul3 ] in
           List.iter (add vec) all ;
           vec
         in
         let urs = Pasta_fp_urs.create 16 in
         (* TODO(dw) write tests with lookup tables *)
         let lookup_tables = [||] in
         (* TODO(dw) write tests with runtime tables *)
         let runtime_table_cfg = [||] in
         let index0 =
           create gate_vector 0 lookup_tables runtime_table_cfg 0 urs
         in
         let index2 =
           create gate_vector 2 lookup_tables runtime_table_cfg 0 urs
         in
         assert (max_degree index0 = 16) ;
         assert (max_degree index2 = 16) ;
         assert (public_inputs index0 = 0) ;
         assert (public_inputs index2 = 2) ;
         assert (domain_d1_size index0 = 16) ;
         assert (domain_d1_size index2 = 16) ;
         assert (domain_d4_size index0 = 64) ;
         assert (domain_d4_size index2 = 64) ;
         assert (domain_d8_size index0 = 128) ;
         assert (domain_d8_size index2 = 128)
    end )

let _ =
  let open Pasta_fq_index in
  Js.export "pasta_fq_index_test"
    (object%js (_self)
       method run =
         let gate_vector =
           let open Protocol.Gates.Vector.Fq in
           let vec = create () in
           let rand_fields i = Array.init i Pasta_fq.rng in
           let zero = mk_wires Zero 0 (0, 0) (0, 1) (0, 2) (rand_fields 0) in
           let generic =
             mk_wires Generic 1 (1, 0) (1, 1) (1, 2) (rand_fields 1)
           in
           let add1 =
             mk_wires Poseidon 1 (1, 0) (1, 1) (1, 2) (rand_fields 2)
           in
           let add2 =
             mk_wires CompleteAdd 2 (2, 0) (2, 1) (2, 2) (rand_fields 3)
           in
           let vbmul1 =
             mk_wires VarBaseMul 3 (3, 0) (3, 1) (3, 2) (rand_fields 5)
           in
           let vbmul2 =
             mk_wires EndoMul 4 (4, 0) (4, 1) (4, 2) (rand_fields 10)
           in
           let vbmul3 =
             mk_wires EndoMulScalar 5 (5, 0) (5, 1) (5, 2) (rand_fields 20)
           in
           let all = [ zero; generic; add1; add2; vbmul1; vbmul2; vbmul3 ] in
           List.iter (add vec) all ;
           vec
         in
         let urs = Pasta_fq_urs.create 16 in
         (* TODO(dw) write tests with lookup tables *)
         let lookup_tables = [||] in
         (* TODO(dw) write tests with runtime tables *)
         let runtime_table_cfg = [||] in
         let index0 =
           create gate_vector 0 lookup_tables runtime_table_cfg 0 urs
         in
         let index2 =
           create gate_vector 2 lookup_tables runtime_table_cfg 0 urs
         in
         assert (max_degree index0 = 16) ;
         assert (max_degree index2 = 16) ;
         assert (public_inputs index0 = 0) ;
         assert (public_inputs index2 = 2) ;
         assert (domain_d1_size index0 = 16) ;
         assert (domain_d1_size index2 = 16) ;
         assert (domain_d4_size index0 = 64) ;
         assert (domain_d4_size index2 = 64) ;
         assert (domain_d8_size index0 = 128) ;
         assert (domain_d8_size index2 = 128)
    end )

let eq_verification_shifts ~field_equal l r = Array.for_all2 field_equal l r

let verification_evals_to_list
    { VerifierIndex.sigma_comm : 'PolyComm array
    ; coefficients_comm : 'PolyComm array
    ; generic_comm : 'PolyComm
    ; psm_comm : 'PolyComm
    ; complete_add_comm : 'PolyComm
    ; mul_comm : 'PolyComm
    ; emul_comm : 'PolyComm
    ; endomul_scalar_comm : 'PolyComm
    ; xor_comm : 'PolyComm option
    ; range_check0_comm : 'PolyComm option
    ; range_check1_comm : 'PolyComm option
    ; foreign_field_add_comm : 'PolyComm option
    ; foreign_field_mul_comm : 'PolyComm option
    ; rot_comm : 'PolyComm option
    } =
  let non_opt_comms =
    generic_comm :: psm_comm :: complete_add_comm :: mul_comm :: emul_comm
    :: endomul_scalar_comm
    :: (Array.append sigma_comm coefficients_comm |> Array.to_list)
  in
  let opt_comms =
    [ xor_comm
    ; range_check0_comm
    ; range_check1_comm
    ; foreign_field_add_comm
    ; foreign_field_mul_comm
    ; rot_comm
    ]
  in
  List.map Option.some non_opt_comms @ opt_comms

let eq_verifier_index ~field_equal ~other_field_equal
    { VerifierIndex.domain = { log_size_of_group = i1_1; group_gen = f1 }
    ; max_poly_size = i1_2
    ; srs = _
    ; evals = evals1
    ; shifts = shifts1
    ; lookup_index = _
    ; public = public1
    ; prev_challenges = prev_challenges1
    }
    { VerifierIndex.domain = { log_size_of_group = i2_1; group_gen = f2 }
    ; max_poly_size = i2_2
    ; srs = _
    ; evals = evals2
    ; shifts = shifts2
    ; lookup_index = _
    ; public = public2
    ; prev_challenges = prev_challenges2
    } =
  i1_1 = i2_1 && field_equal f1 f2 && i1_2 = i2_2
  && List.for_all2
       (fun x y ->
         match (x, y) with
         | Some x, Some y ->
             eq_poly_comm ~field_equal:other_field_equal x y
         | None, None ->
             true
         | _, _ ->
             false )
       (verification_evals_to_list evals1)
       (verification_evals_to_list evals2)
  && eq_verification_shifts ~field_equal shifts1 shifts2
  && public1 = public2
  && prev_challenges1 = prev_challenges2

let _ =
  let open Pasta_fp_verifier_index in
  Js.export "pasta_fp_verifier_index_test"
    (object%js (_self)
       method run =
         let gate_vector =
           let open Protocol.Gates.Vector.Fp in
           let vec = create () in
           let fields = Array.map Pasta_fp.of_int in
           let zero = mk_wires Zero 0 (0, 0) (0, 1) (0, 2) (fields [||]) in
           let generic =
             mk_wires Generic 1 (1, 0) (1, 1) (1, 2)
               (fields [| 0; 0; 0; 0; 0 |])
           in
           let add1 = mk_wires Poseidon 1 (1, 0) (1, 1) (1, 2) (fields [||]) in
           let add2 =
             mk_wires CompleteAdd 2 (2, 0) (2, 1) (2, 2) (fields [||])
           in
           let vbmul1 =
             mk_wires VarBaseMul 3 (3, 0) (3, 1) (3, 2) (fields [||])
           in
           let vbmul2 = mk_wires EndoMul 4 (4, 0) (4, 1) (4, 2) (fields [||]) in
           let vbmul3 =
             mk_wires EndoMulScalar 5 (5, 0) (5, 1) (5, 2) (fields [||])
           in
           let all = [ zero; generic; add1; add2; vbmul1; vbmul2; vbmul3 ] in
           List.iter (add vec) all ;
           vec
         in
         let eq =
           eq_verifier_index ~field_equal:Pasta_fp.equal
             ~other_field_equal:Pasta_fq.equal
         in
         let urs = Pasta_fp_urs.create 16 in
         (* TODO(dw) write tests with lookup tables *)
         let lookup_tables = [||] in
         (* TODO(dw) write tests with runtime tables *)
         let runtime_table_cfg = [||] in
         let index0 =
           Pasta_fp_index.create gate_vector 0 lookup_tables runtime_table_cfg 0
             urs
         in
         let index2 =
           Pasta_fp_index.create gate_vector 2 lookup_tables runtime_table_cfg 0
             urs
         in
         let vindex0_0 = create index0 in
         let vindex0_1 = create index0 in
         assert (eq vindex0_0 vindex0_1) ;
         let vindex2_0 = create index2 in
         let vindex2_1 = create index2 in
         assert (eq vindex2_0 vindex2_1) ;
         let dummy0 = dummy () in
         let dummy1 = dummy () in
         assert (eq dummy0 dummy1) ;
         List.iter
           (fun x -> assert (eq (deep_copy x) x))
           [ vindex0_0; vindex2_0; dummy0 ]
    end )

let _ =
  let open Pasta_fq_verifier_index in
  Js.export "pasta_fq_verifier_index_test"
    (object%js (_self)
       method run =
         let gate_vector =
           let open Protocol.Gates.Vector.Fq in
           let vec = create () in
           let fields = Array.map Pasta_fq.of_int in
           let zero = mk_wires Zero 0 (0, 0) (0, 1) (0, 2) (fields [||]) in
           let generic =
             mk_wires Generic 1 (1, 0) (1, 1) (1, 2)
               (fields [| 0; 0; 0; 0; 0 |])
           in
           let add1 = mk_wires Poseidon 1 (1, 0) (1, 1) (1, 2) (fields [||]) in
           let add2 =
             mk_wires CompleteAdd 2 (2, 0) (2, 1) (2, 2) (fields [||])
           in
           let vbmul1 =
             mk_wires VarBaseMul 3 (3, 0) (3, 1) (3, 2) (fields [||])
           in
           let vbmul2 = mk_wires EndoMul 4 (4, 0) (4, 1) (4, 2) (fields [||]) in
           let vbmul3 =
             mk_wires EndoMulScalar 5 (5, 0) (5, 1) (5, 2) (fields [||])
           in
           let all = [ zero; generic; add1; add2; vbmul1; vbmul2; vbmul3 ] in
           List.iter (add vec) all ;
           vec
         in
         let eq =
           eq_verifier_index ~field_equal:Pasta_fq.equal
             ~other_field_equal:Pasta_fp.equal
         in
         let urs = Pasta_fq_urs.create 16 in
         (* TODO(dw) write tests with lookup tables *)
         let lookup_tables = [||] in
         (* TODO(dw) write tests with runtime tables *)
         let runtime_table_cfg = [||] in
         let index0 =
           Pasta_fq_index.create gate_vector 0 lookup_tables runtime_table_cfg 0
             urs
         in
         let index2 =
           Pasta_fq_index.create gate_vector 2 lookup_tables runtime_table_cfg 0
             urs
         in
         let vindex0_0 = create index0 in
         let vindex0_1 = create index0 in
         assert (eq vindex0_0 vindex0_1) ;
         let vindex2_0 = create index2 in
         let vindex2_1 = create index2 in
         assert (eq vindex2_0 vindex2_1) ;
         let dummy0 = dummy () in
         let dummy1 = dummy () in
         assert (eq dummy0 dummy1) ;
         List.iter
           (fun x -> assert (eq (deep_copy x) x))
           [ vindex0_0; vindex2_0; dummy0 ]
    end )

let linkme = ()
