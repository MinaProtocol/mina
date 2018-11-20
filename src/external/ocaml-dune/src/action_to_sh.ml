open Import

module Simplified = struct
  type destination = Dev_null | File of string

  type t =
    | Run of string * string list
    | Chdir of string
    | Setenv of string * string
    | Redirect of t list * Action.Outputs.t * destination
    | Sh of string
end
open Simplified

let echo s =
  let lines = String.split_lines s in
  if not (String.is_suffix s ~suffix:"\n") then
    match List.rev lines with
    | [] -> [Run ("echo", ["-n"])]
    | last :: rest ->
      List.fold_left rest ~init:[Run ("echo", ["-n"; last])] ~f:(fun acc s ->
        Run ("echo", [s]) :: acc)
  else
    List.map lines ~f:(fun s -> Run ("echo", [s]))

let cat fn = Run ("cat", [fn])
let mkdir p = Run ("mkdir", ["-p"; p])

let simplify act =
  let rec loop (act : Action.For_shell.t) acc =
    match act with
    | Run (prog, args) ->
      Run (prog, args) :: acc
    | Chdir (p, act) ->
      loop act (Chdir p :: mkdir p :: acc)
    | Setenv (k, v, act) ->
      loop act (Setenv (k, v) :: acc)
    | Redirect (outputs, fn, act) ->
      Redirect (block act, outputs, File fn) :: acc
    | Ignore (outputs, act) ->
      Redirect (block act, outputs, Dev_null) :: acc
    | Progn l ->
      List.fold_left l ~init:acc ~f:(fun acc act -> loop act acc)
    | Echo xs -> echo (String.concat xs ~sep:"")
    | Cat x ->
      cat x :: acc
    | Copy (x, y) ->
      Run ("cp", [x; y]) :: acc
    | Symlink (x, y) ->
      Run ("ln", ["-s"; x; y]) :: Run ("rm", ["-f"; y]) :: acc
    | Copy_and_add_line_directive (x, y) ->
      Redirect (echo (Utils.line_directive ~filename:x ~line_number:1) @
                [cat x], Stdout, File y)
      :: acc
    | System x ->
      Sh x :: acc
    | Bash x ->
      Run ("bash", ["-e"; "-u"; "-o"; "pipefail"; "-c"; x]) :: acc
    | Write_file (x, y) ->
      Redirect (echo y, Stdout, File x) :: acc
    | Rename (x, y) ->
      Run ("mv", [x; y]) :: acc
    | Remove_tree x ->
      Run ("rm", ["-rf"; x]) :: acc
    | Mkdir x ->
      mkdir x :: acc
    | Digest_files _ ->
      Run ("echo", []) :: acc
    | Diff { optional; file1; file2; mode = Binary} ->
      assert (not optional);
      Run ("cmp", [file1; file2]) :: acc
    | Diff { optional = true; file1; file2; mode = _ } ->
      Sh (Printf.sprintf "test ! -e file1 -o ! -e file2 || diff %s %s"
            (quote_for_shell file1) (quote_for_shell file2))
      :: acc
    | Diff { optional = false; file1; file2; mode = _ } ->
      Run ("diff", [file1; file2]) :: acc
    | Merge_files_into (srcs, extras, target) ->
      Sh (Printf.sprintf
            "{ echo -ne %s; cat %s; } | sort -u > %s"
            (Filename.quote (List.map extras ~f:(sprintf "%s\n")
                             |> String.concat ~sep:""))
            (List.map srcs ~f:quote_for_shell
             |> String.concat ~sep:" ")
            (quote_for_shell target))
      :: acc
  and block act =
    match List.rev (loop act []) with
    | [] -> [Run ("true", [])]
    | l -> l
  in
  block act

let quote s = Pp.string (quote_for_shell s)

let rec pp = function
  | Run (prog, args) ->
    Pp.hovbox ~indent:2
      (quote prog
       :: List.concat_map args ~f:(fun arg ->
         [Pp.space; quote arg]))
  | Chdir dir ->
    Pp.hovbox ~indent:2
      [ Pp.string "cd"
      ; Pp.space
      ; quote dir
      ]
  | Setenv (k, v) ->
    Pp.concat [Pp.string k; Pp.string "="; quote v]
  | Sh s ->
    Pp.string s
  | Redirect (l, outputs, dest) ->
    let body =
      match l with
      | [x] -> pp x
      | l ->
        Pp.box
          [ Pp.hvbox ~indent:2
              [ Pp.char '{'
              ; Pp.space
              ; Pp.hvbox [Pp.list l ~f:(fun x -> Pp.seq (pp x) (Pp.char ';'))
                             ~sep:Pp.space]
              ]
          ; Pp.space
          ; Pp.char '}'
          ]
    in
    Pp.hovbox ~indent:2
      [ body
      ; Pp.space
      ; Pp.string (match outputs with
          | Stdout -> ">"
          | Stderr -> "2>"
          | Outputs -> "&>")
      ; Pp.space
      ; quote
          (match dest with
           | Dev_null -> "/dev/null"
           | File fn -> fn)
      ]

let rec pp_seq = function
  | [] -> Pp.string "true"
  | [x] -> pp x
  | x :: l ->
    Pp.concat
      [ pp x
      ; Pp.char ';'
      ; Pp.cut
      ; pp_seq l
      ]

let pp act = pp_seq (simplify act)
