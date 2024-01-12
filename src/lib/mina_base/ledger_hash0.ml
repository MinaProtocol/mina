open Core_kernel
open Snark_params.Tick

include Data_hash.Make_full_size (struct
  let description = "Ledger hash"

  let version_byte = Base58_check.Version_bytes.ledger_hash
end)

(* Data hash versioned boilerplate below *)

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V1 = struct
    module T = struct
      type t = (Field.t[@version_asserted]) [@@deriving sexp, compare, hash]
    end

    include T

    let to_latest = Fn.id

    [%%define_from_scope to_yojson, of_yojson]

    include Comparable.Make (T)
    include Hashable.Make_binable (T)
  end
end]

let (_ : (t, Stable.Latest.t) Type_equal.t) = Type_equal.T
