
let _ =
  print_endline X.buy_it;
  Printf.printf "%s\n%!" (X.print (object%js val name = Js.string Z.use_it end));
  X.external_print (Js.string "break it");
  (fun x -> Js.Unsafe.global##globalPrintFunciton x) (Js.string "fix it")
