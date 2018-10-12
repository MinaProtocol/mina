open Core

let () = assert Insecure.randomness

let string () = String.init 128 ~f:(fun _ -> Char.of_int_exn (Random.int 255))
