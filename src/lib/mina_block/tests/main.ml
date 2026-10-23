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

let versioned_reads_sample () =
  let json =
    Yojson.Safe.from_string Sample_precomputed_block.sample_block_json
  in
  match Mina_block.Precomputed.Versioned.of_yojson json with
  | Ok (V4 _ as block) ->
      assert (
        Yojson.Safe.equal json
          (Mina_block.Precomputed.Versioned.to_yojson block) )
  | Ok (V3 _) ->
      failwith "read the version 4 sample as version 3"
  | Error err ->
      failwith err

let versioned_state_hash_matches_latest () =
  let json =
    Yojson.Safe.from_string Sample_precomputed_block.sample_block_json
  in
  let latest = Mina_block.Precomputed.of_yojson json |> Result.ok_or_failwith in
  let versioned =
    Mina_block.Precomputed.Versioned.of_yojson json |> Result.ok_or_failwith
  in
  assert (
    Mina_base.State_hash.equal
      (Mina_state.Protocol_state.hashes latest.protocol_state).state_hash
      (Mina_block.Precomputed.Versioned.state_hashes versioned).state_hash )

let versioned_rejects_unknown_version () =
  let json =
    match
      Yojson.Safe.from_string Sample_precomputed_block.sample_block_json
    with
    | `Assoc fields ->
        `Assoc
          (List.map fields ~f:(function
            | "version", _ ->
                ("version", `Int 1000)
            | field ->
                field ) )
    | _ ->
        failwith "sample block JSON is not an object"
  in
  assert (Result.is_error (Mina_block.Precomputed.Versioned.of_yojson json)) ;
  assert (
    Result.is_error
      (Mina_block.Precomputed.Versioned.of_yojson (`Assoc [ ("data", `Null) ])) )

let large_precomputed_json_file = "hetzner-itn-1-1795.json"

let _json_serialization_is_stable_from_file () =
  json_serialization_is_stable_impl
  @@ In_channel.read_all large_precomputed_json_file

let _json_serialization_roundtrips_from_file () =
  json_serialization_roundtrips_impl
  @@ In_channel.read_all large_precomputed_json_file

let field_element_decimal_deserialization () =
  let filename =
    "regtest-devnet-319281-3NKq8WXEzMFJH3VdmK4seCTpciyjSY2Rf39K7q1Yyt1p4HkqSzqA.json"
  in
  let json = Yojson.Safe.from_file filename in
  json_serialization_is_stable_impl @@ Yojson.Safe.to_string json

(* Mainnet blocks of version 3, from the public block bucket, with the hashes
   of their commands in the mainnet archive dump
   `mainnet-archive-dump-2026-10-01_0000`, in sequence order. The first block
   has a zkApp command authorized by a proof, and an account with a zkApp. *)
let v3_blocks =
  [ ( "mainnet-545000-3NKc1wHM45SweeqiCZyNwmNJQnT4vjzJmeCYkG83YqXNgDPY57ZD.json"
    , [ "5Jv6nCoABLcAsszC4kyFvEy3g6PXS5htvfM9JrGv2vPGERE11N8H"
      ; "5JvGVjyaCDWmyrgw6G9GWYhNaHftMAqUNe6PX2k8wfYYVpGDydDC"
      ; "5JusDQDoH4GfZpD19eRNJmW4vbFwToR7ja12FEMtAbL9Q9dpDk6D"
      ; "5JuNyBCfHpx8XkCMA7ox4i5mVdRudPGHSy7CmYW9SFqp5QJz9rUb"
      ; "5JuEnYjGNm9f4w2MQ3rjhGc7QubsonB7taTUxCsPzv5QVTiCGRCM"
      ] )
  ; ( "mainnet-520000-3NKuyY4iqW7mXThknMwwNiKst67uo6txzhWFJj3S9fk1jot8M7Qn.json"
    , [ "5Ju7ubyPvv3tDvZtHRRUovWckgDQVmQtas8FF4GwUNeYJsJnHTmj" ] )
  ]

let read_v3 filename =
  match
    Mina_block.Precomputed.Versioned.of_yojson (Yojson.Safe.from_file filename)
  with
  | Ok (V3 block) ->
      block
  | Ok (V4 _) ->
      failwith "read a version 3 block as version 4"
  | Error err ->
      failwith err

let v3_roundtrips () =
  List.iter v3_blocks ~f:(fun (filename, _) ->
      let json = Yojson.Safe.from_file filename in
      assert (
        Yojson.Safe.equal json
          (Mina_block.Precomputed.Versioned.to_yojson (V3 (read_v3 filename))) ) )

(* A file in the bucket is named after the state hash of its block. *)
let v3_state_hash_matches_file_name () =
  List.iter v3_blocks ~f:(fun (filename, _) ->
      let state_hash =
        (Mina_block.Precomputed.Versioned.state_hashes (V3 (read_v3 filename)))
          .state_hash
      in
      [%test_eq: string]
        ( String.chop_suffix_exn filename ~suffix:".json"
        |> String.split ~on:'-' |> List.last_exn )
        (Mina_base.State_hash.to_base58_check state_hash) )

let v3_command_hashes_match_archive () =
  List.iter v3_blocks ~f:(fun (filename, archived_hashes) ->
      let block = read_v3 filename in
      let two, one =
        Berkeley_types.Diff.commands_with_hashes block.staged_ledger_diff
      in
      let { Staged_ledger_diff.Pre_diff_two.commands; _ } = two in
      let one_commands =
        Option.value_map one ~default:[]
          ~f:(fun { Staged_ledger_diff.Pre_diff_one.commands; _ } -> commands)
      in
      [%test_eq: string list] archived_hashes
        (List.map (commands @ one_commands)
           ~f:(fun { Mina_base.With_status.data = _, hash; _ } ->
             Mina_transaction.Transaction_hash.to_base58_check hash ) ) )

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
          (* TODO Restore these tests once hetzner-itn-1-1795 can be regenerated
             ; test_case "serialization is stable from file" `Quick
                 json_serialization_is_stable_from_file
             ; test_case "serialization roundtrips from file" `Quick
                 json_serialization_roundtrips_from_file
          *)
        ] )
    ; ( "versioned"
      , [ test_case "reads the sample at its version" `Quick
            versioned_reads_sample
        ; test_case "state hash matches the latest version's" `Quick
            versioned_state_hash_matches_latest
        ; test_case "rejects unknown versions" `Quick
            versioned_rejects_unknown_version
        ] )
    ; ( "version 3"
      , [ test_case "mainnet blocks roundtrip" `Quick v3_roundtrips
        ; test_case "state hashes match the file names" `Quick
            v3_state_hash_matches_file_name
        ; test_case "command hashes match the archive's" `Quick
            v3_command_hashes_match_archive
        ] )
    ; ( "field element represented by decimal"
      , [ test_case "block is deserializable" `Quick
            field_element_decimal_deserialization
        ] )
      (* TODO Restore these tests once hetzner-itn-1-1795 can be regenerated

         ; ( "memory caching"
           , [ test_case "caching works" `Quick (fun () ->
                   Memory_caching.test large_precomputed_json_file )
             ] )
      *)
    ]
