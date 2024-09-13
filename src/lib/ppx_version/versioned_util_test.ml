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

  module Stable = struct
    module V1 = struct
      type t = string

      type x = X.x
      let to_latest = Fn.id
    end
  end
  ]

module StringSet = Set.Make (String)

let () =
  let _ = M.foo 1 in
  let _ = M.N.foo "1" in
  let _ = O.foo 1 in
  let loc = Ppxlib.Location.none in
  let s = str ~loc in
  Pprintast.structure Format.std_formatter s ;
  print_endline "" ;
  let types_used = Versioned_util.collect_types#structure s StringSet.empty in
  (* Using Format.printf to control output *)
  let s = String.concat ~sep:",\n" (StringSet.to_list types_used) in
  Format.printf "%s%!" s
