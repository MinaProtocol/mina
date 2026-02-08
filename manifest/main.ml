let () =
  (* Parse arguments *)
  Array.iter
    (fun arg -> if arg = "--check" then Manifest.check_mode := true)
    Sys.argv ;
  (* All targets are registered at module load time.
     Modules are linked as part of manifest_product. *)
  Manifest.generate ()
