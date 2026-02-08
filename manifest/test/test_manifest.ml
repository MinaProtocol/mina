(** Tests for the manifest system. *)

open Dune_s_expr

let test_parse_atom () =
  let result = parse_string "foo" in
  Alcotest.(check int) "one atom" 1 (List.length result) ;
  Alcotest.(check bool)
    "is atom" true
    (match result with [ Atom "foo" ] -> true | _ -> false)

let test_parse_list () =
  let result = parse_string "(foo bar)" in
  Alcotest.(check bool)
    "is list" true
    ( match result with
    | [ List [ Atom "foo"; Atom "bar" ] ] ->
        true
    | _ ->
        false )

let test_parse_nested () =
  let result = parse_string "(library (name foo))" in
  Alcotest.(check bool)
    "nested list" true
    ( match result with
    | [ List [ Atom "library"; List [ Atom "name"; Atom "foo" ] ] ] ->
        true
    | _ ->
        false )

let test_parse_quoted_string () =
  let result = parse_string {|(synopsis "Hello world")|} in
  Alcotest.(check bool)
    "quoted string" true
    ( match result with
    | [ List [ Atom "synopsis"; Atom "Hello world" ] ] ->
        true
    | _ ->
        false )

let test_parse_comment () =
  let result = parse_string ";; this is a comment\nfoo" in
  Alcotest.(check int) "atom + comment" 2 (List.length result) ;
  Alcotest.(check bool)
    "second is atom" true
    (match result with [ Comment _; Atom "foo" ] -> true | _ -> false)

let test_parse_dune_library () =
  let input =
    {|(library
 (name hex)
 (public_name hex)
 (libraries core_kernel))|}
  in
  let result = parse_string input in
  Alcotest.(check int) "one stanza" 1 (List.length result) ;
  match result with
  | [ List items ] ->
      Alcotest.(check int) "4 fields" 4 (List.length items)
  | _ ->
      Alcotest.fail "expected list"

let test_roundtrip () =
  let sexpr =
    "library"
    @: [ "name" @: [ atom "foo" ]
       ; "public_name" @: [ atom "foo" ]
       ; "libraries" @: [ atom "bar"; atom "baz" ]
       ]
  in
  let s = to_string [ sexpr ] in
  let parsed = parse_string s in
  Alcotest.(check bool) "roundtrip" true (equal_stanzas [ sexpr ] parsed)

let test_equal_atoms () =
  Alcotest.(check bool) "same atoms" true (equal (Atom "foo") (Atom "foo")) ;
  Alcotest.(check bool) "diff atoms" false (equal (Atom "foo") (Atom "bar"))

let test_equal_ignores_comments () =
  let a =
    List
      [ Atom "library"
      ; List [ Atom "name"; Atom "foo" ]
      ; Comment "opam libraries"
      ; List [ Atom "libraries"; Atom "bar" ]
      ]
  in
  let b =
    List
      [ Atom "library"
      ; List [ Atom "name"; Atom "foo" ]
      ; List [ Atom "libraries"; Atom "bar" ]
      ]
  in
  Alcotest.(check bool) "ignores comments" true (equal a b)

let test_equal_field_order_insensitive () =
  let a =
    List
      [ Atom "library"
      ; List [ Atom "name"; Atom "foo" ]
      ; List [ Atom "public_name"; Atom "foo" ]
      ; List [ Atom "libraries"; Atom "bar" ]
      ]
  in
  let b =
    List
      [ Atom "library"
      ; List [ Atom "libraries"; Atom "bar" ]
      ; List [ Atom "name"; Atom "foo" ]
      ; List [ Atom "public_name"; Atom "foo" ]
      ]
  in
  Alcotest.(check bool) "field order insensitive" true (equal a b)

let test_equal_dep_order_insensitive () =
  let a =
    List
      [ Atom "library"
      ; List [ Atom "name"; Atom "foo" ]
      ; List [ Atom "libraries"; Atom "a"; Atom "b"; Atom "c" ]
      ]
  in
  let b =
    List
      [ Atom "library"
      ; List [ Atom "name"; Atom "foo" ]
      ; List [ Atom "libraries"; Atom "c"; Atom "a"; Atom "b" ]
      ]
  in
  Alcotest.(check bool) "dep order insensitive" true (equal a b)

let test_equal_detects_missing_dep () =
  let a =
    List
      [ Atom "library"
      ; List [ Atom "name"; Atom "foo" ]
      ; List [ Atom "libraries"; Atom "a"; Atom "b" ]
      ]
  in
  let b =
    List
      [ Atom "library"
      ; List [ Atom "name"; Atom "foo" ]
      ; List [ Atom "libraries"; Atom "a"; Atom "b"; Atom "c" ]
      ]
  in
  Alcotest.(check bool) "detects missing dep" false (equal a b)

let test_equal_detects_missing_field () =
  let a =
    List
      [ Atom "library"
      ; List [ Atom "name"; Atom "foo" ]
      ; List [ Atom "public_name"; Atom "foo" ]
      ]
  in
  let b = List [ Atom "library"; List [ Atom "name"; Atom "foo" ] ] in
  Alcotest.(check bool) "detects missing field" false (equal a b)

