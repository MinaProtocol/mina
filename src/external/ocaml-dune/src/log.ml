open! Stdune
open Import

type real =
  { oc      : out_channel
  ; buf     : Buffer.t
  ; ppf     : Format.formatter
  ; display : Config.Display.t
  }

type t = real option

let no_log = None

let create ?(display=Config.default.display) () =
  Path.ensure_build_dir_exists ();
  let oc = Io.open_out (Path.relative Path.build_dir "log") in
  Printf.fprintf oc "# %s\n# OCAMLPARAM: %s\n%!"
    (String.concat (List.map (Array.to_list Sys.argv) ~f:quote_for_shell) ~sep:" ")
    (match Env.get Env.initial "OCAMLPARAM" with
     | Some s -> Printf.sprintf "%S" s
     | None   -> "unset");
  let buf = Buffer.create 1024 in
  let ppf = Format.formatter_of_buffer buf in
  Some { oc; buf; ppf; display }

let info_internal { ppf; display; _ } str =
  let write ppf =
    List.iter (String.split_lines str) ~f:(function
      | "" -> Format.pp_print_string ppf "#\n"
      | s  -> Format.fprintf ppf "# %s\n" s);
    Format.pp_print_flush ppf ()
  in
  write ppf;
  if display = Verbose then print_to_console (Format.asprintf "%t" write)

let info t str =
  match t with
  | None -> ()
  | Some t -> info_internal t str

let infof t fmt =
  match t with
  | None -> Format.ikfprintf ignore Format.str_formatter fmt
  | Some t ->
    Format.kfprintf
      (fun ppf ->
         Format.pp_print_flush ppf ();
         let s = Buffer.contents t.buf in
         Buffer.clear t.buf;
         info_internal t s)
      t.ppf
      fmt

let command t ~command_line ~output ~exit_status =
  match t with
  | None -> ()
  | Some { oc; _ } ->
    Printf.fprintf oc "$ %s\n" (Ansi_color.strip command_line);
    List.iter (String.split_lines output) ~f:(fun s ->
      match Ansi_color.strip s with
      | "" -> output_string oc ">\n"
      | s  -> Printf.fprintf oc "> %s\n" s);
    (match (exit_status : Unix.process_status) with
     | WEXITED   0 -> ()
     | WEXITED   n -> Printf.fprintf oc "[%d]\n" n
     | WSIGNALED n -> Printf.fprintf oc "[got signal %s]\n" (Utils.signal_name n)
     | WSTOPPED  _ -> assert false);
    flush oc
