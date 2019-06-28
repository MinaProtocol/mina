open Core

let string () = String.init 128 ~f:(fun _ -> Char.of_int_exn (Random.int 255))
