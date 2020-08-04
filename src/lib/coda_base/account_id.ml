[%%import
"/src/config.mlh"]

open Core_kernel
open Import

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Public_key.Compressed.Stable.V1.t * Token_id.Stable.V1.t
    [@@deriving sexp, equal, compare, hash, yojson]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t [@@deriving sexp, equal, compare, hash, yojson]

let create key tid = (key, tid)

let empty = (Public_key.Compressed.empty, Token_id.default)

let public_key (key, _tid) = key

let token_id (_key, tid) = tid

let to_input (key, tid) =
  Random_oracle.Input.append
    (Public_key.Compressed.to_input key)
    (Token_id.to_input tid)

let gen =
  let open Quickcheck.Let_syntax in
  let%map key = Public_key.Compressed.gen and tid = Token_id.gen in
  (key, tid)

include Comparable.Make_binable (Stable.Latest)
include Hashable.Make_binable (Stable.Latest)

[%%ifdef
consensus_mechanism]

type var = Public_key.Compressed.var * Token_id.var

let typ = Snarky.Typ.(Public_key.Compressed.typ * Token_id.typ)

let var_of_t (key, tid) =
  (Public_key.Compressed.var_of_t key, Token_id.var_of_t tid)

module Checked = struct
  open Snark_params
  open Tick

  let create key tid = (key, tid)

  let public_key (key, _tid) = key

  let token_id (_key, tid) = tid

  let to_input (key, tid) =
    let%map tid = Token_id.Checked.to_input tid in
    Random_oracle.Input.append (Public_key.Compressed.Checked.to_input key) tid

  let equal (pk1, tid1) (pk2, tid2) =
    let%bind pk_equal = Public_key.Compressed.Checked.equal pk1 pk2 in
    let%bind tid_equal = Token_id.Checked.equal tid1 tid2 in
    Tick.Boolean.(pk_equal && tid_equal)

  let if_ b ~then_:(pk_then, tid_then) ~else_:(pk_else, tid_else) =
    let%bind pk =
      Public_key.Compressed.Checked.if_ b ~then_:pk_then ~else_:pk_else
    in
    let%map tid = Token_id.Checked.if_ b ~then_:tid_then ~else_:tid_else in
    (pk, tid)
end

[%%endif]
