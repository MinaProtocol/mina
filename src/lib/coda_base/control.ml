open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      | Proof of Pickles.Side_loaded.Proof.Stable.V1.t
      | Signature of Signature.Stable.V1.t
      | Both of
          { signature: Signature.Stable.V1.t
          ; proof: Pickles.Side_loaded.Proof.Stable.V1.t }
      | None_given
    [@@deriving sexp, eq, yojson, hash, compare]

    let to_latest = Fn.id
  end
end]

module Tag = struct
  type t = Proof | Signature | Both | None_given
end

let tag : t -> Tag.t = function
  | Proof _ ->
      Proof
  | Signature _ ->
      Both
  | Both _ ->
      Both
  | None_given ->
      None_given
