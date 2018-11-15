let foo _ = ()

let run () =
  Priv.run ();
  print_endline "implementation of foo"
