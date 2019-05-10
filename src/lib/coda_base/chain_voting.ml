open Core_kernel
open Signature_lib
open Module_version
open Snark_params.Tick

module Stable = struct
  module V1 = struct
    module T = struct
      type t = {voting_for: State_hash.Stable.V1.t}
      [@@deriving bin_io, compare, eq, sexp, hash, yojson, version]
    end

    include T
    include Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "chain_voting"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

type t = Stable.Latest.t = {voting_for: State_hash.Stable.V1.t}
[@@deriving eq, sexp, hash, yojson]

let gen = Quickcheck.Generator.return {voting_for= State_hash.(of_hash zero)}

let fold {voting_for} =
  (* We stuff the stash_hash into a public_key here for efficiency reason *)
  let pk =
    Public_key.Compressed.Poly.
      {x= (voting_for :> Pedersen.Digest.t); is_odd= false}
  in
  Public_key.Compressed.fold pk

let length_in_triples = Public_key.Compressed.length_in_triples
