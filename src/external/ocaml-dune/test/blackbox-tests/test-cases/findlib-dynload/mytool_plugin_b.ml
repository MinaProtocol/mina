let () = print_endline "b: init"
let called () = print_endline "b: called"; A.called ()

let () = Mytool.Register.register "b" called
