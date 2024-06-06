(* state_hash.ml -- defines the type for the protocol state hash *)

[%%import "/src/config.mlh"]

open Core_kernel
open Snark_params.Tick

include Data_hash.Make_full_size (struct
  let version_byte = Base58_check.Version_bytes.state_hash

  let description = "State hash"
end)

let dummy = of_hash Outside_hash_image.t

let zero = dummy

let raw_hash_bytes = to_bytes

let to_bytes = `Use_to_base58_check_or_raw_hash_bytes

let to_decimal_string = to_decimal_string

let of_decimal_string = of_decimal_string

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

let deriver obj =
  Fields_derivers_zkapps.(
    iso_string ~name:"StateHash" ~js_type:Field ~to_string:to_base58_check
      ~of_string:of_base58_check_exn
    |> needs_custom_js ~name:"StateHash" ~js_type:field)
    obj
