(* stake_delegation.ml *)

[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Signature_lib

[%%else]

open Signature_lib_nonconsensus

[%%endif]

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Set_delegate of {new_delegate: Public_key.Compressed.Stable.V1.t}
    [@@deriving compare, eq, sexp, hash, yojson]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t =
  | Set_delegate of {new_delegate: Public_key.Compressed.Stable.V1.t}
[@@deriving eq, sexp, hash, yojson]

let receiver = function Set_delegate {new_delegate} -> new_delegate

let gen =
  Quickcheck.Generator.map Public_key.Compressed.gen ~f:(fun k ->
      Set_delegate {new_delegate= k} )

let to_input = function
  | Set_delegate {new_delegate} ->
      Public_key.Compressed.to_input new_delegate
