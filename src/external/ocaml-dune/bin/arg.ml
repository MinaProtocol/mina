open Stdune
open Dune

include Cmdliner.Arg

let package_name =
  conv ((fun p -> Ok (Package.Name.of_string p)), Package.Name.pp)

module Path : sig
  type t
  val path : t -> Path.t
  val arg : t -> string

  val conv : t conv
end = struct
  type t = string

  let path p = Path.of_filename_relative_to_initial_cwd p
  let arg s = s

  let conv = conv ((fun p -> Ok p), Format.pp_print_string)
end

let path = Path.conv

[@@@ocaml.warning "-32"]
let file = path
