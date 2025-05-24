open Core_kernel

(* Import the module we're testing *)
module Header = Snark_keys_header

(* Helper module to create test cases *)
module Test_helpers = struct
  (* Create a valid header for testing *)
  let valid_header =
    { Header.header_version = 1
    ; kind = { type_ = "type"; identifier = "identifier" }
    ; constraint_constants =
        { sub_windows_per_window = 4
        ; ledger_depth = 8
        ; work_delay = 1000
        ; block_window_duration_ms = 1000
        ; transaction_capacity = Log_2 3
        ; pending_coinbase_depth = 12
        ; coinbase_amount = Unsigned.UInt64.of_int 1
        ; supercharged_coinbase_factor = 1
        ; account_creation_fee = Unsigned.UInt64.of_int 1
        ; fork = None
        }
    ; length = 4096
    ; constraint_system_hash = "ABCDEF1234567890"
    ; identifying_hash = "ABCDEF1234567890"
    }

  let valid_header_string =
    Yojson.Safe.to_string (Header.to_yojson valid_header)

  let prefix = Header.prefix

  let prefix_len = String.length prefix

  let valid_header_with_prefix = prefix ^ valid_header_string

  (* Function to set up a lexbuf from a string *)
  let lexbuf_from_string str = Lexing.from_string str

  (* Function to set up a lexbuf from part-way through a string *)
  let lexbuf_from_string_offset str =
    let prefix = "AAAAAAAAAA" in
    let prefix_len = String.length prefix in
    let lexbuf = Lexing.from_string (prefix ^ str) in
    lexbuf.lex_start_pos <- 0 ;
    lexbuf.lex_curr_pos <- prefix_len ;
    lexbuf.lex_last_pos <- prefix_len ;
    lexbuf

  (* Function to set up a lexbuf with refill *)
  let lexbuf_with_refill str =
    let init = ref true in
    let initial_prefix = "AAAAAAAAAA" in
    let initial_prefix_len = String.length initial_prefix in
    let offset = ref 0 in
    let str_len = String.length str in
    let lexbuf =
      Lexing.from_function (fun buffer length ->
          match !init with
          | true ->
              init := false ;
              (* Initial read: fill with junk up to the first character
                 of the actual prefix
              *)
              Bytes.From_string.blit ~src:initial_prefix ~src_pos:0 ~dst:buffer
                ~dst_pos:0 ~len:initial_prefix_len ;
              Bytes.set buffer initial_prefix_len str.[0] ;
              offset := 1 ;
              initial_prefix_len + 1
          | false ->
              (* Subsequent read: fill the rest of the buffer. *)
              let len = Int.min length (str_len - !offset) in
              if len = 0 then 0
              else (
                Bytes.From_string.blit ~src:str ~src_pos:!offset ~dst:buffer
                  ~dst_pos:0 ~len ;
                offset := !offset + len ;
                len ) )
    in
    (* Load the initial content into the buffer *)
    lexbuf.refill_buff lexbuf ;
    lexbuf.lex_start_pos <- 0 ;
    lexbuf.lex_curr_pos <- initial_prefix_len ;
    lexbuf.lex_last_pos <- initial_prefix_len ;
    lexbuf
end

(* Tests for the header parsing functionality *)
let test_parse_without_prefix () =
  let open Test_helpers in
  Alcotest.(check bool)
    "Should fail to parse without prefix" true
    ( Header.parse_lexbuf (lexbuf_from_string valid_header_string)
    |> Or_error.is_error )

let test_parse_with_incorrect_prefix () =
  let open Test_helpers in
  Alcotest.(check bool)
    "Should fail to parse with incorrect prefix" true
    ( Header.parse_lexbuf (lexbuf_from_string ("BLAH" ^ valid_header_string))
    |> Or_error.is_error )

let test_parse_with_matching_length_prefix () =
  let open Test_helpers in
  let fake_prefix = String.init prefix_len ~f:(fun _ -> 'a') in
  Alcotest.(check bool)
    "Should fail to parse with matching-length but different prefix" true
    ( Header.parse_lexbuf
        (lexbuf_from_string (fake_prefix ^ valid_header_string))
    |> Or_error.is_error )

let test_parse_with_partial_matching_prefix () =
  let open Test_helpers in
  let partial_prefix = String.sub prefix ~pos:0 ~len:(prefix_len - 1) ^ " " in
  Alcotest.(check bool)
    "Should fail to parse with partial matching prefix" true
    ( Header.parse_lexbuf
        (lexbuf_from_string (partial_prefix ^ valid_header_string))
    |> Or_error.is_error )

let test_parse_with_short_file () =
  let open Test_helpers in
  Alcotest.(check bool)
    "Should fail to parse with short file" true
    (Header.parse_lexbuf (lexbuf_from_string "BLAH") |> Or_error.is_error)

let test_parse_with_prefix_only () =
  let open Test_helpers in
  Alcotest.(check bool)
    "Should fail to parse with prefix only" true
    (Header.parse_lexbuf (lexbuf_from_string prefix) |> Or_error.is_error)

let test_parse_valid_header_with_prefix () =
  let open Test_helpers in
  Alcotest.(check bool)
    "Should successfully parse valid header with prefix" true
    ( Header.parse_lexbuf (lexbuf_from_string valid_header_with_prefix)
    |> Or_error.is_ok )

let test_parse_valid_header_with_prefix_and_data () =
  let open Test_helpers in
  Alcotest.(check bool)
    "Should successfully parse valid header with prefix and additional data"
    true
    ( Header.parse_lexbuf
        (lexbuf_from_string (valid_header_with_prefix ^ "DATADATADATA"))
    |> Or_error.is_ok )

(* Tests for parsing from part-way through a lexbuf *)
let test_offset_parse_without_prefix () =
  let open Test_helpers in
  Alcotest.(check bool)
    "Should fail to parse without prefix (offset)" true
    ( Header.parse_lexbuf (lexbuf_from_string_offset valid_header_string)
    |> Or_error.is_error )

let test_offset_parse_with_incorrect_prefix () =
  let open Test_helpers in
  Alcotest.(check bool)
    "Should fail to parse with incorrect prefix (offset)" true
    ( Header.parse_lexbuf
        (lexbuf_from_string_offset ("BLAH" ^ valid_header_string))
    |> Or_error.is_error )

let test_offset_parse_with_matching_length_prefix () =
  let open Test_helpers in
  let fake_prefix = String.init prefix_len ~f:(fun _ -> 'a') in
  Alcotest.(check bool)
    "Should fail to parse with matching-length but different prefix (offset)"
    true
    ( Header.parse_lexbuf
        (lexbuf_from_string_offset (fake_prefix ^ valid_header_string))
    |> Or_error.is_error )

let test_offset_parse_with_partial_matching_prefix () =
  let open Test_helpers in
  let partial_prefix = String.sub prefix ~pos:0 ~len:(prefix_len - 1) ^ " " in
  Alcotest.(check bool)
    "Should fail to parse with partial matching prefix (offset)" true
    ( Header.parse_lexbuf
        (lexbuf_from_string_offset (partial_prefix ^ valid_header_string))
    |> Or_error.is_error )

let test_offset_parse_with_short_file () =
  let open Test_helpers in
  Alcotest.(check bool)
    "Should fail to parse with short file (offset)" true
    (Header.parse_lexbuf (lexbuf_from_string_offset "BLAH") |> Or_error.is_error)

let test_offset_parse_with_prefix_only () =
  let open Test_helpers in
  Alcotest.(check bool)
    "Should fail to parse with prefix only (offset)" true
    (Header.parse_lexbuf (lexbuf_from_string_offset prefix) |> Or_error.is_error)

let test_offset_parse_valid_header_with_prefix () =
  let open Test_helpers in
  Alcotest.(check bool)
    "Should successfully parse valid header with prefix (offset)" true
    ( Header.parse_lexbuf (lexbuf_from_string_offset valid_header_with_prefix)
    |> Or_error.is_ok )

let test_offset_parse_valid_header_with_prefix_and_data () =
  let open Test_helpers in
  Alcotest.(check bool)
    "Should successfully parse valid header with prefix and additional data \
     (offset)"
    true
    ( Header.parse_lexbuf
        (lexbuf_from_string_offset (valid_header_with_prefix ^ "DATADATADATA"))
    |> Or_error.is_ok )

(* Tests for parsing with refill *)
let test_refill_parse_without_prefix () =
  let open Test_helpers in
  Alcotest.(check bool)
    "Should fail to parse without prefix (refill)" true
    ( Header.parse_lexbuf (lexbuf_with_refill valid_header_string)
    |> Or_error.is_error )

let test_refill_parse_with_incorrect_prefix () =
  let open Test_helpers in
  Alcotest.(check bool)
    "Should fail to parse with incorrect prefix (refill)" true
    ( Header.parse_lexbuf (lexbuf_with_refill ("BLAH" ^ valid_header_string))
    |> Or_error.is_error )

let test_refill_parse_with_matching_length_prefix () =
  let open Test_helpers in
  let fake_prefix = String.init prefix_len ~f:(fun _ -> 'a') in
  Alcotest.(check bool)
    "Should fail to parse with matching-length but different prefix (refill)"
    true
    ( Header.parse_lexbuf
        (lexbuf_with_refill (fake_prefix ^ valid_header_string))
    |> Or_error.is_error )

let test_refill_parse_with_partial_matching_prefix () =
  let open Test_helpers in
  let partial_prefix = String.sub prefix ~pos:0 ~len:(prefix_len - 1) ^ " " in
  Alcotest.(check bool)
    "Should fail to parse with partial matching prefix (refill)" true
    ( Header.parse_lexbuf
        (lexbuf_with_refill (partial_prefix ^ valid_header_string))
    |> Or_error.is_error )

let test_refill_parse_with_short_file () =
  let open Test_helpers in
  Alcotest.(check bool)
    "Should fail to parse with short file (refill)" true
    (Header.parse_lexbuf (lexbuf_with_refill "BLAH") |> Or_error.is_error)

let test_refill_parse_with_prefix_only () =
  let open Test_helpers in
  Alcotest.(check bool)
    "Should fail to parse with prefix only (refill)" true
    (Header.parse_lexbuf (lexbuf_with_refill prefix) |> Or_error.is_error)

let test_refill_parse_valid_header_with_prefix () =
  let open Test_helpers in
  Alcotest.(check bool)
    "Should successfully parse valid header with prefix (refill)" true
    ( Header.parse_lexbuf (lexbuf_with_refill valid_header_with_prefix)
    |> Or_error.is_ok )

let test_refill_parse_valid_header_with_prefix_and_data () =
  let open Test_helpers in
  Alcotest.(check bool)
    "Should successfully parse valid header with prefix and additional data \
     (refill)"
    true
    ( Header.parse_lexbuf
        (lexbuf_with_refill (valid_header_with_prefix ^ "DATADATADATA"))
    |> Or_error.is_ok )

(* Organize all tests *)
let () =
  Alcotest.run "Snark_keys_header"
    [ ( "Standard parsing tests"
      , [ Alcotest.test_case "Parse without prefix" `Quick
            test_parse_without_prefix
        ; Alcotest.test_case "Parse with incorrect prefix" `Quick
            test_parse_with_incorrect_prefix
        ; Alcotest.test_case "Parse with matching-length prefix" `Quick
            test_parse_with_matching_length_prefix
        ; Alcotest.test_case "Parse with partial matching prefix" `Quick
            test_parse_with_partial_matching_prefix
        ; Alcotest.test_case "Parse with short file" `Quick
            test_parse_with_short_file
        ; Alcotest.test_case "Parse with prefix only" `Quick
            test_parse_with_prefix_only
        ; Alcotest.test_case "Parse valid header with prefix" `Quick
            test_parse_valid_header_with_prefix
        ; Alcotest.test_case "Parse valid header with prefix and data" `Quick
            test_parse_valid_header_with_prefix_and_data
        ] )
    ; ( "Offset parsing tests"
      , [ Alcotest.test_case "Offset: Parse without prefix" `Quick
            test_offset_parse_without_prefix
        ; Alcotest.test_case "Offset: Parse with incorrect prefix" `Quick
            test_offset_parse_with_incorrect_prefix
        ; Alcotest.test_case "Offset: Parse with matching-length prefix" `Quick
            test_offset_parse_with_matching_length_prefix
        ; Alcotest.test_case "Offset: Parse with partial matching prefix" `Quick
            test_offset_parse_with_partial_matching_prefix
        ; Alcotest.test_case "Offset: Parse with short file" `Quick
            test_offset_parse_with_short_file
        ; Alcotest.test_case "Offset: Parse with prefix only" `Quick
            test_offset_parse_with_prefix_only
        ; Alcotest.test_case "Offset: Parse valid header with prefix" `Quick
            test_offset_parse_valid_header_with_prefix
        ; Alcotest.test_case "Offset: Parse valid header with prefix and data"
            `Quick test_offset_parse_valid_header_with_prefix_and_data
        ] )
    ; ( "Refill parsing tests"
      , [ Alcotest.test_case "Refill: Parse without prefix" `Quick
            test_refill_parse_without_prefix
        ; Alcotest.test_case "Refill: Parse with incorrect prefix" `Quick
            test_refill_parse_with_incorrect_prefix
        ; Alcotest.test_case "Refill: Parse with matching-length prefix" `Quick
            test_refill_parse_with_matching_length_prefix
        ; Alcotest.test_case "Refill: Parse with partial matching prefix" `Quick
            test_refill_parse_with_partial_matching_prefix
        ; Alcotest.test_case "Refill: Parse with short file" `Quick
            test_refill_parse_with_short_file
        ; Alcotest.test_case "Refill: Parse with prefix only" `Quick
            test_refill_parse_with_prefix_only
        ; Alcotest.test_case "Refill: Parse valid header with prefix" `Quick
            test_refill_parse_valid_header_with_prefix
        ; Alcotest.test_case "Refill: Parse valid header with prefix and data"
            `Quick test_refill_parse_valid_header_with_prefix_and_data
        ] )
    ]
