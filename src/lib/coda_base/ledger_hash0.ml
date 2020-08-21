open Core_kernel
open Snark_params.Tick

include Data_hash.Make_full_size (struct
  let description = "Ledger hash"

  let version_byte = Base58_check.Version_bytes.ledger_hash
end)

(* Data hash versioned boilerplate below *)

[%%versioned
module Stable = struct
  module V1 = struct
    module T = struct
      type t = Field.t [@@deriving sexp, compare, hash, version {asserted}]
    end

    include T

    let to_latest = Core.Fn.id

    [%%define_from_scope
    to_yojson, of_yojson]

    include Comparable.Make (T)
    include Hashable.Make_binable (T)
  end
end]

type _unused = unit constraint t = Stable.Latest.t
