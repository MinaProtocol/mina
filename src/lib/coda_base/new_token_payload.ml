open Core_kernel
open Import

[%%versioned
module Stable = struct
  module V1 = struct
    type t = {token_owner_pk: Public_key.Compressed.Stable.V1.t}
    [@@deriving compare, eq, sexp, hash, yojson]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t = {token_owner_pk: Public_key.Compressed.t}
[@@deriving compare, eq, sexp, hash, yojson]

let receiver_pk {token_owner_pk} = token_owner_pk

let receiver ~next_available_token {token_owner_pk} =
  Account_id.create token_owner_pk next_available_token

let source_pk {token_owner_pk} = token_owner_pk

let source ~next_available_token {token_owner_pk} =
  Account_id.create token_owner_pk next_available_token

let token (_ : t) = Token_id.invalid

let gen =
  Quickcheck.Generator.map Public_key.Compressed.gen ~f:(fun pk ->
      {token_owner_pk= pk} )
