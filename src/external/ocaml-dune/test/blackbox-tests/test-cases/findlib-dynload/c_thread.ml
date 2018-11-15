let t =
  Thread.create
    (fun () -> Thread.delay 0.0001 ) ()

let () = Mytool.Register.register "c_thread" (fun () -> Thread.join t)
