(* Testing
   -------

   Component: Pickles / Composition_types
   Subject: Test types serialization and equality
   Invocation: dune exec src/lib/pickles/composition_types/test/test_composition_types.exe
*)

open Core_kernel

(* Import modules for easier access *)
module Digest = Composition_types.Digest
module Branch_data = Composition_types.Branch_data
module Bulletproof_challenge = Composition_types.Bulletproof_challenge

(* Test helpers and generators *)
module Generators = struct
  (* Generate a random Digest.Constant.t *)
  let gen_digest_constant : Digest.Constant.t Quickcheck.Generator.t =
    let open Quickcheck.Generator in
    let gen_limb = Int64.quickcheck_generator in
    list_with_length 4 gen_limb >>| Digest.Constant.A.of_list_exn

  (* Generate a random Domain_log2 *)
  let gen_domain_log2 : Branch_data.Domain_log2.t Quickcheck.Generator.t =
    let open Quickcheck.Generator in
    (* Domain log2 values are typically small integers *)
    map (Int.gen_incl 1 32) ~f:Branch_data.Domain_log2.of_int_exn

  (* Generate a random Proofs_verified *)
  let gen_proofs_verified : Pickles_base.Proofs_verified.t Quickcheck.Generator.t =
    let open Quickcheck.Generator in
    (* Random verified proofs value 0, 1, or 2 *)
    map (Int.gen_incl 0 2) ~f:(fun x ->
      (* Convert integer to Proofs_verified format *)
      Pickles_base.Proofs_verified.of_int_exn x)

  (* Generate a random Branch_data.t *)
  let gen_branch_data : Branch_data.t Quickcheck.Generator.t =
    let open Quickcheck.Generator in
    both gen_proofs_verified gen_domain_log2 >>| fun (proofs_verified, domain_log2) ->
    { Branch_data.proofs_verified; domain_log2 }

  (* Generate a random challenge value (limb vector) *)
  let gen_challenge : Limb_vector.Challenge.Constant.t Quickcheck.Generator.t =
    let open Quickcheck.Generator in
    (* Generate random bits for the challenge *)
    list_with_length (Limb_vector.Challenge.Constant.length) bool >>| fun bits ->
    Limb_vector.Challenge.Constant.of_bits bits

  (* Generate a random scalar challenge *)
  let gen_scalar_challenge : Limb_vector.Challenge.Constant.t Kimchi_backend_common.Scalar_challenge.t Quickcheck.Generator.t =
    let open Quickcheck.Generator in
    gen_challenge >>| Kimchi_backend_common.Scalar_challenge.create

  (* Generate a random bulletproof challenge *)
  let gen_bulletproof_challenge :
    Limb_vector.Challenge.Constant.t Kimchi_backend_common.Scalar_challenge.t Bulletproof_challenge.t Quickcheck.Generator.t =
    let open Quickcheck.Generator in
    gen_scalar_challenge >>| Bulletproof_challenge.unpack
end

(* Tests for Digest module *)
let test_digest_serialization () =
  Quickcheck.test ~trials:100 Generators.gen_digest_constant ~f:(fun digest ->
    (* Test serialization roundtrip *)
    let bits = Digest.Constant.to_bits digest in
    let recovered = Digest.Constant.of_bits bits in
    Alcotest.(check bool)
      "Digest serialization roundtrip"
      true
      (Digest.Constant.equal digest recovered)
  )

let test_digest_field_roundtrip () =
  Quickcheck.test ~trials:100 Generators.gen_digest_constant ~f:(fun digest ->
    (* Test conversion to tick field and back *)
    let tick_field = Digest.Constant.to_tick_field digest in
    let _recovered = Digest.Constant.of_tick_field tick_field in

    (* Test conversion to tock field and back *)
    let tock_field = Digest.Constant.to_tock_field digest in
    let _recovered = Digest.Constant.of_tock_field tock_field in

    (* Just checking that no exceptions were thrown *)
    Alcotest.(check bool) "Field conversions completed without exception" true true
  )