let test_equal_stanzas_multiple () =
  let a =
    [ "library" @: [ "name" @: [ atom "foo" ] ]
    ; "rule" @: [ "targets" @: [ atom "bar.ml" ] ]
    ]
  in
  let b =
    [ "library" @: [ "name" @: [ atom "foo" ] ]
    ; "rule" @: [ "targets" @: [ atom "bar.ml" ] ]
    ]
  in
  Alcotest.(check bool) "multiple stanzas equal" true (equal_stanzas a b)

let test_diff_equal () =
  let s =
    "library" @: [ "name" @: [ atom "foo" ]; "libraries" @: [ atom "bar" ] ]
  in
  Alcotest.(check bool) "no diff" true (diff s s = None)

let test_diff_missing_field () =
  let a =
    "library" @: [ "name" @: [ atom "foo" ]; "synopsis" @: [ atom "test" ] ]
  in
  let b = "library" @: [ "name" @: [ atom "foo" ] ] in
  match diff a b with
  | Some msg ->
      Alcotest.(check bool) "mentions synopsis" true (String.length msg > 0)
  | None ->
      Alcotest.fail "expected diff"

let test_diff_dep_set () =
  let a =
    "library"
    @: [ "name" @: [ atom "foo" ]
       ; "libraries" @: [ atom "a"; atom "b"; atom "c" ]
       ]
  in
  let b =
    "library"
    @: [ "name" @: [ atom "foo" ]; "libraries" @: [ atom "a"; atom "d" ] ]
  in
  match diff a b with
  | Some msg ->
      Alcotest.(check bool) "reports dep diff" true (String.length msg > 0)
  | None ->
      Alcotest.fail "expected diff"

let test_library_basic () =
  ignore
    (Manifest.library "test_lib" ~path:"/tmp/test_manifest_out/basic"
       ~deps:[ Manifest.opam "core_kernel" ]
       ~ppx:Manifest.Ppx.standard ) ;
  (* Verify it registered without error *)
  Alcotest.(check pass) "library registered" () ()

let test_library_with_extras () =
  ignore
    (Manifest.library "test_with_extras" ~path:"/tmp/test_manifest_out/extras"
       ~deps:[ Manifest.opam "base"; Manifest.local "foo_lib" ]
       ~ppx:Manifest.Ppx.minimal ~inline_tests:true
       ~library_flags:[ "-linkall" ] ~synopsis:"Test library" ) ;
  Alcotest.(check pass) "library with extras" () ()

let test_executable_basic () =
  Manifest.executable "test_exe" ~path:"/tmp/test_manifest_out/exe"
    ~package:"test_pkg"
    ~deps:[ Manifest.opam "core" ]
    ~modes:[ "native" ] ~ppx:Manifest.Ppx.minimal ;
  Alcotest.(check pass) "executable registered" () ()

let test_at_colon () =
  let s = "library" @: [ atom "foo" ] in
  Alcotest.(check bool)
    "at_colon" true
    (match s with List [ Atom "library"; Atom "foo" ] -> true | _ -> false)

let test_nested_construction () =
  let s =
    "preprocess" @: [ "pps" @: [ atom "ppx_version"; atom "ppx_jane" ] ]
  in
  Alcotest.(check bool)
    "nested" true
    ( match s with
    | List
        [ Atom "preprocess"
        ; List [ Atom "pps"; Atom "ppx_version"; Atom "ppx_jane" ]
        ] ->
        true
    | _ ->
        false )

let () =
  Alcotest.run "manifest"
    [ ( "s-expr parsing"
      , [ Alcotest.test_case "atom" `Quick test_parse_atom
        ; Alcotest.test_case "list" `Quick test_parse_list
        ; Alcotest.test_case "nested" `Quick test_parse_nested
        ; Alcotest.test_case "quoted" `Quick test_parse_quoted_string
        ; Alcotest.test_case "comment" `Quick test_parse_comment
        ; Alcotest.test_case "dune library" `Quick test_parse_dune_library
        ; Alcotest.test_case "roundtrip" `Quick test_roundtrip
        ] )
    ; ( "s-expr comparison"
      , [ Alcotest.test_case "equal atoms" `Quick test_equal_atoms
        ; Alcotest.test_case "ignores comments" `Quick
            test_equal_ignores_comments
        ; Alcotest.test_case "field order" `Quick
            test_equal_field_order_insensitive
        ; Alcotest.test_case "dep order" `Quick test_equal_dep_order_insensitive
        ; Alcotest.test_case "missing dep" `Quick test_equal_detects_missing_dep
        ; Alcotest.test_case "missing field" `Quick
            test_equal_detects_missing_field
        ; Alcotest.test_case "multiple stanzas" `Quick
            test_equal_stanzas_multiple
        ] )
    ; ( "s-expr diff"
      , [ Alcotest.test_case "no diff" `Quick test_diff_equal
        ; Alcotest.test_case "missing field" `Quick test_diff_missing_field
        ; Alcotest.test_case "dep set diff" `Quick test_diff_dep_set
        ] )
    ; ( "manifest DSL"
      , [ Alcotest.test_case "library basic" `Quick test_library_basic
        ; Alcotest.test_case "library extras" `Quick test_library_with_extras
        ; Alcotest.test_case "executable" `Quick test_executable_basic
        ] )
    ; ( "s-expr construction"
      , [ Alcotest.test_case "@:" `Quick test_at_colon
        ; Alcotest.test_case "nested" `Quick test_nested_construction
        ] )
    ]
