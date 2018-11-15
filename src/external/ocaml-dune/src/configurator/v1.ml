open! Stdune

(* we shadow this module on purpose because it's unusable without the build dir
   initialized *)
module Path = struct end
module Io = Io.String_path

let sprintf = Printf.sprintf
let eprintf = Printf.eprintf

let ( ^/ ) = Filename.concat

exception Fatal_error of string

let die fmt =
  Printf.ksprintf (fun s ->
    raise (Fatal_error s);
  ) fmt

type t =
  { name              : string
  ; dest_dir          : string
  ; ocamlc            : string
  ; log               : string -> unit
  ; mutable counter   : int
  ; ext_obj           : string
  ; c_compiler        : string
  ; stdlib_dir        : string
  ; ccomp_type        : string
  ; ocamlc_config     : string String.Map.t
  ; ocamlc_config_cmd : string
  }

let rec rm_rf dir =
  Array.iter (Sys.readdir dir) ~f:(fun fn ->
    let fn = dir ^/ fn in
    if Sys.is_directory fn then
      rm_rf fn
    else
      Unix.unlink fn);
  Unix.rmdir dir

module Temp = struct
  (* Copied from filename.ml and adapted for directories *)

  let prng = lazy(Random.State.make_self_init ())

  let gen_name ~temp_dir ~prefix ~suffix =
    let rnd = Random.State.bits (Lazy.force prng) land 0xFFFFFF in
    temp_dir ^/ (Printf.sprintf "%s%06x%s" prefix rnd suffix)

  let create ~prefix ~suffix ~mk =
    let temp_dir = Filename.get_temp_dir_name () in
    let rec try_name counter =
      let name = gen_name ~temp_dir ~prefix ~suffix in
      match mk name with
      | () -> name
      | exception (Unix.Unix_error _) when counter < 1000 ->
        try_name (counter + 1)
    in
    try_name 0

  let create_temp_dir ~prefix ~suffix =
    let dir = create ~prefix ~suffix ~mk:(fun name -> Unix.mkdir name 0o700) in
    at_exit (fun () -> rm_rf dir);
    dir
end

module Flags = struct
  let extract_words = String.extract_words

  let extract_comma_space_separated_words =
    String.extract_comma_space_separated_words

  let extract_blank_separated_words = String.extract_blank_separated_words

  let write_lines path s =
    Io.write_lines path s

  let write_sexp path s =
    let sexp = Dune_lang.List (List.map s ~f:(fun s -> Dune_lang.Quoted_string s)) in
    Io.write_file path (Dune_lang.to_string sexp ~syntax:Dune)
end

module Find_in_path = struct
  let path_sep =
    if Sys.win32 then
      ';'
    else
      ':'

  let get_path () =
    match Sys.getenv "PATH" with
    | exception Not_found -> []
    | s -> String.split s ~on:path_sep

  let exe = if Sys.win32 then ".exe" else ""

  let prog_not_found prog =
    die "Program %s not found in PATH" prog

  let best_prog dir prog =
    let fn = dir ^/ prog ^ ".opt" ^ exe in
    if Sys.file_exists fn then
      Some fn
    else
      let fn = dir ^/ prog ^ exe in
      if Sys.file_exists fn then
        Some fn
      else
        None

  let find_ocaml_prog prog =
    match
      List.find_map (get_path ()) ~f:(fun dir ->
        best_prog dir prog)
    with
    | None -> prog_not_found prog
    | Some fn -> fn

  let find prog =
    List.find_map (get_path ()) ~f:(fun dir ->
      let fn = dir ^/ prog ^ exe in
      Option.some_if (Sys.file_exists fn) fn)
end

let logf t fmt = Printf.ksprintf t.log fmt

let gen_id t =
  let n = t.counter in
  t.counter <- n + 1;
  n

type run_result =
  { exit_code : int
  ; stdout    : string
  ; stderr    : string
  }

let quote =
  let need_quote = function
    | ' ' | '\"' -> true
    | _          -> false
  in
  fun s ->
    if String.is_empty s || String.exists ~f:need_quote s
    then Filename.quote s
    else s

let command_line prog args =
  String.concat ~sep:" " (List.map (prog :: args) ~f:quote)

