let () =
  (* Parse arguments *)
  Array.iter
    (fun arg ->
      if arg = "--check" then Manifest.check_mode := true)
    Sys.argv;
  (* Register all targets *)
  Product_mina.register ();
  (* Generate (or check) dune files *)
  Manifest.generate ()
