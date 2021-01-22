open Core_kernel
open Rosetta_lib

let assert_ ~f ~expected ~actual =
  let eq x y =
    match (x, y) with
    | Ok x, Ok y ->
        Yojson.Safe.equal x y
    | Error x, Error y ->
        Errors.equal x y
    | _ ->
        false
  in
  let to_yojson = function Ok x -> x | Error y -> Errors.to_yojson y in
  let expected = Result.map ~f expected in
  let actual = Result.map ~f actual in
  if eq expected actual then ()
  else
    let output =
      Yojson.Safe.pretty_to_string
        (`Assoc
          [("expected", to_yojson expected); ("actual", to_yojson actual)])
    in
    eprintf "%s" output ; failwith output
