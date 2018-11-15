open! Stdune
open Import
open Fiber.O

type accepted_codes =
  | These of int list
  | All

let code_is_ok accepted_codes n =
  match accepted_codes with
  | These set -> List.mem n ~set
  | All -> true

type ('a, 'b) failure_mode =
  | Strict : ('a, 'a) failure_mode
  | Accept : accepted_codes -> ('a, ('a, int) result) failure_mode

let accepted_codes : type a b. (a, b) failure_mode -> accepted_codes = function
  | Strict -> These [0]
  | Accept (These codes) -> These (0 :: codes)
  | Accept All -> All

let map_result
  : type a b. (a, b) failure_mode -> int Fiber.t -> f:(unit -> a) -> b Fiber.t
  = fun mode t ~f ->
    match mode with
    | Strict   -> t >>| fun _ -> f ()
    | Accept _ ->
      t >>| function
      | 0 -> Ok (f ())
      | n -> Error n

type std_output_to =
  | Terminal
  | File        of Path.t
  | Opened_file of opened_file

and opened_file =
  { filename : Path.t
  ; desc     : opened_file_desc
  ; tail     : bool
  }

and opened_file_desc =
  | Fd      of Unix.file_descr
  | Channel of out_channel

type purpose =
  | Internal_job
  | Build_job of Path.Set.t

module Temp = struct
  let tmp_files = ref Path.Set.empty
  let () =
    at_exit (fun () ->
      let fns = !tmp_files in
      tmp_files := Path.Set.empty;
      Path.Set.iter fns ~f:Path.unlink_no_err)

  let create prefix suffix =
    let fn = Path.of_string (Filename.temp_file prefix suffix) in
    tmp_files := Path.Set.add !tmp_files fn;
    fn

  let destroy fn =
    Path.unlink_no_err fn;
    tmp_files := Path.Set.remove !tmp_files fn
end

module Fancy = struct
  let split_prog s =
    let len = String.length s in
    if len = 0 then
      "", "", ""
    else begin
      let rec find_prog_start i =
        if i < 0 then
          0
        else
          match s.[i] with
          | '\\' | '/' -> (i + 1)
          | _ -> find_prog_start (i - 1)
      in
      let prog_end =
        match s.[len - 1] with
        | '"' -> len - 1
        | _   -> len
      in
      let prog_start = find_prog_start (prog_end - 1) in
      let prog_end =
        match String.index_from s prog_start '.' with
        | exception _ -> prog_end
        | i -> i
      in
      let before = String.take s prog_start in
      let after = String.drop s prog_end in
      let prog = String.sub s ~pos:prog_start ~len:(prog_end - prog_start) in
      before, prog, after
    end

  let colorize_prog s =
    let len = String.length s in
    if len = 0 then
      s
    else
      let before, prog, after = split_prog s in
      before ^ Colors.colorize ~key:prog prog ^ after

  let rec colorize_args = function
    | [] -> []
    | "-o" :: fn :: rest ->
      "-o" :: Colors.(apply_string output_filename) fn :: colorize_args rest
    | x :: rest -> x :: colorize_args rest

  let command_line ~prog ~args ~dir ~stdout_to ~stderr_to =
    let prog = Path.reach_for_running ?from:dir prog in
    let quote = quote_for_shell in
    let prog = colorize_prog (quote prog) in
    let s =
      String.concat (prog :: colorize_args (List.map args ~f:quote)) ~sep:" "
    in
    let s =
      match dir with
      | None -> s
      | Some dir -> sprintf "(cd %s && %s)" (Path.to_string dir) s
    in
    match stdout_to, stderr_to with
    | (File fn1 | Opened_file { filename = fn1; _ }),
      (File fn2 | Opened_file { filename = fn2; _ }) when Path.equal fn1 fn2 ->
      sprintf "%s &> %s" s (Path.to_string fn1)
    | _ ->
      let s =
        match stdout_to with
        | Terminal -> s
        | File fn | Opened_file { filename = fn; _ } ->
          sprintf "%s > %s" s (Path.to_string fn)
      in
      match stderr_to with
      | Terminal -> s
      | File fn | Opened_file { filename = fn; _ } ->
        sprintf "%s 2> %s" s (Path.to_string fn)

  let pp_purpose ppf = function
    | Internal_job ->
      Format.fprintf ppf "(internal)"
    | Build_job targets ->
      let rec split_paths targets_acc ctxs_acc = function
        | [] -> List.rev targets_acc, String.Set.(to_list (of_list ctxs_acc))
        | path :: rest ->
          let add_ctx ctx acc = if ctx = "default" then acc else ctx :: acc in
          match Utils.analyse_target path with
          | Other path ->
            split_paths (Path.to_string path :: targets_acc) ctxs_acc rest
          | Regular (ctx, filename) ->
            split_paths (Path.to_string filename :: targets_acc)
              (add_ctx ctx ctxs_acc) rest
          | Alias (ctx, name) ->
            split_paths (("alias " ^ Path.to_string name) :: targets_acc)
              (add_ctx ctx ctxs_acc) rest
      in
      let targets = Path.Set.to_list targets in
      let target_names, contexts = split_paths [] [] targets in
      let target_names_grouped_by_prefix =
        List.map target_names ~f:Filename.split_extension_after_dot
        |> String.Map.of_list_multi
        |> String.Map.to_list
      in
      let pp_comma ppf () = Format.fprintf ppf "," in
      let pp_group ppf (prefix, suffixes) =
        match suffixes with
        | [] -> assert false
        | [suffix] -> Format.fprintf ppf "%s%s" prefix suffix
        | _ ->
          Format.fprintf ppf "%s{%a}"
            prefix
            (Format.pp_print_list ~pp_sep:pp_comma Format.pp_print_string)
            suffixes
      in
      let pp_contexts ppf = function
        | [] -> ()
        | ctxs ->
          Format.fprintf ppf " @{<details>[%a]@}"
            (Format.pp_print_list ~pp_sep:pp_comma
               (fun ppf s -> Format.fprintf ppf "%s" s))
            ctxs
      in
      Format.fprintf ppf "%a%a"
        (Format.pp_print_list ~pp_sep:pp_comma pp_group)
        target_names_grouped_by_prefix
        pp_contexts
        contexts;
