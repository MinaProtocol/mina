open Ocamlbuild_plugin
open Unix

let run_cmd cmd =
  try
    let ch = Unix.open_process_in cmd in
    let line = input_line ch in
    let () = close_in ch in
    line
  with | End_of_file -> "Not available"

let from_env_or_cmd envvar cmd =
  try Unix.getenv envvar
  with Not_found -> run_cmd cmd

let make_version_and_meta _ _ =
  let (major,minor,patch) =
    try
      let tag_version =
        from_env_or_cmd
          "OROCKSDB_TAG_VERSION"
          "git describe --tags --exact-match --dirty"
      in
      Scanf.sscanf tag_version "%i.%i.%i" (fun ma mi p -> (ma,mi,p))
    with _ ->
      let branch_version = run_cmd "git describe --all" in
      try Scanf.sscanf branch_version "heads/%i.%i" (fun ma mi -> (ma,mi,-1))
      with _ -> (-1,-1,-1)
  in
  let git_revision =
    from_env_or_cmd
      "OROCKSDB_GIT_REVISION"
      "git describe --all --long --always --dirty"
  in
  let lines = [
      Printf.sprintf "let major = %i\n" major;
      Printf.sprintf "let minor = %i\n" minor;
      Printf.sprintf "let patch = %i\n" patch;
      Printf.sprintf "let git_revision = %S\n" git_revision;
      "let summary = (major, minor , patch , git_revision)\n"
    ]
  in
  let write_version = Echo (lines, "rocks_version.ml") in
  let clean_version =
    match patch with
    | -1 -> git_revision
    | _  -> Printf.sprintf "%i.%i.%i" major minor patch
  in
  let rocks_libdir =
    try Unix.getenv "ROCKS_LIBDIR"
    with Not_found ->
      failwith "MUST set ROCKS_LIBDIR to build" in
  let rocks_lib =
    try Unix.getenv "ROCKS_LIB"
    with Not_found ->
      failwith "MUST set ROCKS_LIB to build" in
  let linkopts =
    Printf.sprintf "-cclib -Wl,-rpath=%s -cclib -L%s -cclib -l%s"
      rocks_libdir rocks_libdir rocks_lib in
  let meta_lines = [
      "description = \"Rocksdb binding\"\n";
      Printf.sprintf "version = %S\n" clean_version;
      "exists_if = \"rocks.cma,rocks.cmxa,rocks.cmxs\"\n";
      "requires = \"ctypes ctypes.foreign\"\n";
      "archive(native) = \"rocks.cmxa\"\n";
      "archive(byte) = \"rocks.cma\"\n";
      Printf.sprintf "linkopts = \"%s\"" linkopts ;
    ]
  in
  let write_meta = Echo (meta_lines, "META") in
  Seq [write_version;write_meta]


let _ =
  dispatch
  & function
    | After_rules ->
       rule "rocks_version.ml" ~prod:"rocks_version.ml" make_version_and_meta;
    | _ -> ()
