open Core_kernel

module Legacy_token = Mina_numbers.Nat.Make64 ()

[%%versioned
module Stable = struct
  module V2 = struct
    type t = Account_id.Digest.Stable.V1.t
    [@@deriving sexp, yojson, equal, compare, hash]

    let to_latest = Fn.id
  end

  (* for transactions in pre-Berkeley hard fork *)
  module V1 = struct
    [@@@with_all_version_tags]

    type t = Legacy_token.Stable.V1.t
    [@@deriving sexp, equal, compare, hash, yojson]

    let to_latest _ = failwith "Not implemented"
  end
end]

[%%define_locally
Account_id.Digest.
  ( default
  , typ
  , to_input
  , gen
  , gen_non_default
  , to_string
  , of_string
  , comparator
  , ( <> ) )]

include Account_id.Digest.Binables

(* someday, allow this in %%define_locally *)
module Checked = Account_id.Digest.Checked

let deriver obj =
  (* this doesn't use js_type:Field because it is converted to JSON differently than a normal Field *)
  Fields_derivers_zkapps.iso_string obj ~name:"TokenId"
    ~js_type:(Custom "TokenId") ~doc:"String representing a token ID" ~to_string
    ~of_string:(Fields_derivers_zkapps.except ~f:of_string `Token_id)
