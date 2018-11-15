open! Stdune
open Import

open Fiber.O

let print ?(skip_trailing_cr=Sys.win32) path1 path2 =
  let dir, file1, file2 =
    match
      Path.extract_build_context_dir path1,
      Path.extract_build_context_dir path2
    with
    | Some (dir1, f1), Some (dir2, f2) when Path.equal dir1 dir2 ->
      (dir1, Path.to_string f1, Path.to_string f2)
    | _ ->
      (Path.root, Path.to_string path1, Path.to_string path2)
  in
  let loc = Loc.in_file file1 in
  let fallback () =
    die "%aFiles %s and %s differ." Errors.print loc
      (Path.to_string_maybe_quoted path1)
      (Path.to_string_maybe_quoted path2)
  in
  let normal_diff () =
    match Bin.which ~path:(Env.path Env.initial) "diff" with
    | None -> fallback ()
    | Some prog ->
      Format.eprintf "%a@?" Errors.print loc;
      Process.run ~dir ~env:Env.initial Strict prog
        (List.concat
           [ ["-u"]
           ; if skip_trailing_cr then ["--strip-trailing-cr"] else []
           ; [ file1; file2 ]
           ])
      >>= fun () ->
      fallback ()
  in
  match !Clflags.diff_command with
  | Some "-" -> fallback ()
  | Some cmd ->
    let sh, arg = Utils.system_shell_exn ~needed_to:"print diffs" in
    let cmd =
      sprintf "%s %s %s" cmd (quote_for_shell file1) (quote_for_shell file2)
    in
    Process.run ~dir ~env:Env.initial Strict sh [arg; cmd]
    >>= fun () ->
    die "command reported no differences: %s"
      (if Path.is_root dir then
         cmd
       else
         sprintf "cd %s && %s" (quote_for_shell (Path.to_string dir)) cmd)
  | None ->
    if Config.inside_dune then
      fallback ()
    else
      match Bin.which ~path:(Env.path Env.initial) "patdiff" with
      | None -> normal_diff ()
      | Some prog ->
        Process.run ~dir ~env:Env.initial Strict prog
          [ "-keep-whitespace"
          ; "-location-style"; "omake"
          ; if Lazy.force Colors.stderr_supports_colors then
              "-unrefined"
            else
              "-ascii"
          ; file1
          ; file2
          ]
        >>= fun () ->
        (* Use "diff" if "patdiff" reported no differences *)
        normal_diff ()
