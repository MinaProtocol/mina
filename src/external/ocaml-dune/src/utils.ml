open! Stdune
open Import

let system_shell_exn =
  let cmd, arg, os =
    if Sys.win32 then
      ("cmd", "/c", "on Windows")
    else
      ("sh", "-c", "")
  in
  let bin = lazy (Bin.which ~path:(Env.path Env.initial) cmd) in
  fun ~needed_to ->
    match Lazy.force bin with
    | Some path -> (path, arg)
    | None ->
      die "I need %s to %s but I couldn't find it :(\n\
           Who doesn't have %s%s?!"
        cmd needed_to cmd os

let bash_exn =
  let bin = lazy (Bin.which ~path:(Env.path Env.initial) "bash") in
  fun ~needed_to ->
    match Lazy.force bin with
    | Some path -> path
    | None ->
      die "I need bash to %s but I couldn't find it :("
        needed_to

let signal_name =
  let table =
    let open Sys in
    [ sigabrt   , "ABRT"
    ; sigalrm   , "ALRM"
    ; sigfpe    , "FPE"
    ; sighup    , "HUP"
    ; sigill    , "ILL"
    ; sigint    , "INT"
    ; sigkill   , "KILL"
    ; sigpipe   , "PIPE"
    ; sigquit   , "QUIT"
    ; sigsegv   , "SEGV"
    ; sigterm   , "TERM"
    ; sigusr1   , "USR1"
    ; sigusr2   , "USR2"
    ; sigchld   , "CHLD"
    ; sigcont   , "CONT"
    ; sigstop   , "STOP"
    ; sigtstp   , "TSTP"
    ; sigttin   , "TTIN"
    ; sigttou   , "TTOU"
    ; sigvtalrm , "VTALRM"
    ; sigprof   , "PROF"
    (* These ones are only available in OCaml >= 4.03 *)
    ; -22       , "BUS"
    ; -23       , "POLL"
    ; -24       , "SYS"
    ; -25       , "TRAP"
    ; -26       , "URG"
    ; -27       , "XCPU"
    ; -28       , "XFSZ"
    ]
  in
  fun n ->
    match List.assoc table n with
    | None -> sprintf "%d\n" n
    | Some s -> s

type target_kind =
  | Regular of string * Path.t
  | Alias   of string * Path.t
  | Other of Path.t

let analyse_target fn =
  match Path.extract_build_context fn with
  | Some (".aliases", sub) -> begin
      match Path.split_first_component sub with
      | None -> Other fn
      | Some (ctx, fn) ->
        if Path.is_root fn then
          Other fn
        else
          let basename =
            match String.rsplit2 (Path.basename fn) ~on:'-' with
            | None -> assert false
            | Some (name, digest) ->
              assert (String.length digest = 32);
              name
          in
          Alias (ctx, Path.relative (Path.parent_exn fn) basename)
    end
  | Some ("install", _) -> Other fn
  | Some (ctx, sub) -> Regular (ctx, sub)
  | None ->
    Other fn

let describe_target fn =
  let ctx_suffix = function
    | "default" -> ""
    | ctx -> sprintf " (context %s)" ctx
  in
  match analyse_target fn with
  | Alias (ctx, p) ->
    sprintf "alias %s%s" (Path.to_string_maybe_quoted p) (ctx_suffix ctx)
  | Regular (ctx, fn) ->
    sprintf "%s%s" (Path.to_string_maybe_quoted fn) (ctx_suffix ctx)
  | Other fn ->
    Path.to_string_maybe_quoted fn

let library_object_directory ~dir name =
  Path.relative dir ("." ^ Lib_name.Local.to_string name ^ ".objs")

let library_private_obj_dir ~obj_dir =
  Path.relative obj_dir ".private"

(* Use "eobjs" rather than "objs" to avoid a potential conflict with a
   library of the same name *)
let executable_object_directory ~dir name =
  Path.relative dir ("." ^ name ^ ".eobjs")

let program_not_found ?context ?hint ~loc prog =
  Errors.fail_opt loc
    "@{<error>Error@}: Program %s not found in the tree or in PATH%s%a"
    (String.maybe_quoted prog)
    (match context with
     | None -> ""
     | Some name -> sprintf " (context: %s)" name)
    (fun fmt -> function
       | None -> ()
       | Some h -> Format.fprintf fmt "@ Hint: %s" h)
    hint

let library_not_found ?context ?hint lib =
  die "@{<error>Error@}: Library %s not found%s%a" (String.maybe_quoted lib)
    (match context with
     | None -> ""
     | Some name -> sprintf " (context: %s)" name)
    (fun fmt -> function
       | None -> ()
       | Some h -> Format.fprintf fmt "@ Hint: %s" h)
    hint

let install_file ~(package : Package.Name.t) ~findlib_toolchain =
  let package = Package.Name.to_string package in
  match findlib_toolchain with
  | None -> package ^ ".install"
  | Some x -> sprintf "%s-%s.install" package x

let line_directive ~filename:fn ~line_number =
  let directive =
    match Filename.extension fn with
    | ".c" | ".cpp" | ".h" -> "line"
    | _ -> ""
  in
  sprintf "#%s %d %S\n" directive line_number fn

let local_bin p = Path.relative p ".bin"

module type Persistent_desc = sig
  type t
  val name : string
  val version : int
end

module Persistent(D : Persistent_desc) = struct
  let magic = sprintf "DUNE-%sv%d:" D.name D.version

  let to_out_string (v : D.t) =
    magic ^ Marshal.to_string v []

  let dump file (v : D.t) =
    Io.with_file_out file ~f:(fun oc ->
      output_string oc magic;
      Marshal.to_channel oc v [])

  let load file =
    if Path.exists file then
      Io.with_file_in file ~f:(fun ic ->
        match really_input_string ic (String.length magic) with
        | exception End_of_file -> None
        | s ->
          if s = magic then
            Some (Marshal.from_channel ic : D.t)
          else
            None)
    else
      None
end

module Cached_digest = struct
  type file =
    { mutable digest            : Digest.t
    ; mutable timestamp         : float
    ; mutable timestamp_checked : int
    }

  type t =
    { mutable checked_key : int
    ; mutable table       : (Path.t, file) Hashtbl.t
    }

  let cache =
    { checked_key = 0
    ; table       = Hashtbl.create 1024
    }

  let refresh fn =
    let digest = Digest.file (Path.to_string fn) in
    Hashtbl.replace cache.table ~key:fn
      ~data:{ digest
            ; timestamp = (Unix.stat (Path.to_string fn)).st_mtime
            ; timestamp_checked = cache.checked_key
            };
    digest

  let file fn =
    match Hashtbl.find cache.table fn with
    | Some x ->
      if x.timestamp_checked = cache.checked_key then
        x.digest
      else begin
        let mtime = (Unix.stat (Path.to_string fn)).st_mtime in
        if mtime <> x.timestamp then begin
          let digest = Digest.file (Path.to_string fn) in
          x.digest    <- digest;
          x.timestamp <- mtime;
        end;
        x.timestamp_checked <- cache.checked_key;
        x.digest
      end
    | None ->
      refresh fn

  let remove fn = Hashtbl.remove cache.table fn

  let db_file = Path.relative Path.build_dir ".digest-db"

  module P = Persistent(struct
      type nonrec t = t
      let name = "DIGEST-DB"
      let version = 1
    end)

  let dump () =
    if Path.build_dir_exists () then P.dump db_file cache

  let load () =
    match P.load db_file with
    | None -> ()
    | Some c ->
      cache.checked_key <- c.checked_key + 1;
      cache.table <- c.table
end