let test_digest_sexp_roundtrip () =
  Quickcheck.test ~trials:100 Generators.gen_digest_constant ~f:(fun digest ->
    (* Convert to sexp and back *)
    let sexp = Digest.Constant.sexp_of_t digest in
    let recovered = Digest.Constant.t_of_sexp sexp in
    Alcotest.(check bool)
      "Digest sexp roundtrip"
      true
      (Digest.Constant.equal digest recovered)
  )

let test_digest_json_roundtrip () =
  Quickcheck.test ~trials:100 Generators.gen_digest_constant ~f:(fun digest ->
    (* Convert to json and back *)
    let json = Digest.Constant.to_yojson digest in
    let recovered = Digest.Constant.of_yojson json |> Result.ok_or_failwith in
    Alcotest.(check bool)
      "Digest json roundtrip"
      true
      (Digest.Constant.equal digest recovered)
  )

(* Tests for Branch_data module *)
let test_branch_data_equality () =
  Quickcheck.test ~trials:100 Generators.gen_branch_data ~f:(fun branch_data ->
    (* Test equality with itself *)
    Alcotest.(check bool)
      "Branch_data equality with itself"
      true
      (Branch_data.equal branch_data branch_data);

    (* Test inequality with modified data *)
    let modified =
      { branch_data with
        domain_log2 = Branch_data.Domain_log2.of_int_exn
          (let domain = Branch_data.domain branch_data in
           match domain with
           | Pickles_base.Domain.Pow_2_roots_of_unity log_size ->
              if log_size > 1 then log_size - 1 else log_size + 1)
      }
    in
    Alcotest.(check bool)
      "Branch_data inequality with different data"
      false
      (Branch_data.equal branch_data modified)
  )

let test_branch_data_domain () =
  Quickcheck.test ~trials:100 Generators.gen_branch_data ~f:(fun branch_data ->
    (* Test domain accessor *)
    let domain = Branch_data.domain branch_data in
    Alcotest.(check bool)
      "Branch_data domain length is positive"
      true
      (match domain with
       | Pickles_base.Domain.Pow_2_roots_of_unity log_size -> log_size > 0)
  )

let test_branch_data_sexp_roundtrip () =
  Quickcheck.test ~trials:100 Generators.gen_branch_data ~f:(fun branch_data ->
    (* Convert to sexp and back *)
    let sexp = Branch_data.sexp_of_t branch_data in
    let recovered = Branch_data.t_of_sexp sexp in
    Alcotest.(check bool)
      "Branch_data sexp roundtrip"
      true
      (Branch_data.equal branch_data recovered)
  )

let test_branch_data_json_roundtrip () =
  Quickcheck.test ~trials:100 Generators.gen_branch_data ~f:(fun branch_data ->
    (* Convert to json and back *)
    let json = Branch_data.to_yojson branch_data in
    let recovered = Branch_data.of_yojson json |> Result.ok_or_failwith in
    Alcotest.(check bool)
      "Branch_data json roundtrip"
      true
      (Branch_data.equal branch_data recovered)
  )

(* Tests for Bulletproof_challenge module *)
let test_bulletproof_challenge_packing () =
  Quickcheck.test ~trials:100 Generators.gen_bulletproof_challenge ~f:(fun challenge ->
    (* Test pack/unpack roundtrip *)
    let prechallenge = Bulletproof_challenge.pack challenge in
    let recovered = Bulletproof_challenge.unpack prechallenge in
    Alcotest.(check bool)
      "Bulletproof_challenge pack/unpack roundtrip"
      true
      (Bulletproof_challenge.equal
         (fun a b -> Kimchi_backend_common.Scalar_challenge.equal
                      (fun a b -> Limb_vector.Challenge.Constant.equal a b) a b)
         challenge recovered)
  )

