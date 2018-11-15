open Core_kernel
open Signature_lib

module Stable = struct
  module V1 = struct
    type t = Set_delegate of {new_delegate: Public_key.Compressed.t}
    [@@deriving bin_io, eq, sexp, hash]
  end
end

include Stable.V1

let gen =
  Quickcheck.Generator.map Public_key.Compressed.gen ~f:(fun k ->
      Set_delegate {new_delegate= k} )

let fold = function
  | Set_delegate {new_delegate} -> Public_key.Compressed.fold new_delegate

let length_in_triples = Public_key.Compressed.length_in_triples
