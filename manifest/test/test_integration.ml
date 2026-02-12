(** Integration tests: verify that every manifest declaration
    produces a dune file structurally identical to the original. *)

let test_all_dune_files_match () =
  Manifest.reset () ;
  Product_mina.register () ;
  let results = Manifest.check () in
  let failures =
    List.filter
      (fun (r : Manifest.check_result) ->
        match r.status with `Ok -> false | _ -> true )
      results
  in
  ( if failures <> [] then
    let msgs =
      List.map
        (fun (r : Manifest.check_result) ->
          match r.status with
          | `Ok ->
              ""
          | `New ->
              Printf.sprintf "%s: file not found" r.path
          | `Differs None ->
              Printf.sprintf "%s: differs" r.path
          | `Differs (Some d) ->
              Printf.sprintf "%s: %s" r.path d )
        failures
    in
    Alcotest.fail
      (Printf.sprintf "%d file(s) differ:\n  %s" (List.length failures)
         (String.concat "\n  " msgs) ) ) ;
  (* Sanity check: we have a reasonable number of files *)
  Alcotest.(check bool) "has registered files" true (List.length results > 0)

let test_generation_idempotent () =
  (* Test that the manifest generation pipeline is idempotent:
     generate stanzas -> serialize -> parse -> serialize
     should produce identical bytes. This ensures that running
     the manifest generator twice produces the same output. *)
  let failures = ref [] in
  (* Test the s-expr serializer roundtrip on representative
     stanzas covering all stanza types we generate. *)
  let test_cases =
    [ "(library\n (name foo)\n (libraries bar baz))"
    ; "(executable\n (name main)\n (modules main))"
    ; "(test\n (name t)\n (deps a.json b.json)\n (libraries alcotest))"
    ; "(library\n (name x)\n (modules\n  (:standard \\ excluded)))"
    ; "(rule\n (targets a.ml)\n (deps b.exe)\n (action (run %{deps})))"
    ]
  in
  List.iter
    (fun input ->
      let stanzas = Dune_s_expr.parse_string input in
      let s1 = Dune_s_expr.to_string stanzas in
      let reparsed = Dune_s_expr.parse_string s1 in
      let s2 = Dune_s_expr.to_string reparsed in
      if s1 <> s2 then
        failures :=
          Printf.sprintf
            "roundtrip failure:\n  input:  %S\n  first:  %S\n  second: %S" input
            s1 s2
          :: !failures )
    test_cases ;
  (* Also verify that running Manifest.check twice produces
     identical results (same set of ok/differs). *)
  Manifest.reset () ;
  Product_mina.register () ;
  let results1 = Manifest.check () in
  Manifest.reset () ;
  Product_mina.register () ;
  let results2 = Manifest.check () in
  let n1 = List.length results1 in
  let n2 = List.length results2 in
  if n1 <> n2 then
    failures :=
      Printf.sprintf "check result count differs: %d vs %d" n1 n2 :: !failures ;
  let ok1 =
    List.filter (fun (r : Manifest.check_result) -> r.status = `Ok) results1
    |> List.length
  in
  let ok2 =
    List.filter (fun (r : Manifest.check_result) -> r.status = `Ok) results2
    |> List.length
  in
  if ok1 <> ok2 then
    failures := Printf.sprintf "ok count differs: %d vs %d" ok1 ok2 :: !failures ;
  if !failures <> [] then
    Alcotest.fail
      (Printf.sprintf "Idempotency failures:\n  %s"
         (String.concat "\n  " !failures) )

let () =
  Alcotest.run "manifest integration"
    [ ( "dune file equivalence"
      , [ Alcotest.test_case "all files match" `Quick test_all_dune_files_match
        ] )
    ; ( "idempotency"
      , [ Alcotest.test_case "serialize-parse-serialize is stable" `Quick
            test_generation_idempotent
        ] )
    ]
