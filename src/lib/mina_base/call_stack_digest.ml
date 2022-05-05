open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Kimchi_backend.Pasta.Basic.Fp.Stable.V1.t
    [@@deriving sexp, compare, equal, hash, yojson]

    let to_latest = Fn.id
  end
end]

open Pickles.Impls.Step

let cons (h : Stack_frame.Digest.t) (t : t) : t =
  Random_oracle.hash ~init:Hash_prefix_states.party_stack_frame_cons
    [| (h :> Field.Constant.t); t |]

let empty = Field.Constant.zero

let gen = Field.Constant.gen

module Checked = struct
  include Field

  let cons (h : Stack_frame.Digest.Checked.t) (t : t) : t =
    Random_oracle.Checked.hash ~init:Hash_prefix_states.party_stack_frame_cons
      [| (h :> Field.t); t |]
end

let constant = Field.constant

let typ = Field.typ
