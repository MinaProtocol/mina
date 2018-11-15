open! Stdune
open Import
open Fiber.O

type exec_context =
  { context : Context.t option
  ; purpose : Process.purpose
  }

let get_std_output : _ -> Process.std_output_to = function
  | None          -> Terminal
  | Some (fn, oc) ->
    Opened_file { filename = fn
                ; tail = false
                ; desc = Channel oc }


let exec_run_direct ~ectx ~dir ~env ~stdout_to ~stderr_to prog args =
  begin match ectx.context with
  | None
  | Some { Context.for_host = None; _ } -> ()
  | Some ({ Context.for_host = Some host; _ } as target) ->
    let invalid_prefix prefix =
      match Path.descendant prog ~of_:prefix with
      | None -> ()
      | Some _ ->
        die "Context %s has a host %s.@.It's not possible to execute binary %a \
             in it.@.@.This is a bug and should be reported upstream."
          target.name host.name Path.pp prog in
    invalid_prefix (Path.relative Path.build_dir target.name);
    invalid_prefix (Path.relative Path.build_dir ("install/" ^ target.name));
  end;
  Process.run Strict ~dir ~env
    ~stdout_to ~stderr_to
    ~purpose:ectx.purpose
    prog args

let exec_run ~stdout_to ~stderr_to =
  let stdout_to = get_std_output stdout_to in
  let stderr_to = get_std_output stderr_to in
  exec_run_direct ~stdout_to ~stderr_to

let exec_echo stdout_to str =
  Fiber.return
    (match stdout_to with
     | None -> print_string str; flush stdout
     | Some (_, oc) -> output_string oc str)

