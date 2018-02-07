(* Adapted from https://stackoverflow.com/questions/11276985/emulating-try-with-finally-in-ocaml *)
(* Parametricity ensures bracket acquisition happens before f and release *)
let bracket ~acquire ~release f =
  let resource = acquire () in
  let res = try Ok (f resource) with e -> Error e in
  let () = release resource in
  match res with
  | Ok y -> y
  | Error e -> raise e

let%test_module "bracket" = (module struct

  let%test "bracket_releases_happy_case" =
    let released = ref false in
    let x = bracket ~acquire:(fun () -> 3) ~release:(fun _ -> released := true) (fun x -> x) in
    x = 3 && !released

  exception Mock
  let%test "bracket_releases_sad_case" =
    let released = ref false in
    let _ =
      try
        bracket ~acquire:(fun () -> 3) ~release:(fun _ -> released := true) (fun x -> raise Mock)
      with _ -> 3
    in
    !released
end)
