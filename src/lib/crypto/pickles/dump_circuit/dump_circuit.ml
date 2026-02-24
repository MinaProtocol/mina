let () =
  let output_dir =
    if Array.length Sys.argv > 1 then Sys.argv.(1)
    else "."
  in
  Pickles.Dump_circuit_impl.run ~output_dir
