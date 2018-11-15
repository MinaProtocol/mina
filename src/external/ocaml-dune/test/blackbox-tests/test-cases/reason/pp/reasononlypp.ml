let lint = ref false
let fname = ref None
let usage =
  Printf.sprintf "%s [-lint] file" (Filename.basename Sys.executable_name)
let anon s =
  match !fname with
  | None -> fname := Some s
  | Some _ -> raise (Arg.Bad "file must only be given once")

let is_ascii s =
  try
    for i=0 to String.length s - 1 do
      if Char.code (s.[i]) > 127 then raise Exit
    done;
    true
  with Exit ->
    false

let () =
  Arg.parse
    ["-lint", Arg.Set lint, "lint instead of preprocessing"
    ] anon usage;
  let fname =
    match !fname with
    | None -> raise (Arg.Bad "file must be provided")
    | Some f -> f in

  if Filename.check_suffix fname ".re"
  || Filename.check_suffix fname ".rei" then (
    if !lint && (Filename.check_suffix fname ".pp.re"
              || Filename.check_suffix fname ".pp.rei") then (
      Format.eprintf "reason linter doesn't accept preprocessed file %s" fname;
    );
    let ch = open_in fname in
    let rec loop () =
      match input_line ch with
      | exception End_of_file -> ()
      | line when is_ascii line ->
        if not !lint then (
          print_endline line
        );
        loop ()
      | _ ->
        Format.eprintf "%s isn't source code@.%!" fname;
        exit 1
    in
    loop ();
    close_in ch;
    exit 0
  ) else (
    Format.eprintf "%s is not a reason source@.%!" fname;
    exit 1
  )
