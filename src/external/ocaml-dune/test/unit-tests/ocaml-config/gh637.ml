open! Stdune

let pwd = Sys.getcwd ()

let valid_ocaml_config = Printf.sprintf
{|version: 4.02.3
standard_library_default: %s
standard_library: %s
standard_runtime: /usr/bin/ocamlrun
ccomp_type: cc
bytecomp_c_compiler: gcc -O -fno-defer-pop -Wall -D_FILE_OFFSET_BITS=64 -D_REENTRANT -O -fPIC
bytecomp_c_libraries: -lm  -ldl -lcurses -lpthread
native_c_compiler: gcc -O -Wall -D_FILE_OFFSET_BITS=64 -D_REENTRANT
native_c_libraries: -lm  -ldl
native_pack_linker: ld -r  -o
ranlib: ranlib
cc_profile: -pg
architecture: none
model: default
system: unknown
asm:
asm_cfi_supported: false
with_frame_pointers: false
ext_obj: .o
ext_asm: .s
ext_lib: .a
ext_dll: .so
os_type: Unix
default_executable_name: a.out
systhread_supported: true
host: mips-unknown-linux-gnu
target: mips-unknown-linux-gnu
exec_magic_number: Caml1999X011
cmi_magic_number: Caml1999I017
cmo_magic_number: Caml1999O010
cma_magic_number: Caml1999A011
cmx_magic_number: Caml1999Y014
cmxa_magic_number: Caml1999Z013
ast_impl_magic_number: Caml1999M016
ast_intf_magic_number: Caml1999N015
cmxs_magic_number: Caml2007D002
cmt_magic_number: Caml2012T004|}
pwd pwd

let () =
  match
    match
      valid_ocaml_config
      |> String.split_lines
      |> Ocaml_config.Vars.of_lines
    with
    | Ok x -> Ocaml_config.make x
    | Error msg -> Error (Ocamlc_config, msg)
  with
  | Error (_, e) -> failwith e
  | Ok (_ : Ocaml_config.t) -> ()
