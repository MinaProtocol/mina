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

let to_public_key {voting_for} =
  Public_key.Compressed.Poly.
    {x= (voting_for :> Pedersen.Digest.t); is_odd= false}

let fold {voting_for} =
  (* We stuff the stash_hash into a public_key here for efficiency reason.
     
     To be specific, every [transaction] is eventually compiled to a
     [transaction_union] which would be used in snark. And [chain_voting] is
     just 1 kind of transaction.
     
     Unfortunately, we don't have variant in snark, so we have to manually
     compile different variants of [transaction]s into a hand-crafted
     data structure in snark called [transaction_union].
     
     Metaphorically, we smash all the variants into a big union type with tags
     to differentiate each individual variant.
     
     [transaction_union] has a payload body part which is different for
     different transactions. And we decided that body part should only contains
     a public_key (which is a field element + a bit) + an amount.

     Here we are compiling the body of the chain_voting (which is just a
     hash/field element) into the body of a [Transaction_union_payload] by
     stuffing the hash into the public_key. *)
  Fn.compose Public_key.Compressed.fold to_public_key

let length_in_triples = Public_key.Compressed.length_in_triples
