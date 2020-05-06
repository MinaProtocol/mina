(* state_hash.ml -- defines the type for the protocol state hash *)

[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifndef
consensus_mechanism]

module Outside_pedersen_image =
  Outside_pedersen_image_nonconsensus.Outside_pedersen_image
module Random_oracle = Random_oracle_nonconsensus.Random_oracle
open Snark_params_nonconsensus

[%%else]

open Snark_params.Tick

[%%endif]

include Data_hash.Make_full_size (struct
  let version_byte = Base58_check.Version_bytes.state_hash

  let description = "State hash"
end)

let dummy = of_hash Outside_pedersen_image.t

[%%ifdef
consensus_mechanism]

let zero = Snark_params.Tick.Pedersen.zero_hash

[%%else]

(* in the nonconsensus world, we don't have the Pedersen machinery available,
   so just inline the value for zero
*)
let zero =
  Snark_params_nonconsensus.Field.of_string
    "332637027557984585263317650500984572911029666110240270052776816409842001629441009391914692"

[%%endif]

let raw_hash_bytes = to_bytes

let to_bytes = `Use_to_base58_check_or_raw_hash_bytes

let to_decimal_string = to_decimal_string

(* Data hash versioned boilerplate below *)

[%%versioned
module Stable = struct
  module V1 = struct
    module T = struct
      type t = Field.t [@@deriving sexp, compare, hash, version {asserted}]
    end

    include T

    let to_latest = Fn.id

    [%%define_from_scope
    to_yojson, of_yojson]

    include Comparable.Make (T)
    include Hashable.Make_binable (T)
  end
end]

type _unused = unit constraint t = Stable.Latest.t