let run t ~dir cmd =
  logf t "run: %s" cmd;
  let n = gen_id t in
  let stdout_fn = t.dest_dir ^/ sprintf "stdout-%d" n in
  let stderr_fn = t.dest_dir ^/ sprintf "stderr-%d" n in
  let exit_code =
    Printf.ksprintf
      Sys.command "cd %s && %s > %s 2> %s"
      (Filename.quote dir)
      cmd
      (Filename.quote stdout_fn)
      (Filename.quote stderr_fn)
  in
  let stdout = Io.read_file stdout_fn in
  let stderr = Io.read_file stderr_fn in
  logf t "-> process exited with code %d" exit_code;
  logf t "-> stdout:";
  List.iter (String.split_lines stdout) ~f:(logf t " | %s");
  logf t "-> stderr:";
  List.iter (String.split_lines stderr) ~f:(logf t " | %s");
  { exit_code; stdout; stderr }

let run_capture_exn t ~dir cmd =
  let { exit_code; stdout; stderr } = run t ~dir cmd in
  if exit_code <> 0 then
    die "command exited with code %d: %s" exit_code cmd
  else if not (String.is_empty stderr) then
    die "command has non-empty stderr: %s" cmd
  else
    stdout

let run_ok t ~dir cmd = (run t ~dir cmd).exit_code = 0

let get_ocaml_config_var_exn ~ocamlc_config_cmd map var =
  match String.Map.find map var with
  | None -> die "variable %S not found in the output of `%s`" var ocamlc_config_cmd
  | Some s -> s

let ocaml_config_var t var = String.Map.find t.ocamlc_config var
let ocaml_config_var_exn t var =
  get_ocaml_config_var_exn t.ocamlc_config var
    ~ocamlc_config_cmd:t.ocamlc_config_cmd

let create ?dest_dir ?ocamlc ?(log=ignore) name =
  let dest_dir =
    match dest_dir with
    | Some dir -> dir
    | None -> Temp.create_temp_dir ~prefix:"ocaml-configurator" ~suffix:""
  in
  let ocamlc =
    match ocamlc with
    | Some fn -> fn
    | None -> Find_in_path.find_ocaml_prog "ocamlc"
  in
  let ocamlc_config_cmd = command_line ocamlc ["-config"] in
  let t =
    { name
    ; ocamlc
    ; log
    ; dest_dir
    ; counter = 0
    ; ext_obj       = ""
    ; c_compiler    = ""
    ; stdlib_dir    = ""
    ; ccomp_type    = ""
    ; ocamlc_config = String.Map.empty
    ; ocamlc_config_cmd
    }
  in
  let ocamlc_config =
    let ocamlc_config_output =
      run_capture_exn t ~dir:dest_dir ocamlc_config_cmd
      |> String.split_lines
    in
    match Ocaml_config.Vars.of_lines ocamlc_config_output with
    | Ok x -> x
    | Error msg ->
      die "Failed to parse the output of '%s':@\n\
           %s"
        ocamlc_config_cmd msg
  in
  let get = get_ocaml_config_var_exn ocamlc_config ~ocamlc_config_cmd in
  let c_compiler =
    match String.Map.find ocamlc_config "c_compiler" with
    | Some c_comp -> c_comp ^ " " ^ get "ocamlc_cflags"
    | None -> get "bytecomp_c_compiler"
  in
  { t with
    ocamlc_config
  ; ext_obj    = get "ext_obj"
  ; c_compiler
  ; stdlib_dir = get "standard_library"
  ; ccomp_type = get "ccomp_type"
  }

let need_to_compile_and_link_separately t =
  (* Vague memory from writing the discover.ml script for Lwt... *)
  match t.ccomp_type with
  | "msvc" -> true
  | _      -> false

let compile_and_link_c_prog t ?(c_flags=[]) ?(link_flags=[]) code =
  let dir = t.dest_dir ^/ sprintf "c-test-%d" (gen_id t) in
  Unix.mkdir dir 0o777;
  let base = dir ^/ "test" in
  let c_fname = base ^ ".c" in
  let obj_fname = base ^ t.ext_obj in
  let exe_fname = base ^ ".exe" in
  Io.write_file c_fname code;
  logf t "compiling c program:";
  List.iter (String.split_lines code) ~f:(logf t " | %s");
  let run_ok args =
    run_ok t ~dir
      (String.concat ~sep:" "
         (t.c_compiler :: List.map args ~f:Filename.quote))
  in
  let ok =
    if need_to_compile_and_link_separately t then
      run_ok (c_flags @ ["-I"; t.stdlib_dir; "-c"; c_fname])
      && run_ok ("-o" :: exe_fname :: obj_fname :: link_flags)
    else
      run_ok
        (List.concat
           [ c_flags
           ; [ "-I" ; t.stdlib_dir
             ; "-o" ; exe_fname
             ; c_fname
             ]
           ; link_flags
           ])
  in
  if ok then Ok () else Error ()