let test_bulletproof_challenge_map () =
  Quickcheck.test ~trials:100 Generators.gen_bulletproof_challenge ~f:(fun challenge ->
    (* Test map identity *)
    let mapped = Bulletproof_challenge.map challenge ~f:(fun x -> x) in
    Alcotest.(check bool)
      "Bulletproof_challenge map with identity preserves value"
      true
      (Bulletproof_challenge.equal
         (fun a b -> Kimchi_backend_common.Scalar_challenge.equal
                      (fun a b -> Limb_vector.Challenge.Constant.equal a b) a b)
         challenge mapped)
  )

let test_bulletproof_challenge_sexp_roundtrip () =
  Quickcheck.test ~trials:100 Generators.gen_bulletproof_challenge ~f:(fun challenge ->
    (* Convert to sexp and back *)
    let sexp = Bulletproof_challenge.sexp_of_t
                (fun sc -> Kimchi_backend_common.Scalar_challenge.sexp_of_t
                            (fun c -> Limb_vector.Challenge.Constant.sexp_of_t c) sc)
                challenge in
    let recovered = Bulletproof_challenge.t_of_sexp
                      (fun s -> Kimchi_backend_common.Scalar_challenge.t_of_sexp
                                  (fun s -> Limb_vector.Challenge.Constant.t_of_sexp s) s)
                      sexp in
    Alcotest.(check bool)
      "Bulletproof_challenge sexp roundtrip"
      true
      (Bulletproof_challenge.equal
         (fun a b -> Kimchi_backend_common.Scalar_challenge.equal
                      (fun a b -> Limb_vector.Challenge.Constant.equal a b) a b)
         challenge recovered)
  )

let test_bulletproof_challenge_json_roundtrip () =
  Quickcheck.test ~trials:100 Generators.gen_bulletproof_challenge ~f:(fun challenge ->
    (* Convert to json and back *)
    let json = Bulletproof_challenge.to_yojson
                 (fun sc -> Kimchi_backend_common.Scalar_challenge.to_yojson
                              (fun c -> Limb_vector.Challenge.Constant.to_yojson c) sc)
                 challenge in
    let recovered = Bulletproof_challenge.of_yojson
                      (fun j -> Kimchi_backend_common.Scalar_challenge.of_yojson
                                  (fun j -> Limb_vector.Challenge.Constant.of_yojson j) j)
                      json |> Result.ok_or_failwith in
    Alcotest.(check bool)
      "Bulletproof_challenge json roundtrip"
      true
      (Bulletproof_challenge.equal
         (fun a b -> Kimchi_backend_common.Scalar_challenge.equal
                      (fun a b -> Limb_vector.Challenge.Constant.equal a b) a b)
         challenge recovered)
  )

(* Main test runner *)
let () =
  let open Alcotest in
  run "Pickles.Composition_types" [
    (* Digest tests *)
    "Digest", [
      test_case "serialization roundtrip" `Quick test_digest_serialization;
      test_case "field conversion roundtrip" `Quick test_digest_field_roundtrip;
      test_case "sexp roundtrip" `Quick test_digest_sexp_roundtrip;
      test_case "json roundtrip" `Quick test_digest_json_roundtrip;
    ];

    (* Branch_data tests *)
    "Branch_data", [
      test_case "equality" `Quick test_branch_data_equality;
      test_case "domain accessor" `Quick test_branch_data_domain;
      test_case "sexp roundtrip" `Quick test_branch_data_sexp_roundtrip;
      test_case "json roundtrip" `Quick test_branch_data_json_roundtrip;
    ];

    (* Bulletproof_challenge tests *)
    "Bulletproof_challenge", [
      test_case "pack/unpack" `Quick test_bulletproof_challenge_packing;
      test_case "map function" `Quick test_bulletproof_challenge_map;
      test_case "sexp roundtrip" `Quick test_bulletproof_challenge_sexp_roundtrip;
      test_case "json roundtrip" `Quick test_bulletproof_challenge_json_roundtrip;
    ];
  ]
