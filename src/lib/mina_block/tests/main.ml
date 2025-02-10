open Alcotest
open Core_kernel

(* NOTE: This serialization is used externally and MUST NOT change.
    If the underlying types change, you should write a conversion, or add
    optional fields and handle them appropriately.
*)
(* But if you really need to update it, you can generate new samples using:
   `dune exec dump_blocks 1> block.txt` *)
let sexp_serialization_is_stable () =
  let serialized_block = Sample_precomputed_block.sample_block_sexp in
  ignore @@ Mina_block.Precomputed.t_of_sexp @@ Sexp.of_string serialized_block

let sexp_serialization_roundtrips () =
  let serialized_block = Sample_precomputed_block.sample_block_sexp in
  let sexp = Sexp.of_string serialized_block in
  let sexp_roundtrip = Mina_block.Precomputed.(sexp_of_t @@ t_of_sexp sexp) in
  if Sexp.equal sexp sexp_roundtrip then ()
  else failwith "sexp roundtrip failed"

(* NOTE: This serialization is used externally and MUST NOT change.
    If the underlying types change, you should write a conversion, or add
    optional fields and handle them appropriately.
*)
(* But if you really need to update it, see output of CLI command:
   `dune exec dump_blocks 1> block.txt` *)
let json_serialization_is_stable () =
  let serialized_block = Sample_precomputed_block.sample_block_json in
  match
    Mina_block.Precomputed.of_yojson @@ Yojson.Safe.from_string serialized_block
  with
  | Ok _ ->
      ()
  | Error err ->
      failwith err

let json_serialization_roundtrips () =
  let serialized_block = Sample_precomputed_block.sample_block_json in
  let json = Yojson.Safe.from_string serialized_block in
  let json_roundtrip =
    match
      Mina_block.Precomputed.(Result.map ~f:to_yojson @@ of_yojson json)
    with
    | Ok json ->
        json
    | Error err ->
        failwith err
  in
  assert (Yojson.Safe.equal json json_roundtrip)

let () =
  run "Precomputed block serialization tests"
    [ ( "sexp"
      , [ test_case "serialization is stable" `Quick
            sexp_serialization_is_stable
        ; test_case "serialization roundtrips" `Quick
            sexp_serialization_roundtrips
        ] )
    ; ( "json"
      , [ test_case "serialization is stable" `Quick
            json_serialization_is_stable
        ; test_case "serialization roundtrips" `Quick
            json_serialization_roundtrips
        ] )
    ]
