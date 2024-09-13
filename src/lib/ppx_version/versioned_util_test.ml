open Core_kernel
open Ppxlib
open Ppx_version

module M = struct
  type t = int

  let foo : t -> t = fun x -> x

  module N = struct
    type t = string

    let foo : t -> t = fun x -> x
  end
end

module O = struct
  type o = int

  let foo : o -> o = fun x -> x
end

module P = struct end

let str ~loc =
  [%str
    open M
    include O

    let a = const (module P)

    type t = { a : int * string * N.t list; b : o }]

let () =
  let _ = M.foo 1 in
  let _ = M.N.foo "1" in
  let _ = O.foo 1 in
  let loc = Ppxlib.Location.none in
  let s = str ~loc in
  Pprintast.structure Format.std_formatter s ;
  print_endline "" ;
  let types_used = Versioned_util.types_in_declaration_fold#structure s [] in
  (* Using Format.printf to control output *)
  let s = String.concat ~sep:",\n" types_used in
  Format.printf "%s%!" s