let rec exec t ~ectx ~dir ~env ~stdout_to ~stderr_to =
  match (t : Action.t) with
  | Run (Error e, _) ->
    Action.Prog.Not_found.raise e
  | Run (Ok prog, args) ->
    exec_run ~ectx ~dir ~env ~stdout_to ~stderr_to prog args
  | Chdir (dir, t) ->
    exec t ~ectx ~dir ~env ~stdout_to ~stderr_to
  | Setenv (var, value, t) ->
    exec t ~ectx ~dir ~stdout_to ~stderr_to
      ~env:(Env.add env ~var ~value)
  | Redirect (Stdout, fn, Echo s) ->
    Io.write_file fn (String.concat s ~sep:" ");
    Fiber.return ()
  | Redirect (outputs, fn, Run (Ok prog, args)) ->
    let out = Process.File fn in
    let stdout_to, stderr_to =
      match outputs with
      | Stdout -> (out, get_std_output stderr_to)
      | Stderr -> (get_std_output stdout_to, out)
      | Outputs -> (out, out)
    in
    exec_run_direct ~ectx ~dir ~env ~stdout_to ~stderr_to prog args
  | Redirect (outputs, fn, t) ->
    redirect ~ectx ~dir outputs fn t ~env ~stdout_to ~stderr_to
  | Ignore (outputs, t) ->
    redirect ~ectx ~dir outputs Config.dev_null t ~env ~stdout_to ~stderr_to
  | Progn l ->
    exec_list l ~ectx ~dir ~env ~stdout_to ~stderr_to
  | Echo strs -> exec_echo stdout_to (String.concat strs ~sep:" ")
  | Cat fn ->
    Io.with_file_in fn ~f:(fun ic ->
      let oc =
        match stdout_to with
        | None -> stdout
        | Some (_, oc) -> oc
      in
      Io.copy_channels ic oc);
    Fiber.return ()
  | Copy (src, dst) ->
    Io.copy_file ~src ~dst ();
    Fiber.return ()
  | Symlink (src, dst) ->
    if Sys.win32 then
      Io.copy_file ~src ~dst ()
    else begin
      let src =
        match Path.parent dst with
        | None -> Path.to_string src
        | Some from -> Path.reach ~from src
      in
      let dst = Path.to_string dst in
      match Unix.readlink dst with
      | target ->
        if target <> src then begin
          (* @@DRA Win32 remove read-only attribute needed when symlinking enabled *)
          Unix.unlink dst;
          Unix.symlink src dst
        end
      | exception _ ->
        Unix.symlink src dst
    end;
    Fiber.return ()
  | Copy_and_add_line_directive (src, dst) ->
    Io.with_file_in src ~f:(fun ic ->
      Io.with_file_out dst ~f:(fun oc ->
        let fn = Path.drop_optional_build_context src in
        output_string oc
          (Utils.line_directive
             ~filename:(Path.to_string fn)
             ~line_number:1);
        Io.copy_channels ic oc));
    Fiber.return ()
  | System cmd ->
    let path, arg =
      Utils.system_shell_exn ~needed_to:"interpret (system ...) actions"
    in
    exec_run ~ectx ~dir ~env ~stdout_to ~stderr_to path [arg; cmd]
  | Bash cmd ->
    exec_run ~ectx ~dir ~env ~stdout_to ~stderr_to
      (Utils.bash_exn ~needed_to:"interpret (bash ...) actions")
      ["-e"; "-u"; "-o"; "pipefail"; "-c"; cmd]
  | Write_file (fn, s) ->
    Io.write_file fn s;
    Fiber.return ()
  | Rename (src, dst) ->
    Unix.rename (Path.to_string src) (Path.to_string dst);
    Fiber.return ()
  | Remove_tree path ->
    Path.rm_rf path;
    Fiber.return ()
  | Mkdir path ->
    Path.mkdir_p path;
    Fiber.return ()
  | Digest_files paths ->
    let s =
      let data =
        List.map paths ~f:(fun fn ->
          (Path.to_string fn, Utils.Cached_digest.file fn))
      in
      Digest.string
        (Marshal.to_string data [])
    in
    exec_echo stdout_to s
  | Diff { optional; file1; file2; mode } ->
    let compare_files =
      match mode with
      | Text_jbuild | Binary -> Io.compare_files
      | Text -> Io.compare_text_files
    in
    if (optional && not (Path.exists file1 && Path.exists file2)) ||
       compare_files file1 file2 = Eq then
      Fiber.return ()
    else begin
      let is_copied_from_source_tree file =
        match Path.drop_build_context file with
        | None -> false
        | Some file -> Path.exists file
      in
      if is_copied_from_source_tree file1 &&
         not (is_copied_from_source_tree file2) then begin
        Promotion.File.register
          { src = file2
          ; dst = Option.value_exn (Path.drop_build_context file1)
          }
      end;
      if mode = Binary then
        die "@{<error>Error@}: Files %s and %s differ."
          (Path.to_string_maybe_quoted file1)
          (Path.to_string_maybe_quoted file2)
      else
        Print_diff.print file1 file2
          ~skip_trailing_cr:(mode = Text && Sys.win32)
    end
  | Merge_files_into (sources, extras, target) ->
    let lines =
      List.fold_left
        ~init:(String.Set.of_list extras)
        ~f:(fun set source_path ->
          Io.lines_of_file source_path
          |> String.Set.of_list
          |> String.Set.union set
        )
        sources
    in
    Io.write_lines target (String.Set.to_list lines);
    Fiber.return ()

and redirect outputs fn t ~ectx ~dir ~env ~stdout_to ~stderr_to =
  let oc = Io.open_out fn in
  let out = Some (fn, oc) in
  let stdout_to, stderr_to =
    match outputs with
    | Stdout -> (out, stderr_to)
    | Stderr -> (stdout_to, out)
    | Outputs -> (out, out)
  in
  exec t ~ectx ~dir ~env ~stdout_to ~stderr_to >>| fun () ->
  close_out oc

and exec_list l ~ectx ~dir ~env ~stdout_to ~stderr_to =
  match l with
  | [] ->
    Fiber.return ()
  | [t] ->
    exec t ~ectx ~dir ~env ~stdout_to ~stderr_to
  | t :: rest ->
    exec t ~ectx ~dir ~env ~stdout_to ~stderr_to >>= fun () ->
    exec_list rest ~ectx ~dir ~env ~stdout_to ~stderr_to

let exec ~targets ~context ~env t =
  let env =
    match (context : Context.t option), env with
    | _ , Some e -> e
    | None, None   -> Env.initial
    | Some c, None -> c.env
  in
  let purpose = Process.Build_job targets in
  let ectx = { purpose; context } in
  exec t ~ectx ~dir:Path.root ~env ~stdout_to:None ~stderr_to:None
