#!/usr/bin/env ocaml

open StdLabels
open Printf

let list f l = sprintf "[%s]" (String.concat ~sep:"; " (List.map l ~f))
let string s = sprintf "%S" s
let option f = function
  | None -> "None"
  | Some x -> sprintf "Some %s" (f x)

let () =
  let bad fmt = ksprintf (fun s -> raise (Arg.Bad s)) fmt in
  let library_path = ref None in
  let library_destdir = ref None in
  let set_libdir s =
    let dir =
      if Filename.is_relative s then
        Filename.concat (Sys.getcwd ()) s
      else
        s
    in
    library_path    := Some [dir];
    library_destdir := Some dir
  in
  let args =
    [ "--libdir", Arg.String set_libdir,
      "DIR where installed libraries are for the default build context"
    ]
  in
  let anon s =
    bad "Don't know what to do with %s" s
  in
  Arg.parse (Arg.align args)
    anon "Usage: ocaml configure.ml [OPTRIONS]]\nOptions are:";
  let oc = open_out "src/setup.ml" in
  let pr fmt = fprintf oc (fmt ^^ "\n") in
  pr "let library_path    = %s" (option (list string) !library_path);
  pr "let library_destdir = %s" (option string        !library_destdir);
  close_out oc