let compile_c_prog t ?(c_flags=[]) code =
  let dir = t.dest_dir ^/ sprintf "c-test-%d" (gen_id t) in
  Unix.mkdir dir 0o777;
  let base = dir ^/ "test" in
  let c_fname = base ^ ".c" in
  let obj_fname = base ^ t.ext_obj in
  Io.write_file c_fname code;
  logf t "compiling c program:";
  List.iter (String.split_lines code) ~f:(logf t " | %s");
  let run_ok args =
    run_ok t ~dir
      (String.concat ~sep:" "
         (t.c_compiler :: List.map args ~f:Filename.quote))
  in
  let ok =
    run_ok (List.concat
              [ c_flags
              ; [ "-I" ; t.stdlib_dir
                ; "-o" ; obj_fname
                ; "-c" ; c_fname
                ]
              ])
  in
  if ok then
    Ok obj_fname
  else
    Error ()

let c_test t ?c_flags ?link_flags code =
  match compile_and_link_c_prog t ?c_flags ?link_flags code with
  | Ok    _ -> true
  | Error _ -> false

module C_define = struct
  module Type = struct
    type t =
      | Switch
      | Int
      | String
  end

  module Value = struct
    type t =
      | Switch of bool
      | Int    of int
      | String of string
  end

  let extract_program ?prelude includes vars =
    let has_type t = List.exists vars ~f:(fun (_, t') -> t = t') in
    let buf = Buffer.create 1024 in
    let pr fmt = Printf.bprintf buf (fmt ^^ "\n") in
    List.iter includes ~f:(pr "#include <%s>");
    pr "";
    Option.iter prelude ~f:(pr "%s");
    if has_type Type.Int then (
      pr {|
#define D0(x) ('0'+(x/1         )%%10)
#define D1(x) ('0'+(x/10        )%%10), D0(x)
#define D2(x) ('0'+(x/100       )%%10), D1(x)
#define D3(x) ('0'+(x/1000      )%%10), D2(x)
#define D4(x) ('0'+(x/10000     )%%10), D3(x)
#define D5(x) ('0'+(x/100000    )%%10), D4(x)
#define D6(x) ('0'+(x/1000000   )%%10), D5(x)
#define D7(x) ('0'+(x/10000000  )%%10), D6(x)
#define D8(x) ('0'+(x/100000000 )%%10), D7(x)
#define D9(x) ('0'+(x/1000000000)%%10), D8(x)
|}
    );
    List.iteri vars ~f:(fun i (name, t) ->
      match t with
      | Type.Int ->
        let c_arr_i =
          let b = Buffer.create 8 in
          let is = string_of_int i in
          for i=0 to String.length is - 1 do
            Printf.bprintf b "'%c', " is.[i]
          done;
          Buffer.contents b
        in
        pr {|
const char s%i[] = {
  'B', 'E', 'G', 'I', 'N', '-', %s'-',
#if %s >= 0
  D9((%s)),
#else
  '-', D9((- %s)),
#endif
  '-', 'E', 'N', 'D'
};
|} i c_arr_i name name name
      | String ->
        pr {|const char *s%i = "BEGIN-%i-" %s "-END";|} i i name;
      | Switch ->
        pr {|
#ifdef %s
const char *s%i = "BEGIN-%i-true-END";
#else
const char *s%i = "BEGIN-%i-false-END";
#endif
|} name i i i i
    );
    Buffer.contents buf

  let extract_values obj_file vars =
    let values =
      Io.with_lexbuf_from_file obj_file ~f:(Extract_obj.extract [])
      |> Int.Map.of_list_exn
    in
    List.mapi vars ~f:(fun i (name, t) ->
      let value =
        let raw_val =
          match Int.Map.find values i with
          | None -> die "Unable to get value for %s" name
          | Some v -> v in
        match t with
        | Type.Switch -> Value.Switch (bool_of_string raw_val)
        | Int -> Int (int_of_string raw_val)
        | String -> String raw_val in
      (name, value))

  let import t ?prelude ?c_flags ~includes vars =
    let program = extract_program ?prelude ("stdio.h" :: includes) vars in
    match compile_c_prog t ?c_flags program with
    | Error _ -> die "failed to compile program"
    | Ok obj -> extract_values obj vars

  let gen_header_file t ~fname ?protection_var vars =
    let protection_var =
      match protection_var with
      | Some v -> v
      | None ->
        String.map (t.name ^ "_" ^ Filename.basename fname) ~f:(function
          | 'a'..'z' as c -> Char.uppercase_ascii c
          | 'A'..'Z' | '0'..'9' as c -> c
          | _ -> '_')
    in
    let vars =
      List.sort vars ~compare:(fun (a, _) (b, _) -> String.compare a b) in
    let lines =
      List.map vars ~f:(fun (name, value) ->
        match (value : Value.t) with
        | Switch false -> sprintf "#undef  %s" name
        | Switch true  -> sprintf "#define %s" name
        | Int    n     -> sprintf "#define %s (%d)" name n
        | String s     -> sprintf "#define %s %S" name s)
    in
    let lines =
      List.concat
        [ [ sprintf "#ifndef %s" protection_var
          ; sprintf "#define %s" protection_var
          ]
        ; lines
        ; [ "#endif" ]
        ]
    in
    logf t "writing header file %s" fname;
    List.iter lines ~f:(logf t " | %s");
    let tmp_fname = fname ^ ".tmp" in
    Io.write_lines tmp_fname lines;
    Sys.rename tmp_fname fname
end

let find_in_path t prog =
  logf t "find_in_path: %s" prog;
  let x = Find_in_path.find prog in
  logf t "-> %s"
    (match x with
     | None -> "not found"
     | Some fn -> "found: " ^ quote fn);
  x

module Pkg_config = struct
  type nonrec t =
    { pkg_config   : string
    ; configurator : t
    }

  let get c =
    Option.map (find_in_path c "pkg-config") ~f:(fun pkg_config ->
      { pkg_config; configurator = c })

  type package_conf =
    { libs   : string list
    ; cflags : string list
    }

  let query t ~package =
    let package = quote package in
    let pkg_config = quote t.pkg_config in
    let c = t.configurator in
    let dir = c.dest_dir in
    let env =
      match ocaml_config_var c "system" with
      | Some "macosx" -> begin
          match find_in_path c "brew" with
          | Some brew ->
            let prefix =
              String.trim (run_capture_exn c ~dir (command_line brew ["--prefix"]))
            in
            sprintf "env PKG_CONFIG_PATH=%s/opt/%s/lib/pkgconfig:$PKG_CONFIG_PATH "
              (quote prefix) package
          | None ->
            ""
        end
      | _ -> ""
    in
    if run_ok c ~dir (sprintf "%s%s %s" env pkg_config package) then
      let run what =
        match
          String.trim
            (run_capture_exn c ~dir (sprintf "%s%s %s %s" env pkg_config what package))
        with
        | "" -> []
        | s  -> String.split s ~on:' '
      in
      Some
        { libs   = run "--libs"
        ; cflags = run "--cflags"
        }
    else
      None
end

let main ?(args=[]) ~name f =
  let ocamlc  = ref (
    match Sys.getenv "DUNE_CONFIGURATOR" with
    | s -> Some s
    | exception Not_found ->
      die "Configurator scripts must be run with Dune. \
           To manually run a script, use $ dune exec."
  ) in
  let verbose = ref false in
  let dest_dir = ref None in
  let args =
    Arg.align
      ([ "-verbose", Arg.Set verbose,
         " be verbose"
       ; "-dest-dir", Arg.String (fun s -> dest_dir := Some s),
         "DIR save temporary files to this directory"
       ] @ args)
  in
  let anon s = raise (Arg.Bad (sprintf "don't know what to do with %s" s)) in
  let usage = sprintf "%s [OPTIONS]" (Filename.basename Sys.executable_name) in
  Arg.parse args anon usage;
  let log_db = ref [] in
  let log s = log_db := s :: !log_db in
  let t =
    create
      ?dest_dir:!dest_dir
      ?ocamlc:!ocamlc
      ~log:(if !verbose then prerr_endline else log)
      name
  in
  try
    f t
  with exn ->
    let bt = Printexc.get_raw_backtrace () in
    List.iter (List.rev !log_db) ~f:(eprintf "%s\n");
    match exn with
    | Fatal_error msg ->
      eprintf "Error: %s\n%!" msg;
      exit 1
    | _ -> Exn.raise_with_backtrace exn bt