end

let get_std_output ~default = function
  | Terminal -> (default, None)
  | File fn ->
    let fd = Unix.openfile (Path.to_string fn)
               [O_WRONLY; O_CREAT; O_TRUNC; O_SHARE_DELETE] 0o666 in
    (fd, Some (Fd fd))
  | Opened_file { desc; tail; _ } ->
    let fd =
      match desc with
      | Fd      fd -> fd
      | Channel oc -> flush oc; Unix.descr_of_out_channel oc
    in
    (fd, Option.some_if tail desc)

let close_std_output = function
  | None -> ()
  | Some (Fd      fd) -> Unix.close fd
  | Some (Channel oc) -> close_out  oc

let gen_id =
  let next = ref (-1) in
  fun () -> incr next; !next

let cmdline_approximate_length prog args =
  List.fold_left args ~init:(String.length prog) ~f:(fun acc arg ->
    acc + String.length arg)

let run_internal ?dir ?(stdout_to=Terminal) ?(stderr_to=Terminal) ~env ~purpose
      fail_mode prog args =
  Scheduler.wait_for_available_job ()
  >>= fun scheduler ->
  let display = Scheduler.display scheduler in
  let dir =
    match dir with
    | Some p ->
      if Path.is_root p then
        None
      else
        Some p
    | None -> dir
  in
  let id = gen_id () in
  let ok_codes = accepted_codes fail_mode in
  let command_line = Fancy.command_line ~prog ~args ~dir ~stdout_to ~stderr_to in
  if display = Verbose then
    Format.eprintf "@{<kwd>Running@}[@{<id>%d@}]: %s@." id
      (Colors.strip_colors_for_stderr command_line);
  let prog_str = Path.reach_for_running ?from:dir prog in
  let args, response_file =
    if Sys.win32 && cmdline_approximate_length prog_str args >= 1024 then
      match Response_file.get ~prog with
      | Not_supported -> (args, None)
      | Zero_terminated_strings arg ->
        let fn = Temp.create "responsefile" ".data" in
        Io.with_file_out fn ~f:(fun oc ->
          List.iter args ~f:(fun arg ->
            output_string oc arg;
            output_char oc '\000'));
        ([arg; Path.to_string fn], Some fn)
    else
      (args, None)
  in
  let argv = prog_str :: args in
  let output_filename, stdout_fd, stderr_fd, to_close =
    match stdout_to, stderr_to with
    | (Terminal, _ | _, Terminal) when !Clflags.capture_outputs ->
      let fn = Temp.create "dune" ".output" in
      let fd = Unix.openfile (Path.to_string fn) [O_WRONLY; O_SHARE_DELETE] 0 in
      (Some fn, fd, fd, Some fd)
    | _ ->
      (None, Unix.stdout, Unix.stderr, None)
  in
  let stdout, close_stdout = get_std_output stdout_to ~default:stdout_fd in
  let stderr, close_stderr = get_std_output stderr_to ~default:stderr_fd in
  let run () =
    Spawn.spawn ()
      ~prog:prog_str
      ~argv
      ~env:(Spawn.Env.of_array (Env.to_unix env))
      ~stdout
      ~stderr
  in
  let pid =
    match dir with
    | None -> run ()
    | Some dir -> Scheduler.with_chdir scheduler ~dir ~f:run
  in
  Option.iter to_close ~f:Unix.close;
  close_std_output close_stdout;
  close_std_output close_stderr;
  Scheduler.wait_for_process pid
  >>| fun exit_status ->
  Option.iter response_file ~f:Path.unlink;
  let output =
    match output_filename with
    | None -> ""
    | Some fn ->
      let s = Io.read_file fn in
      Temp.destroy fn;
      let len = String.length s in
      if len > 0 && s.[len - 1] <> '\n' then
        s ^ "\n"
      else
        s
  in
  Log.command (Scheduler.log scheduler) ~command_line ~output ~exit_status;
  let _, progname, _ = Fancy.split_prog prog_str in
  let print fmt = Errors.kerrf ~f:(Scheduler.print scheduler) fmt in
  match exit_status with
  | WEXITED n when code_is_ok ok_codes n ->
    if display = Verbose then begin
      if output <> "" then
        print "@{<kwd>Output@}[@{<id>%d@}]:\n%s" id output;
      if n <> 0 then
        print
          "@{<warning>Warning@}: Command [@{<id>%d@}] exited with code %d, \
           but I'm ignoring it, hope that's OK.\n" id n
    end else if output <> "" ||
                (display = Short && purpose <> Internal_job) then begin
      let pad = String.make (max 0 (12 - String.length progname)) ' ' in
      print "%s@{<ok>%s@} %a\n%s" pad progname Fancy.pp_purpose purpose output
    end;
    n
  | WEXITED n ->
    if display = Verbose then
      die "\n@{<kwd>Command@} [@{<id>%d@}] exited with code %d:\n\
           @{<prompt>$@} %s\n%s"
        id n
        (Colors.strip_colors_for_stderr command_line)
        (Colors.strip_colors_for_stderr output)
    else
      die "@{<error>%12s@} %a @{<error>(exit %d)@}\n\
           @{<details>%s@}\n\
           %s"
        progname Fancy.pp_purpose purpose n
        (Ansi_color.strip command_line)
        output
  | WSIGNALED n ->
    if display = Verbose then
      die "\n@{<kwd>Command@} [@{<id>%d@}] got signal %s:\n\
           @{<prompt>$@} %s\n%s"
        id (Utils.signal_name n)
        (Colors.strip_colors_for_stderr command_line)
        (Colors.strip_colors_for_stderr output)
    else
      die "@{<error>%12s@} %a @{<error>(got signal %s)@}\n\
           @{<details>%s@}\n\
           %s"
        progname Fancy.pp_purpose purpose (Utils.signal_name n)
        (Ansi_color.strip command_line)
        output
  | WSTOPPED _ -> assert false

