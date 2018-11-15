open Printf

let parse_version s =
  Scanf.sscanf s "%d.%d.%d" (fun a b c -> a, b, c)

let () =
  let usage =
    sprintf "%s -ocamlv version" (Filename.basename Sys.executable_name) in
  let ocaml_version = ref "" in
  let anon _ =
    raise (Arg.Bad "anonymous arguments aren't accepted") in
  Arg.parse
    [ "-ocamlv"
    , Arg.String (fun s -> ocaml_version := s)
    , "Version of ocaml being used"
    ] anon usage;
  if !ocaml_version = "" then
    raise (Arg.Bad "Provide version with -ocamlv")
  else
    let (x, y, _) = parse_version !ocaml_version in
    if x >= 4 && y > 2 then (
      printf "()\n"
    ) else (
      printf "(-w -50)\n"
    )
