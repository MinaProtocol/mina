(* stake_delegation.ml *)

open Core_kernel
open Signature_lib

[%%versioned
module Stable = struct
  module V2 = struct
    [@@@with_all_version_tags]

    type t = Mina_wire_types.Mina_base.Stake_delegation.V2.t =
      | Set_delegate of { new_delegate : Public_key.Compressed.Stable.V1.t }
    [@@deriving compare, equal, sexp, hash, yojson]

    let to_latest = Fn.id
  end

  module V1 = struct
    [@@@with_all_version_tags]

    type t = Mina_wire_types.Mina_base.Stake_delegation.V1.t =
      | Set_delegate of
          { delegator : Public_key.Compressed.Stable.V1.t
          ; new_delegate : Public_key.Compressed.Stable.V1.t
          }
    [@@deriving compare, equal, sexp, hash, yojson]

    let to_latest (Set_delegate { delegator = _; new_delegate }) =
      V2.Set_delegate { new_delegate }
  end
end]

let receiver_pk = function Set_delegate { new_delegate } -> new_delegate

let receiver = function
  | Set_delegate { new_delegate } ->
      Account_id.create new_delegate Token_id.default

let gen =
  Quickcheck.Generator.map Public_key.Compressed.gen ~f:(fun k ->
      Set_delegate { new_delegate = k } )