let run ?dir ?stdout_to ?stderr_to ~env ?(purpose=Internal_job) fail_mode
      prog args =
  map_result fail_mode
    (run_internal ?dir ?stdout_to ?stderr_to ~env ~purpose fail_mode prog args)
    ~f:ignore

let run_capture_gen ?dir ?stderr_to ~env ?(purpose=Internal_job) fail_mode
      prog args ~f =
  let fn = Temp.create "dune" ".output" in
  map_result fail_mode
    (run_internal ?dir ~stdout_to:(File fn) ?stderr_to
       ~env ~purpose fail_mode prog args)
    ~f:(fun () ->
      let x = f fn in
      Temp.destroy fn;
      x)

let run_capture = run_capture_gen ~f:Io.read_file
let run_capture_lines = run_capture_gen ~f:Io.lines_of_file

let run_capture_line ?dir ?stderr_to ~env ?(purpose=Internal_job) fail_mode
      prog args =
  run_capture_gen ?dir ?stderr_to ~env ~purpose fail_mode prog args ~f:(fun fn ->
    match Io.lines_of_file fn with
    | [x] -> x
    | l ->
      let cmdline =
        let prog = Path.reach_for_running ?from:dir prog in
        let prog_display = String.concat (prog :: args) ~sep:" " in
        match dir with
        | None -> prog_display
        | Some dir -> sprintf "cd %s && %s" (Path.to_string dir) prog_display
      in
      match l with
      | [] ->
        die "command returned nothing: %s" cmdline
      | _ ->
        die "command returned too many lines: %s\n%s"
          cmdline (String.concat l ~sep:"\n"))
