include Data_hash.Make_full_size ()

module Base58_check = Codable.Make_base58_check(struct
    include Stable.Latest

    let description = "State body hash"

    let version_byte = Base58_check.Version_bytes.state_body_hash
end)

[%%define_locally
Base58_check.(to_yojson,of_yojson)]

let dummy = of_hash Outside_pedersen_image.t
