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

let json_serialization_is_stable_impl serialized_block =
  match
    Mina_block.Precomputed.of_yojson @@ Yojson.Safe.from_string serialized_block
  with
  | Ok _ ->
      ()
  | Error err ->
      failwith err

(* NOTE: This serialization is used externally and MUST NOT change.
    If the underlying types change, you should write a conversion, or add
    optional fields and handle them appropriately.
*)
(* But if you really need to update it, see output of CLI command:
   `dune exec dump_blocks 1> block.txt` *)
let json_serialization_is_stable () =
  json_serialization_is_stable_impl
  @@ Sample_precomputed_block.sample_block_json

let json_serialization_roundtrips_impl serialized_block =
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

let json_serialization_roundtrips () =
  json_serialization_roundtrips_impl
  @@ Sample_precomputed_block.sample_block_json

let large_precomputed_json_file = "hetzner-itn-1-1795.json"

let json_serialization_is_stable_from_file () =
  json_serialization_is_stable_impl
  @@ In_channel.read_all large_precomputed_json_file

let json_serialization_roundtrips_from_file () =
  json_serialization_roundtrips_impl
  @@ In_channel.read_all large_precomputed_json_file

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
        ; test_case "serialization is stable from file" `Quick
            json_serialization_is_stable_from_file
        ; test_case "serialization roundtrips from file" `Quick
            json_serialization_roundtrips_from_file
        ] )
    ; ( "memory caching"
      , [ test_case "caching works" `Quick (fun () ->
              Memory_caching.test large_precomputed_json_file )
        ] )
    ]
