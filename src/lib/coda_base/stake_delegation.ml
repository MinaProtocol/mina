open Core_kernel
open Signature_lib
open Module_version

module Stable = struct
  module V1 = struct
    module T = struct
      let version = 1

      type t =
        | Set_delegate of {new_delegate: Public_key.Compressed.Stable.V1.t}
      [@@deriving bin_io, eq, sexp, hash, yojson]
    end

    include T
    include Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "stake_delegation"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

(* bin_io omitted *)
type t = Stable.Latest.t =
  | Set_delegate of {new_delegate: Public_key.Compressed.Stable.V1.t}
[@@deriving eq, sexp, hash, yojson]

let gen =
  Quickcheck.Generator.map Public_key.Compressed.gen ~f:(fun k ->
      Set_delegate {new_delegate= k} )

let fold = function
  | Set_delegate {new_delegate} -> Public_key.Compressed.fold new_delegate

let length_in_triples = Public_key.Compressed.length_in_triples
