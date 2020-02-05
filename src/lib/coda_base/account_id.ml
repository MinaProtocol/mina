open Core_kernel
open Signature_lib

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Public_key.Compressed.Stable.V1.t * Token_id.Stable.V1.t
    [@@deriving sexp, compare, hash, yojson]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t [@@deriving sexp, compare, hash, yojson]

type var = Public_key.Compressed.var * Token_id.var

let typ = Snarky.Typ.(Public_key.Compressed.typ * Token_id.typ)

let create key tid = (key, tid)

include Comparable.Make_binable (Stable.Latest)
include Hashable.Make_binable (Stable.Latest)

module Checked = struct
  open Snark_params
  open Tick

  let create key tid = (key, tid)

  let equal (pk1, tid1) (pk2, tid2) =
    let%bind pk_equal = Public_key.Compressed.Checked.equal pk1 pk2 in
    let%bind tid_equal = Token_id.Checked.equal tid1 tid2 in
    Tick.Boolean.(pk_equal && tid_equal)
end
