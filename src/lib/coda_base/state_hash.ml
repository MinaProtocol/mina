(* state_hash.ml -- defines the type for the protocol state hash *)

[%%import
"/src/config.mlh"]

[%%ifndef
consensus_mechanism]

module Outside_pedersen_image =
  Outside_pedersen_image_nonconsensus.Outside_pedersen_image
module Random_oracle = Random_oracle_nonconsensus.Random_oracle

[%%endif]

include Data_hash.Make_full_size ()

module Base58_check = Codable.Make_base58_check (struct
  include Stable.Latest

  let version_byte = Base58_check.Version_bytes.state_hash

  let description = "State hash"
end)

[%%define_locally
Base58_check.(to_base58_check, of_base58_check, of_base58_check_exn)]

[%%define_locally
Base58_check.String_ops.(to_string, of_string)]

[%%define_locally
Base58_check.(to_yojson, of_yojson)]

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
