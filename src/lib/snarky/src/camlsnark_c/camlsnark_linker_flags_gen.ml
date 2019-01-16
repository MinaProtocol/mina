open Printf
module C = Configurator.V1

let () =
  let cwd = Unix.getcwd () in
  let uname_chan = Unix.open_process_in "uname" in
  let l = input_line uname_chan in
  C.Flags.write_sexp "flags.sexp"
    ( match l with
    | "Darwin" ->
        [ sprintf "-Wl,-force_load,%s/libcamlsnark_c_stubs.a" cwd
        ; "-L/usr/local/opt/openssl/lib"
        ; "-lssl"
        ; "-lcrypto"
        ; "-lgmp"
        ; "-lstdc++" ]
    | "Linux" ->
        [ "-Wl,-E"
        ; "-Wl,--push-state,-whole-archive"
        ; "-lcamlsnark_c_stubs"
        ; "-Wl,--pop-state"
        ; "-fopenmp"
        ; "-lssl"
        ; "-lcrypto"
        ; "-lprocps"
        ; "-lgmp"
        ; "-lstdc++" ]
    | s -> failwith (sprintf "don't know how to link on %s yet" s) )
