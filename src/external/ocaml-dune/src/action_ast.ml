open! Stdune
open Import
open Dune_lang.Decoder

let () = let module M = Stanza in ()

module Outputs = struct
  include Action_intf.Outputs

  let to_string = function
    | Stdout -> "stdout"
    | Stderr -> "stderr"
    | Outputs -> "outputs"
end
module Diff_mode = Action_intf.Diff_mode

module Make
    (Program : Dune_lang.Conv)
    (Path    : Dune_lang.Conv)
    (String  : Dune_lang.Conv)
    (Ast : Action_intf.Ast
     with type program := Program.t
     with type path    := Path.t
     with type string  := String.t) =
struct
  include Ast

  let decode =
    let path = Path.decode and string = String.decode in
    Dune_lang.Decoder.fix (fun t ->
      sum
        [ "run",
          (let%map prog = Program.decode
           and args = repeat String.decode
           in
           Run (prog, args))
        ; "chdir",
          (let%map dn = path
           and t = t
           in
           Chdir (dn, t))
        ; "setenv",
          (let%map k = string
           and v = string
           and t = t
           in
           Setenv (k, v, t))
        ; "with-stdout-to",
          (let%map fn = path
           and t = t
           in
           Redirect (Stdout, fn, t))
        ; "with-stderr-to",
          (let%map fn = path
           and t = t
           in
           Redirect (Stderr, fn, t))
        ; "with-outputs-to",
          (let%map fn = path
           and t = t
           in
           Redirect (Outputs, fn, t))
        ; "ignore-stdout",
          (t >>| fun t -> Ignore (Stdout, t))
        ; "ignore-stderr",
          (t >>| fun t -> Ignore (Stderr, t))
        ; "ignore-outputs",
          (t >>| fun t -> Ignore (Outputs, t))
        ; "progn",
          (repeat t >>| fun l -> Progn l)
        ; "echo",
          (let%map x = string
           and xs = repeat string
           in
           Echo (x :: xs))
        ; "cat",
          (path >>| fun x -> Cat x)
        ; "copy",
          (let%map src = path
           and dst = path
           in
           Copy (src, dst))
        ; "copy#",
          (let%map src = path
           and dst = path
           in
           Copy_and_add_line_directive (src, dst))
        ; "copy-and-add-line-directive",
          (let%map src = path
           and dst = path
           in
           Copy_and_add_line_directive (src, dst))
        ; "system",
          (string >>| fun cmd -> System cmd)
        ; "bash",
          (string >>| fun cmd -> Bash cmd)
        ; "write-file",
          (let%map fn = path
           and s = string
           in
           Write_file (fn, s))
        ; "diff",
          (let%map file1 = path
           and file2 = path
           and kind = Stanza.file_kind ()
           in
           let mode =
             match kind with
             | Jbuild -> Diff_mode.Text_jbuild
             | Dune   -> Text
           in
           Diff { optional = false; file1; file2; mode })
        ; "diff?",
          (let%map file1 = path
           and file2 = path
           and kind = Stanza.file_kind ()
           in
           let mode =
             match kind with
             | Jbuild -> Diff_mode.Text_jbuild
             | Dune   -> Text
           in
           Diff { optional = true; file1; file2; mode })
        ; "cmp",
          (let%map () = Syntax.since Stanza.syntax (1, 0)
           and file1 = path
           and file2 = path
           in
           Diff { optional = false; file1; file2; mode = Binary })
        ])

  let rec encode =
    let open Dune_lang in
    let program = Program.encode in
    let string = String.encode in
    let path = Path.encode in
    function
    | Run (a, xs) ->
      List (atom "run" :: program a :: List.map xs ~f:string)
    | Chdir (a, r) -> List [atom "chdir" ; path a ; encode r]
    | Setenv (k, v, r) -> List [atom "setenv" ; string k ; string v ; encode r]
    | Redirect (outputs, fn, r) ->
      List [ atom (sprintf "with-%s-to" (Outputs.to_string outputs))
           ; path fn
           ; encode r
           ]
    | Ignore (outputs, r) ->
      List [ atom (sprintf "ignore-%s" (Outputs.to_string outputs))
           ; encode r
           ]
    | Progn l -> List (atom "progn" :: List.map l ~f:encode)
    | Echo xs ->
      List (atom "echo" :: List.map xs ~f:string)
    | Cat x -> List [atom "cat"; path x]
    | Copy (x, y) ->
      List [atom "copy"; path x; path y]
    | Symlink (x, y) ->
      List [atom "symlink"; path x; path y]
    | Copy_and_add_line_directive (x, y) ->
      List [atom "copy#"; path x; path y]
    | System x -> List [atom "system"; string x]
    | Bash   x -> List [atom "bash"; string x]
    | Write_file (x, y) -> List [atom "write-file"; path x; string y]
    | Rename (x, y) -> List [atom "rename"; path x; path y]
    | Remove_tree x -> List [atom "remove-tree"; path x]
    | Mkdir x       -> List [atom "mkdir"; path x]
    | Digest_files paths -> List [atom "digest-files";
                                  List (List.map paths ~f:path)]
    | Diff { optional; file1; file2; mode = Binary} ->
      assert (not optional);
      List [atom "cmp"; path file1; path file2]
    | Diff { optional = false; file1; file2; mode = _ } ->
      List [atom "diff"; path file1; path file2]
    | Diff { optional = true; file1; file2; mode = _ } ->
      List [atom "diff?"; path file1; path file2]
    | Merge_files_into (srcs, extras, target) ->
      List
        [ atom "merge-files-into"
        ; List (List.map ~f:path srcs)
        ; List (List.map ~f:string extras)
        ; path target
        ]

  let run prog args = Run (prog, args)
  let chdir path t = Chdir (path, t)
  let setenv var value t = Setenv (var, value, t)
  let with_stdout_to path t = Redirect (Stdout, path, t)
  let with_stderr_to path t = Redirect (Stderr, path, t)
  let with_outputs_to path t = Redirect (Outputs, path, t)
  let ignore_stdout t = Ignore (Stdout, t)
  let ignore_stderr t = Ignore (Stderr, t)
  let ignore_outputs t = Ignore (Outputs, t)
  let progn ts = Progn ts
  let echo s = Echo s
  let cat path = Cat path
  let copy a b = Copy (a, b)
  let symlink a b = Symlink (a, b)
  let copy_and_add_line_directive a b = Copy_and_add_line_directive (a, b)
  let system s = System s
  let bash s = Bash s
  let write_file p s = Write_file (p, s)
  let rename a b = Rename (a, b)
  let remove_tree path = Remove_tree path
  let mkdir path = Mkdir path
  let digest_files files = Digest_files files
  let diff ?(optional=false) ?(mode=Diff_mode.Text) file1 file2 =
    Diff { optional; file1; file2; mode }
end
