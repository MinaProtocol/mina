open Printf
module C = Configurator.V1

let () =
  let cwd = Unix.getcwd () in
  let uname_chan = Unix.open_process_in "uname" in
  let l = input_line uname_chan in
  C.Flags.write_sexp "flags.sexp"
    ( match l with
    | "Darwin" ->
        [sprintf "-Wl,-force_load,%s/librocksdb_stubs.a" cwd; "-lz"; "-lbz2"]
    | "Linux" ->
        [ "-Wl,--push-state,-whole-archive"
        ; "-lrocksdb_stubs"
        ; "-Wl,--pop-state"
        ; "-lz"
        ; "-lbz2"
        ; "-lstdc++" ]
    | s -> failwith (sprintf "don't know how to link on %s yet" s) )
