(** Integration tests: verify that every manifest declaration
    produces a dune file structurally identical to the original. *)

let test_all_dune_files_match () =
  Manifest.reset ();
  Product_mina.register ();
  let results = Manifest.check () in
  let failures =
    List.filter
      (fun (r : Manifest.check_result) ->
        match r.status with `Ok -> false | _ -> true)
      results
  in
  if failures <> [] then begin
    let msgs =
      List.map
        (fun (r : Manifest.check_result) ->
          match r.status with
          | `Ok -> ""
          | `New ->
              Printf.sprintf "%s: file not found" r.path
          | `Differs None ->
              Printf.sprintf "%s: differs" r.path
          | `Differs (Some d) ->
              Printf.sprintf "%s: %s" r.path d)
        failures
    in
    Alcotest.fail
      (Printf.sprintf "%d file(s) differ:\n  %s"
         (List.length failures)
         (String.concat "\n  " msgs))
  end;
  (* Sanity check: we have a reasonable number of files *)
  Alcotest.(check bool) "has registered files"
    true (List.length results > 0)

let () =
  Alcotest.run "manifest integration"
    [ ( "dune file equivalence"
      , [ Alcotest.test_case "all files match" `Quick
            test_all_dune_files_match
        ] )
    ]
